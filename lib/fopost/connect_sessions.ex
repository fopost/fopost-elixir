defmodule FoPost.ConnectSessions do
  @moduledoc """
  Hosted connect links — let your own users connect a social account without leaving
  your product.

      {:ok, session} =
        FoPost.ConnectSessions.create(client,
          workspace_id: workspace.id,
          external_user_id: "user_42",
          platforms: ["twitter", "linkedin"],
          redirect_url: "https://app.yourbrand.com/connected"
        )

      session.url

  Hand `session.url` to the user; poll `get/2` until `:status` is `"used"`, then
  `:account_id` names the account. Both need the `accounts` scope.
  """

  alias FoPost.Client
  alias FoPost.ConnectSession
  alias FoPost.Model
  alias FoPost.Result

  @fields [
    {:workspace_id, "workspaceId"},
    {:external_user_id, "externalUserId"},
    :platforms,
    {:redirect_url, "redirectUrl"}
  ]

  @doc """
  Mints a hosted connect link. `:url` on the result is only ever returned here.

  Required: `:external_user_id`, `:platforms`. Optional: `:workspace_id`,
  `:redirect_url`, and `:branding` as a map of `:name` and `:logo_url`.
  """
  @spec create(Client.t(), keyword()) :: {:ok, ConnectSession.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    body = opts |> Model.take_body(@fields) |> put_branding(opts)

    with {:ok, data} <- Client.request(client, :post, "/connect-sessions", json: body) do
      {:ok, ConnectSession.from_map(data)}
    end
  end

  @doc """
  Where a connect link stands.
  """
  @spec get(Client.t(), String.t()) :: {:ok, ConnectSession.t()} | {:error, FoPost.Error.t()}
  def get(client, id) do
    url_path = "/connect-sessions/" <> URI.encode(to_string(id), &URI.char_unreserved?/1)

    with {:ok, data} <- Client.request(client, :get, url_path) do
      {:ok, ConnectSession.from_map(data)}
    end
  end

  @doc "Same as `create/2`, but raises `FoPost.Error`."
  def create!(client, opts), do: Result.unwrap!(create(client, opts))

  @doc "Same as `get/2`, but raises `FoPost.Error`."
  def get!(client, id), do: Result.unwrap!(get(client, id))

  defp put_branding(body, opts) do
    case Keyword.fetch(opts, :branding) do
      {:ok, %{} = branding} ->
        wire =
          %{}
          |> Model.put_present("name", branding[:name] || branding["name"])
          |> Model.put_present("logoUrl", branding[:logo_url] || branding["logo_url"])

        Map.put(body, "branding", wire)

      _other ->
        body
    end
  end
end
