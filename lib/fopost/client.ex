defmodule FoPost.Client do
  @moduledoc """
  The client struct every resource function takes as its first argument.

  Build one with `FoPost.new/1` and pass it around explicitly — there is no global client
  and no process state, so a client is just data and is safe to share between processes.

      client = FoPost.new(api_key: "fp_...")

  ## Transport

  Requests go out over [Req](https://hexdocs.pm/req), which pools connections through the
  Finch instance Req starts with its own application. Nothing needs to be added to a host
  application's supervision tree. To use your own pool, pass it through:

      FoPost.new(api_key: key, req_options: [finch: MyApp.Finch])

  `:req_options` is merged last, so it wins over everything the SDK sets — including the
  retry policy. It is the escape hatch for proxies, custom TLS, and test stubs.
  """

  alias FoPost.Error

  @version "0.1.0"
  @default_base_url "https://api.fopost.com/v1"
  @default_receive_timeout 30_000
  @default_max_retries 2
  @base_retry_delay 500
  @max_retry_delay 60_000
  @max_retry_after 60

  @missing_api_key """
  FoPost: an API key is required.

  Pass one to FoPost.new/1:

      FoPost.new(api_key: "fp_...")

  or configure it once:

      config :fopost, api_key: "fp_..."

  or export FOPOST_API_KEY in the environment. Keys are created in the FoPost dashboard
  under Settings then API Keys.
  """

  defstruct [
    :api_key,
    :user_agent,
    base_url: @default_base_url,
    receive_timeout: @default_receive_timeout,
    max_retries: @default_max_retries,
    req_options: []
  ]

  @type t :: %__MODULE__{
          api_key: String.t(),
          user_agent: String.t(),
          base_url: String.t(),
          receive_timeout: pos_integer(),
          max_retries: non_neg_integer(),
          req_options: keyword()
        }

  @doc """
  The SDK version, as reported in the `User-Agent` header.
  """
  @spec version() :: String.t()
  def version, do: @version

  @doc """
  Builds a client. See `FoPost.new/1` for the options.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    api_key = setting(opts, :api_key, "FOPOST_API_KEY")
    base_url = setting(opts, :base_url, "FOPOST_BASE_URL") || @default_base_url

    if is_nil(api_key) or api_key == "" do
      raise ArgumentError, @missing_api_key
    end

    %__MODULE__{
      api_key: api_key,
      base_url: String.trim_trailing(base_url, "/"),
      user_agent: setting(opts, :user_agent, nil) || "fopost-elixir/#{@version}",
      receive_timeout: setting(opts, :timeout, nil) || @default_receive_timeout,
      max_retries: max_retries(opts),
      req_options: setting(opts, :req_options, nil) || []
    }
  end

  @doc """
  Sends one authenticated request and decodes the response.

  `method` is an atom (`:get`, `:post`, `:put`, `:delete`), `path` is relative to the
  client's base URL. Options are passed straight through to Req, so `:params`, `:json`,
  and `:form_multipart` all work, plus one of our own:

    * `:unwrap` — peel the `{"data": ...}` envelope off a successful response.
      Defaults to `true`; list endpoints that also need `meta` pass `false`.

  Answers `{:ok, body}` or `{:error, %FoPost.Error{}}`.
  """
  @spec request(t(), atom(), String.t(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  def request(%__MODULE__{} = client, method, path, opts \\ []) do
    {unwrap?, req_opts} = Keyword.pop(opts, :unwrap, true)

    client
    |> build(method, path, req_opts)
    |> Req.request()
    |> handle(unwrap?)
  end

  @doc false
  @spec retry?(Req.Request.t(), Req.Response.t() | Exception.t()) :: boolean()
  def retry?(_request, %Req.Response{status: status}), do: status == 429 or status >= 500
  def retry?(_request, _exception), do: true

  @doc false
  @spec retry_delay(non_neg_integer()) :: non_neg_integer()
  def retry_delay(attempt) when is_integer(attempt) and attempt >= 0 do
    min(@base_retry_delay * Integer.pow(2, attempt), @max_retry_delay)
  end

  @doc false
  def cap_retry_after_step({request, %Req.Response{} = response}) do
    {request, cap_retry_after(response)}
  end

  def cap_retry_after_step({request, other}), do: {request, other}

  @doc false
  @spec cap_retry_after(Req.Response.t()) :: Req.Response.t()
  def cap_retry_after(%Req.Response{} = response) do
    case Req.Response.get_header(response, "retry-after") do
      [value | _rest] -> Req.Response.put_header(response, "retry-after", capped(value))
      [] -> response
    end
  end

  # Req always hands header values back as binaries, so no catch-all clause is reachable here.
  defp capped(value) do
    case Integer.parse(String.trim(value)) do
      {seconds, ""} when seconds > @max_retry_after -> Integer.to_string(@max_retry_after)
      _other -> value
    end
  end

  defp build(client, method, path, opts) do
    [
      method: method,
      url: url(client, path),
      headers: headers(client),
      receive_timeout: client.receive_timeout,
      max_retries: client.max_retries,
      retry: &__MODULE__.retry?/2,
      retry_delay: &__MODULE__.retry_delay/1,
      retry_log_level: false
    ]
    |> Keyword.merge(opts)
    |> Keyword.merge(client.req_options)
    |> drop_empty_params()
    |> Req.new()
    |> Req.Request.prepend_response_steps(
      fopost_cap_retry_after: &__MODULE__.cap_retry_after_step/1
    )
  end

  defp handle({:ok, %Req.Response{} = response}, unwrap?) do
    if response.status in 200..299 do
      {:ok, payload(response.body, unwrap?)}
    else
      {:error, Error.from_response(response)}
    end
  end

  defp handle({:error, exception}, _unwrap?) do
    {:error, Error.from_exception(exception)}
  end

  defp payload(%{"data" => data}, true), do: data
  defp payload(body, _unwrap?), do: body

  defp url(client, path) do
    client.base_url <> "/" <> String.trim_leading(path, "/")
  end

  defp headers(client) do
    [
      {"accept", "application/json"},
      {"user-agent", client.user_agent},
      {"x-api-key", client.api_key}
    ]
  end

  defp drop_empty_params(options) do
    case Keyword.get(options, :params) do
      [] -> Keyword.delete(options, :params)
      _other -> options
    end
  end

  defp max_retries(opts) do
    case setting(opts, :max_retries, nil) do
      value when is_integer(value) and value >= 0 -> value
      _other -> @default_max_retries
    end
  end

  defp setting(opts, key, env_var) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> value
      :error -> Application.get_env(:fopost, key) || env(env_var)
    end
  end

  defp env(nil), do: nil
  defp env(name), do: System.get_env(name)
end
