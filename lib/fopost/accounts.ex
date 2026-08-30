defmodule FoPost.Accounts do
  @moduledoc """
  Connected social accounts — what a post is actually delivered to.

  Accounts on platforms that use OAuth are connected in the FoPost dashboard; `create/2`
  is for the platforms where you already hold the credentials.
  """

  alias FoPost.Account
  alias FoPost.AccountAnalytics
  alias FoPost.AccountHealth
  alias FoPost.Client
  alias FoPost.HealthSummary
  alias FoPost.Message
  alias FoPost.Model
  alias FoPost.Result
  alias FoPost.ValidationResult

  @doc """
  The connected accounts the key can reach, optionally narrowed with `:workspace_id`.
  """
  @spec list(Client.t(), keyword()) :: {:ok, [Account.t()]} | {:error, FoPost.Error.t()}
  def list(client, opts \\ []) do
    params = Model.take_params(opts, [{:workspace_id, "workspaceId"}])

    with {:ok, data} <- Client.request(client, :get, "/accounts", params: params) do
      {:ok, Model.list(Account, data)}
    end
  end

  @doc """
  One account.
  """
  @spec get(Client.t(), String.t()) :: {:ok, Account.t()} | {:error, FoPost.Error.t()}
  def get(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id)) do
      {:ok, Account.from_map(data)}
    end
  end

  @doc """
  Connects an account from credentials you already hold.

  Required: `:workspace_id`, `:platform`, `:username`, `:name`. Optional: `:avatar`,
  `:credentials` — a map of the platform's own fields.
  """
  @spec create(Client.t(), keyword()) :: {:ok, Account.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    body =
      Model.take_body(opts, [
        {:workspace_id, "workspaceId"},
        :platform,
        :username,
        :name,
        :avatar,
        :credentials
      ])

    with {:ok, data} <- Client.request(client, :post, "/accounts", json: body) do
      {:ok, Account.from_map(data)}
    end
  end

  @doc """
  Disconnects an account.
  """
  @spec delete(Client.t(), String.t()) :: {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete(client, id) do
    with {:ok, data} <- Client.request(client, :delete, path(id)) do
      {:ok, Message.from_map(data)}
    end
  end

  @doc """
  Makes this the account that leads its platform in the workspace.
  """
  @spec set_primary(Client.t(), String.t()) :: {:ok, Account.t()} | {:error, FoPost.Error.t()}
  def set_primary(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id) <> "/primary") do
      {:ok, Account.from_map(data)}
    end
  end

  @doc """
  Checks an account's stored credentials against the platform.
  """
  @spec validate(Client.t(), String.t()) ::
          {:ok, ValidationResult.t()} | {:error, FoPost.Error.t()}
  def validate(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id) <> "/validate") do
      {:ok, ValidationResult.from_map(data)}
    end
  end

  @doc """
  One account's health.

  Pass `refresh: true` to check it live rather than reading the last stored result.
  """
  @spec health(Client.t(), String.t(), keyword()) ::
          {:ok, AccountHealth.t()} | {:error, FoPost.Error.t()}
  def health(client, id, opts \\ []) do
    params = Model.take_params(opts, [:refresh])

    with {:ok, data} <- Client.request(client, :get, path(id) <> "/health", params: params) do
      {:ok, AccountHealth.from_map(data)}
    end
  end

  @doc """
  Every reachable account's health, optionally narrowed with `:workspace_id`.
  """
  @spec health_summary(Client.t(), keyword()) ::
          {:ok, HealthSummary.t()} | {:error, FoPost.Error.t()}
  def health_summary(client, opts \\ []) do
    params = Model.take_params(opts, [{:workspace_id, "workspaceId"}])

    with {:ok, data} <- Client.request(client, :get, "/accounts/health", params: params) do
      {:ok, HealthSummary.from_map(data)}
    end
  end

  @doc """
  Renews an account's OAuth token ahead of its expiry.
  """
  @spec refresh_token(Client.t(), String.t()) ::
          {:ok, FoPost.TokenRefresh.t()} | {:error, FoPost.Error.t()}
  def refresh_token(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id) <> "/refresh-token") do
      {:ok, FoPost.TokenRefresh.from_map(data)}
    end
  end

  @doc """
  An account's stored follower snapshots, newest first.

  `:limit` caps how many come back; leaving it out keeps the API's own default.
  """
  @spec analytics(Client.t(), String.t(), keyword()) ::
          {:ok, AccountAnalytics.t()} | {:error, FoPost.Error.t()}
  def analytics(client, id, opts \\ []) do
    params = Model.take_params(opts, [:limit])
    url_path = path(id) <> "/analytics"

    with {:ok, data} <- Client.request(client, :get, url_path, params: params) do
      {:ok, AccountAnalytics.from_map(data)}
    end
  end

  @doc "Same as `list/2`, but raises `FoPost.Error`."
  def list!(client, opts \\ []), do: Result.unwrap!(list(client, opts))

  @doc "Same as `get/2`, but raises `FoPost.Error`."
  def get!(client, id), do: Result.unwrap!(get(client, id))

  @doc "Same as `create/2`, but raises `FoPost.Error`."
  def create!(client, opts), do: Result.unwrap!(create(client, opts))

  @doc "Same as `delete/2`, but raises `FoPost.Error`."
  def delete!(client, id), do: Result.unwrap!(delete(client, id))

  @doc "Same as `set_primary/2`, but raises `FoPost.Error`."
  def set_primary!(client, id), do: Result.unwrap!(set_primary(client, id))

  @doc "Same as `validate/2`, but raises `FoPost.Error`."
  def validate!(client, id), do: Result.unwrap!(validate(client, id))

  @doc "Same as `health/3`, but raises `FoPost.Error`."
  def health!(client, id, opts \\ []), do: Result.unwrap!(health(client, id, opts))

  @doc "Same as `health_summary/2`, but raises `FoPost.Error`."
  def health_summary!(client, opts \\ []), do: Result.unwrap!(health_summary(client, opts))

  @doc "Same as `refresh_token/2`, but raises `FoPost.Error`."
  def refresh_token!(client, id), do: Result.unwrap!(refresh_token(client, id))

  @doc "Same as `analytics/3`, but raises `FoPost.Error`."
  def analytics!(client, id, opts \\ []), do: Result.unwrap!(analytics(client, id, opts))

  defp path(id), do: "/accounts/" <> URI.encode(to_string(id), &URI.char_unreserved?/1)
end
