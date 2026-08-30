defmodule FoPost.Error do
  @moduledoc """
  The single error type every FoPost call answers with.

  The API replies to a failed request with `{"error": "<code>", "message": "<text>"}`,
  which maps onto `:code` and `:message`. `:body` keeps the decoded body as it arrived so
  fields this struct does not model stay reachable.

  Elixir does not need one exception module per status code — the status is on the struct
  and the predicates below cover the cases callers actually branch on:

      case FoPost.Posts.publish(client, post.id) do
        {:ok, result} ->
          result

        {:error, %FoPost.Error{} = error} ->
          cond do
            FoPost.Error.rate_limited?(error) -> retry_in(error.retry_after)
            FoPost.Error.payment_required?(error) -> send_to(error.upgrade_url)
            true -> Logger.error(Exception.message(error))
          end
      end

  A transport failure — connection refused, DNS, a timeout — is the same struct with
  `status: nil` and `code: "transport_error"`, so a caller never has to match on two
  shapes.

  The struct is also an exception, so `raise error` and the bang variants of every
  resource function work the way they do elsewhere in Elixir.
  """

  defexception [:status, :code, :message, :body, :retry_after, :upgrade_url]

  @type t :: %__MODULE__{
          status: pos_integer() | nil,
          code: String.t() | nil,
          message: String.t() | nil,
          body: term(),
          retry_after: pos_integer() | nil,
          upgrade_url: String.t() | nil
        }

  @impl true
  def message(%__MODULE__{status: nil, message: message}), do: "FoPost: #{message}"

  def message(%__MODULE__{status: status, code: nil, message: message}) do
    "FoPost: #{status}: #{message}"
  end

  def message(%__MODULE__{status: status, code: code, message: message}) do
    "FoPost: #{status} #{code}: #{message}"
  end

  @doc """
  True for a 401 — the API key is missing, malformed, or revoked.
  """
  @spec unauthorized?(t()) :: boolean()
  def unauthorized?(%__MODULE__{status: 401}), do: true
  def unauthorized?(%__MODULE__{}), do: false

  @doc """
  True for a 402 — no active subscription, or AI credits are exhausted.

  `:upgrade_url` carries where to send the user when the API supplies one.
  """
  @spec payment_required?(t()) :: boolean()
  def payment_required?(%__MODULE__{status: 402}), do: true
  def payment_required?(%__MODULE__{}), do: false

  @doc """
  True for a 403 — the key is valid but lacks the scope or the workspace.
  """
  @spec forbidden?(t()) :: boolean()
  def forbidden?(%__MODULE__{status: 403}), do: true
  def forbidden?(%__MODULE__{}), do: false

  @doc """
  True for a 404 — no such resource, or it sits outside this key's reach.
  """
  @spec not_found?(t()) :: boolean()
  def not_found?(%__MODULE__{status: 404}), do: true
  def not_found?(%__MODULE__{}), do: false

  @doc """
  True for a 400 or 422 — the request body did not validate.
  """
  @spec validation?(t()) :: boolean()
  def validation?(%__MODULE__{status: status}) when status in [400, 422], do: true
  def validation?(%__MODULE__{}), do: false

  @doc """
  True for a 429. `:retry_after` holds the wait the API asked for, in seconds.

  The client already retries a 429 twice on its own, so seeing this means the retries
  were used up.
  """
  @spec rate_limited?(t()) :: boolean()
  def rate_limited?(%__MODULE__{status: 429}), do: true
  def rate_limited?(%__MODULE__{}), do: false

  @doc """
  True for any 5xx.
  """
  @spec server_error?(t()) :: boolean()
  def server_error?(%__MODULE__{status: status}) when is_integer(status) and status >= 500 do
    true
  end

  def server_error?(%__MODULE__{}), do: false

  @doc """
  True when the request never produced a response: connection refused, DNS, a timeout.
  """
  @spec transport_error?(t()) :: boolean()
  def transport_error?(%__MODULE__{status: nil}), do: true
  def transport_error?(%__MODULE__{}), do: false

  @doc false
  @spec from_response(Req.Response.t()) :: t()
  def from_response(%Req.Response{status: status, body: body} = response) do
    %__MODULE__{
      status: status,
      code: error_code(body),
      message: error_message(body, status),
      body: body,
      retry_after: retry_after(response),
      upgrade_url: upgrade_url(body)
    }
  end

  @doc false
  @spec from_exception(term()) :: t()
  def from_exception(exception) do
    %__MODULE__{
      status: nil,
      code: "transport_error",
      message: describe(exception),
      body: nil
    }
  end

  defp describe(exception) when is_exception(exception), do: Exception.message(exception)
  defp describe(other), do: inspect(other)

  defp error_code(%{"error" => error}) when is_binary(error), do: error
  defp error_code(_body), do: nil

  defp error_message(%{"message" => message}, _status) when is_binary(message), do: message
  defp error_message(%{"error" => error}, _status) when is_binary(error), do: error
  defp error_message(_body, status), do: "HTTP #{status}"

  defp upgrade_url(%{"upgrade_url" => url}) when is_binary(url), do: url
  defp upgrade_url(%{"upgradeUrl" => url}) when is_binary(url), do: url
  defp upgrade_url(_body), do: nil

  defp retry_after(response) do
    case Req.Response.get_header(response, "retry-after") do
      [value | _rest] -> parse_seconds(value)
      [] -> nil
    end
  end

  defp parse_seconds(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {seconds, ""} when seconds > 0 -> seconds
      _other -> nil
    end
  end

  defp parse_seconds(_value), do: nil
end
