defmodule FoPost.Webhooks do
  @moduledoc """
  Outbound webhooks — the push counterpart to polling a post's deliveries.

  ## Verifying a delivery

  Every delivery carries these headers:

    * `X-FoPost-Signature` — `sha256=<hex>`, the HMAC-SHA256 of the raw request body
      keyed with the subscription's secret
    * `X-FoPost-Timestamp`: unix seconds when the attempt was sent
    * `X-FoPost-Signature-256`: `sha256=<hex>`, the HMAC-SHA256 of
      `"<timestamp>.<raw body>"`, which is what rules out a replay
    * `X-FoPost-Event` — the event name
    * `X-FoPost-Delivery` — the delivery's own id

  Verify against the **raw** body, before any JSON decoding, or the bytes will not match:

      def handle(conn) do
        {:ok, raw, conn} = Plug.Conn.read_body(conn)

        case FoPost.Webhooks.verify(raw, conn.req_headers, secret) do
          {:ok, event} -> process(event)
          {:error, _reason} -> Plug.Conn.send_resp(conn, 401, "")
        end
      end

  `verify/4` prefers the timestamped signature and rejects one older than 300 seconds;
  it falls back to the plain body signature only when no timestamp header arrived.
  Every comparison is constant time. The website target of `FoPost.Blog` signs its
  requests the same way, with the secret from `FoPost.Blog.update_settings/3`.
  """

  alias FoPost.Client
  alias FoPost.Message
  alias FoPost.Model
  alias FoPost.Result
  alias FoPost.Webhook
  alias FoPost.WebhookEvent

  @events [
    "post.published",
    "post.failed",
    "post.partially_failed",
    "delivery.published",
    "delivery.failed",
    "delivery.delayed",
    "account.health_changed",
    "article.published"
  ]

  @tolerance 300
  @signature_header "x-fopost-signature"
  @timestamped_signature_header "x-fopost-signature-256"
  @timestamp_header "x-fopost-timestamp"

  @doc """
  Every event a subscription can ask for.
  """
  @spec events() :: [String.t()]
  def events, do: @events

  @doc """
  The webhook subscriptions the key can reach.
  """
  @spec list(Client.t()) :: {:ok, [Webhook.t()]} | {:error, FoPost.Error.t()}
  def list(client) do
    with {:ok, data} <- Client.request(client, :get, "/webhooks") do
      {:ok, Model.list(Webhook, data)}
    end
  end

  @doc """
  Subscribes an endpoint to a workspace's events.

  Required: `:workspace_id`, `:url`, `:events`. The signing secret comes back on
  `:secret`, once and only here — store it now.
  """
  @spec create(Client.t(), keyword()) :: {:ok, Webhook.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    body = Model.take_body(opts, [{:workspace_id, "workspaceId"}, :url, :events])

    with {:ok, data} <- Client.request(client, :post, "/webhooks", json: body) do
      {:ok, Webhook.from_map(data)}
    end
  end

  @doc """
  Changes a subscription's endpoint, events, or active flag.
  """
  @spec update(Client.t(), String.t(), keyword()) ::
          {:ok, Webhook.t()} | {:error, FoPost.Error.t()}
  def update(client, id, opts) do
    body = Model.take_body(opts, [:url, :events, :active])

    with {:ok, data} <- Client.request(client, :put, path(id), json: body) do
      {:ok, Webhook.from_map(data)}
    end
  end

  @doc """
  Removes a subscription.
  """
  @spec delete(Client.t(), String.t()) :: {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete(client, id) do
    with {:ok, data} <- Client.request(client, :delete, path(id)) do
      {:ok, Message.from_map(data)}
    end
  end

  @doc """
  Sends a sample event to the subscribed endpoint.
  """
  @spec test(Client.t(), String.t()) :: {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def test(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id) <> "/test") do
      {:ok, Message.from_map(data)}
    end
  end

  @doc """
  The signature FoPost would send for this body and secret, header value and all.

  Useful for testing your own handler.
  """
  @spec signature(binary(), String.t()) :: String.t()
  def signature(raw_body, secret) when is_binary(raw_body) and is_binary(secret) do
    digest = :crypto.mac(:hmac, :sha256, secret, raw_body)

    "sha256=" <> Base.encode16(digest, case: :lower)
  end

  @doc """
  The `X-FoPost-Signature-256` value for this body, timestamp and secret.
  """
  @spec timestamped_signature(binary(), integer() | String.t(), String.t()) :: String.t()
  def timestamped_signature(raw_body, timestamp, secret)
      when is_binary(raw_body) and is_binary(secret) do
    signature(to_string(timestamp) <> "." <> raw_body, secret)
  end

  @doc """
  Verifies a delivery from its headers and decodes it in one step.

  `headers` is what the web server handed you: a list of `{name, value}` pairs
  (`conn.req_headers`) or a map. Names are matched case-insensitively.

  When `X-FoPost-Timestamp` is present the timestamped signature must match and the
  timestamp must sit within `:tolerance` seconds (default 300) of now; otherwise the plain
  body signature is checked. Answers `{:ok, event}`, `{:error, :invalid_signature}`,
  `{:error, :stale_timestamp}` or `{:error, :invalid_payload}`.

  Options: `:tolerance` in seconds, and `:now` as unix seconds for tests.
  """
  @spec verify(binary(), [{String.t(), String.t()}] | map(), String.t(), keyword()) ::
          {:ok, WebhookEvent.t()}
          | {:error, :invalid_signature | :stale_timestamp | :invalid_payload}
  def verify(raw_body, headers, secret, opts \\ [])
      when is_binary(raw_body) and is_binary(secret) do
    headers = normalize_headers(headers)
    tolerance = Keyword.get(opts, :tolerance, @tolerance)
    now = Keyword.get_lazy(opts, :now, fn -> System.system_time(:second) end)

    with :ok <- check_signature(raw_body, headers, secret, tolerance, now) do
      parse_event(raw_body)
    end
  end

  @doc """
  Whether the `X-FoPost-Signature` header matches the raw body.

  Pass the body exactly as it arrived, before any decoding. The comparison is constant
  time, so a wrong signature reveals nothing about how wrong it was.
  """
  @spec verify_signature(binary(), String.t() | nil, String.t()) :: boolean()
  def verify_signature(raw_body, header, secret)
      when is_binary(raw_body) and is_binary(header) and is_binary(secret) do
    secure_equal?(signature(raw_body, secret), header)
  end

  def verify_signature(_raw_body, _header, _secret), do: false

  @doc """
  Decodes a delivery body into a `FoPost.WebhookEvent`.
  """
  @spec parse_event(binary()) :: {:ok, WebhookEvent.t()} | {:error, :invalid_payload}
  def parse_event(raw_body) when is_binary(raw_body) do
    case Jason.decode(raw_body) do
      {:ok, data} when is_map(data) -> {:ok, WebhookEvent.from_map(data)}
      _other -> {:error, :invalid_payload}
    end
  end

  @doc """
  Verifies a delivery and decodes it in one step.

  Answers `{:ok, event}`, `{:error, :invalid_signature}`, or `{:error, :invalid_payload}`.
  """
  @spec verify_and_parse(binary(), String.t() | nil, String.t()) ::
          {:ok, WebhookEvent.t()} | {:error, :invalid_signature | :invalid_payload}
  def verify_and_parse(raw_body, header, secret) do
    if verify_signature(raw_body, header, secret) do
      parse_event(raw_body)
    else
      {:error, :invalid_signature}
    end
  end

  @doc "Same as `list/1`, but raises `FoPost.Error`."
  def list!(client), do: Result.unwrap!(list(client))

  @doc "Same as `create/2`, but raises `FoPost.Error`."
  def create!(client, opts), do: Result.unwrap!(create(client, opts))

  @doc "Same as `update/3`, but raises `FoPost.Error`."
  def update!(client, id, opts), do: Result.unwrap!(update(client, id, opts))

  @doc "Same as `delete/2`, but raises `FoPost.Error`."
  def delete!(client, id), do: Result.unwrap!(delete(client, id))

  @doc "Same as `test/2`, but raises `FoPost.Error`."
  def test!(client, id), do: Result.unwrap!(test(client, id))

  defp check_signature(raw_body, headers, secret, tolerance, now) do
    case Map.fetch(headers, @timestamp_header) do
      {:ok, timestamp} ->
        check_timestamped(raw_body, headers, secret, timestamp, tolerance, now)

      :error ->
        if verify_signature(raw_body, headers[@signature_header], secret) do
          :ok
        else
          {:error, :invalid_signature}
        end
    end
  end

  defp check_timestamped(raw_body, headers, secret, timestamp, tolerance, now) do
    expected = timestamped_signature(raw_body, timestamp, secret)

    cond do
      not secure_equal?(expected, headers[@timestamped_signature_header]) ->
        {:error, :invalid_signature}

      not fresh?(timestamp, tolerance, now) ->
        {:error, :stale_timestamp}

      true ->
        :ok
    end
  end

  defp fresh?(timestamp, tolerance, now) do
    case Integer.parse(String.trim(timestamp)) do
      {seconds, ""} -> abs(now - seconds) <= tolerance
      _other -> false
    end
  end

  defp normalize_headers(headers) when is_map(headers),
    do: normalize_headers(Map.to_list(headers))

  defp normalize_headers(headers) when is_list(headers) do
    Map.new(headers, fn {name, value} ->
      {String.downcase(to_string(name)), header_value(value)}
    end)
  end

  defp header_value([value | _rest]), do: to_string(value)
  defp header_value(value) when is_binary(value), do: value
  defp header_value(_value), do: nil

  # hash_equals/2 raises on unequal sizes, which would itself leak the length.
  defp secure_equal?(left, right)
       when is_binary(left) and is_binary(right) and byte_size(left) == byte_size(right) do
    :crypto.hash_equals(left, right)
  end

  defp secure_equal?(_left, _right), do: false

  defp path(id), do: "/webhooks/" <> URI.encode(to_string(id), &URI.char_unreserved?/1)
end
