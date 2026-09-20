defmodule FoPost.Knowledge do
  @moduledoc """
  The workspace knowledge base — what the workspace has told FoPost about
  itself.

  A source is an FAQ, a note, a page on your own site, or a plain-text/CSV item
  from the media library. Retrieval over these is what grounds a drafted inbox
  reply in your own answers instead of an invented one. Needs the `inbox` scope.
  """

  alias FoPost.Client
  alias FoPost.KnowledgeMatch
  alias FoPost.KnowledgeSource
  alias FoPost.KnowledgeSyncResult
  alias FoPost.Message
  alias FoPost.Model
  alias FoPost.Result

  @doc """
  The workspace's sources, optionally narrowed with `:workspace_id`. Only a
  `"ready"` source is searched.
  """
  @spec list(Client.t(), keyword()) :: {:ok, [KnowledgeSource.t()]} | {:error, FoPost.Error.t()}
  def list(client, opts \\ []) do
    params = Model.take_params(opts, [:workspace_id])

    with {:ok, data} <- Client.request(client, :get, "/knowledge/sources", params: params) do
      {:ok, Model.list(KnowledgeSource, data)}
    end
  end

  @doc """
  Adds a source and queues it for indexing, so it comes back `"pending"`.

  Required: `:kind` and `:title`. A `"faq"` or `"text"` source needs
  `:content`, a `"url"` source needs `:url`, and a `"file"` source needs
  `:media_id` pointing at a plain-text or CSV item in the same workspace.
  Optional: `:brand_voice_id`, `:workspace_id`.
  """
  @spec create(Client.t(), keyword()) :: {:ok, KnowledgeSource.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    body =
      Model.take_body(opts, [
        :kind,
        :title,
        :content,
        :url,
        :media_id,
        :brand_voice_id,
        :workspace_id
      ])

    with {:ok, data} <- Client.request(client, :post, "/knowledge/sources", json: body) do
      {:ok, KnowledgeSource.from_map(data)}
    end
  end

  @doc """
  Edits a source. Only the keys you pass are sent; changing `:content` or
  `:url` returns the source to `"pending"` and re-indexes it.
  """
  @spec update(Client.t(), String.t(), keyword()) ::
          {:ok, KnowledgeSource.t()} | {:error, FoPost.Error.t()}
  def update(client, id, opts) do
    body = Model.take_body(opts, [:title, :content, :url, :brand_voice_id])

    with {:ok, data} <- Client.request(client, :patch, path(id), json: body) do
      {:ok, KnowledgeSource.from_map(data)}
    end
  end

  @doc """
  Removes a source and every passage indexed from it.
  """
  @spec delete(Client.t(), String.t()) :: {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete(client, id) do
    with {:ok, data} <- Client.request(client, :delete, path(id)) do
      {:ok, Message.from_map(data)}
    end
  end

  @doc """
  Reads the source again — a `"url"` source is re-fetched. Returns once the
  re-index is queued, not once it has finished.
  """
  @spec sync(Client.t(), String.t()) ::
          {:ok, KnowledgeSyncResult.t()} | {:error, FoPost.Error.t()}
  def sync(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id) <> "/sync", json: %{}) do
      {:ok, KnowledgeSyncResult.from_map(data)}
    end
  end

  @doc """
  The passages closest to a question, best first. An empty list is the honest
  answer when nothing stored answers it.

  Optional: `:top_k` (default 5, max 20), `:brand_voice_id`, `:workspace_id`.
  """
  @spec search(Client.t(), String.t(), keyword()) ::
          {:ok, [KnowledgeMatch.t()]} | {:error, FoPost.Error.t()}
  def search(client, q, opts \\ []) do
    params =
      [{"q", q} | Model.take_params(opts, [:top_k, :brand_voice_id, :workspace_id])]

    with {:ok, data} <- Client.request(client, :get, "/knowledge/search", params: params) do
      {:ok, Model.list(KnowledgeMatch, data)}
    end
  end

  @doc "Same as `list/2`, but raises `FoPost.Error`."
  def list!(client, opts \\ []), do: Result.unwrap!(list(client, opts))

  @doc "Same as `create/2`, but raises `FoPost.Error`."
  def create!(client, opts), do: Result.unwrap!(create(client, opts))

  @doc "Same as `update/3`, but raises `FoPost.Error`."
  def update!(client, id, opts), do: Result.unwrap!(update(client, id, opts))

  @doc "Same as `delete/2`, but raises `FoPost.Error`."
  def delete!(client, id), do: Result.unwrap!(delete(client, id))

  @doc "Same as `sync/2`, but raises `FoPost.Error`."
  def sync!(client, id), do: Result.unwrap!(sync(client, id))

  @doc "Same as `search/3`, but raises `FoPost.Error`."
  def search!(client, q, opts \\ []), do: Result.unwrap!(search(client, q, opts))

  defp path(id),
    do: "/knowledge/sources/" <> URI.encode(to_string(id), &URI.char_unreserved?/1)
end
