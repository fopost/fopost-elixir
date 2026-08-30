defmodule FoPost.Communities do
  @moduledoc """
  The communities an account can post into.
  """

  alias FoPost.Client
  alias FoPost.Community
  alias FoPost.CommunitySearchResult
  alias FoPost.Message
  alias FoPost.Model
  alias FoPost.Result

  @doc """
  The communities linked to an account.
  """
  @spec list(Client.t(), String.t()) :: {:ok, [Community.t()]} | {:error, FoPost.Error.t()}
  def list(client, account_id) do
    with {:ok, data} <- Client.request(client, :get, path(account_id)) do
      {:ok, Model.list(Community, data)}
    end
  end

  @doc """
  Pulls the account's communities from the platform and stores them.
  """
  @spec sync(Client.t(), String.t()) :: {:ok, [Community.t()]} | {:error, FoPost.Error.t()}
  def sync(client, account_id) do
    with {:ok, data} <- Client.request(client, :post, path(account_id) <> "/sync") do
      {:ok, Model.list(Community, data)}
    end
  end

  @doc """
  Looks a community up on the platform without linking it.
  """
  @spec search(Client.t(), String.t(), String.t()) ::
          {:ok, [CommunitySearchResult.t()]} | {:error, FoPost.Error.t()}
  def search(client, account_id, query) do
    url_path = path(account_id) <> "/search"

    with {:ok, data} <- Client.request(client, :get, url_path, params: [q: query]) do
      {:ok, Model.list(CommunitySearchResult, data)}
    end
  end

  @doc """
  Links a community to the account by its platform id.

  For the case where neither `search/3` nor `sync/2` surfaces it. Required:
  `:community_id`. Optional: `:name`.
  """
  @spec add(Client.t(), String.t(), keyword()) ::
          {:ok, Community.t()} | {:error, FoPost.Error.t()}
  def add(client, account_id, opts) do
    body = Model.take_body(opts, [{:community_id, "communityId"}, :name])
    url_path = path(account_id) <> "/manual"

    with {:ok, data} <- Client.request(client, :post, url_path, json: body) do
      {:ok, Community.from_map(data)}
    end
  end

  @doc """
  Unlinks a community.

  `community_id` is the `:id` of a `FoPost.Community`, the local row id — not the
  platform's own community id.
  """
  @spec remove(Client.t(), String.t(), String.t() | integer()) ::
          {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def remove(client, account_id, community_id) do
    url_path = path(account_id) <> "/" <> segment(community_id)

    with {:ok, data} <- Client.request(client, :delete, url_path) do
      {:ok, Message.from_map(data)}
    end
  end

  @doc "Same as `list/2`, but raises `FoPost.Error`."
  def list!(client, account_id), do: Result.unwrap!(list(client, account_id))

  @doc "Same as `sync/2`, but raises `FoPost.Error`."
  def sync!(client, account_id), do: Result.unwrap!(sync(client, account_id))

  @doc "Same as `search/3`, but raises `FoPost.Error`."
  def search!(client, account_id, query) do
    Result.unwrap!(search(client, account_id, query))
  end

  @doc "Same as `add/3`, but raises `FoPost.Error`."
  def add!(client, account_id, opts), do: Result.unwrap!(add(client, account_id, opts))

  @doc "Same as `remove/3`, but raises `FoPost.Error`."
  def remove!(client, account_id, community_id) do
    Result.unwrap!(remove(client, account_id, community_id))
  end

  defp path(account_id), do: "/accounts/" <> segment(account_id) <> "/communities"

  defp segment(value), do: URI.encode(to_string(value), &URI.char_unreserved?/1)
end
