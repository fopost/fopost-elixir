defmodule FoPost.Workspaces do
  @moduledoc """
  Workspaces — the tenant boundary every other resource is scoped to.

  A key bound to a single workspace only ever sees that one.
  """

  alias FoPost.Client
  alias FoPost.Message
  alias FoPost.Model
  alias FoPost.Result
  alias FoPost.Workspace
  alias FoPost.WorkspaceAnalytics

  @fields [
    :name,
    :slug,
    :type,
    :logo,
    :website,
    :timezone,
    :country,
    :description,
    :language,
    {:require_approval, "requireApproval"},
    {:ai_alt_text_enabled, "aiAltTextEnabled"},
    {:brand_color, "brandColor"}
  ]

  @doc """
  Every workspace the key can reach.
  """
  @spec list(Client.t()) :: {:ok, [Workspace.t()]} | {:error, FoPost.Error.t()}
  def list(client) do
    with {:ok, data} <- Client.request(client, :get, "/workspaces") do
      {:ok, Model.list(Workspace, data)}
    end
  end

  @doc """
  One workspace, with its connected accounts.
  """
  @spec get(Client.t(), String.t()) :: {:ok, Workspace.t()} | {:error, FoPost.Error.t()}
  def get(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id)) do
      {:ok, Workspace.from_map(data)}
    end
  end

  @doc """
  Adds a workspace.

  Required: `:name`, `:slug`. Optional: `:type`, `:logo`, `:website`, `:timezone`,
  `:country`, `:description`, `:language`.

  Plans cap how many workspaces an account may have, so this answers `402` once the limit
  is reached.
  """
  @spec create(Client.t(), keyword()) :: {:ok, Workspace.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    with {:ok, data} <- Client.request(client, :post, "/workspaces", json: body(opts)) do
      {:ok, Workspace.from_map(data)}
    end
  end

  @doc """
  Edits a workspace. Only the keys you pass are sent.

  Beyond the create fields: `:require_approval`, `:ai_alt_text_enabled`, `:brand_color`.
  """
  @spec update(Client.t(), String.t(), keyword()) ::
          {:ok, Workspace.t()} | {:error, FoPost.Error.t()}
  def update(client, id, opts) do
    with {:ok, data} <- Client.request(client, :put, path(id), json: body(opts)) do
      {:ok, Workspace.from_map(data)}
    end
  end

  @doc """
  Removes a workspace and everything scoped to it.
  """
  @spec delete(Client.t(), String.t()) :: {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete(client, id) do
    with {:ok, data} <- Client.request(client, :delete, path(id)) do
      {:ok, Message.from_map(data)}
    end
  end

  @doc """
  A workspace's follower and post totals.
  """
  @spec analytics(Client.t(), String.t()) ::
          {:ok, WorkspaceAnalytics.t()} | {:error, FoPost.Error.t()}
  def analytics(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id) <> "/analytics") do
      {:ok, WorkspaceAnalytics.from_map(data)}
    end
  end

  @doc "Same as `list/1`, but raises `FoPost.Error`."
  def list!(client), do: Result.unwrap!(list(client))

  @doc "Same as `get/2`, but raises `FoPost.Error`."
  def get!(client, id), do: Result.unwrap!(get(client, id))

  @doc "Same as `create/2`, but raises `FoPost.Error`."
  def create!(client, opts), do: Result.unwrap!(create(client, opts))

  @doc "Same as `update/3`, but raises `FoPost.Error`."
  def update!(client, id, opts), do: Result.unwrap!(update(client, id, opts))

  @doc "Same as `delete/2`, but raises `FoPost.Error`."
  def delete!(client, id), do: Result.unwrap!(delete(client, id))

  @doc "Same as `analytics/2`, but raises `FoPost.Error`."
  def analytics!(client, id), do: Result.unwrap!(analytics(client, id))

  defp body(opts), do: Model.take_body(opts, @fields)

  defp path(id), do: "/workspaces/" <> URI.encode(to_string(id), &URI.char_unreserved?/1)
end
