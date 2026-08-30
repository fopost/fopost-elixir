defmodule FoPost.Webhooks do
  @moduledoc """
  Outbound webhooks — the push counterpart to polling a post's deliveries.

  ## Verifying a delivery

  Every delivery carries three headers:

    * `X-FoPost-Signature` — `sha256=<hex>`, the HMAC-SHA256 of the raw request body
      keyed with the subscription's secret
    * `X-FoPost-Event` — the event name
    * `X-FoPost-Delivery` — the delivery's own id

  Verify against the **raw** body, before any JSON decoding, or the bytes will not match:

      def handle(conn) do
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        [signature] = Plug.Conn.get_req_header(conn, "x-fopost-signature")

        case FoPost.Webhooks.verify_and_parse(raw, signature, secret) do
          {:ok, event} -> process(event)
          {:error, :invalid_signature} -> Plug.Conn.send_resp(conn, 401, "")
        end
      end

  The comparison is constant time. No timestamp is mixed into the signature, so there is
  no replay window to enforce — deduplicate on `X-FoPost-Delivery` if you need it.
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
    "account.health_changed"
  ]

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

  defp secure_equal?(left, right)
       when is_binary(left) and is_binary(right) and byte_size(left) == byte_size(right) do
    constant_time_equal?(left, right, 0)
  end

  defp secure_equal?(_left, _right), do: false

  defp constant_time_equal?(<<left, rest_left::binary>>, <<right, rest_right::binary>>, acc) do
    constant_time_equal?(rest_left, rest_right, Bitwise.bor(acc, Bitwise.bxor(left, right)))
  end

  defp constant_time_equal?(<<>>, <<>>, acc), do: acc == 0

  defp path(id), do: "/webhooks/" <> URI.encode(to_string(id), &URI.char_unreserved?/1)
end
