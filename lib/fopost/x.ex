defmodule FoPost.X do
  @moduledoc """
  Pass-through reads from X: look up one post, or search recent posts, through a
  connected X account's own token.

  Every function needs the `inbox` scope and is metered as one X read. The account must
  be an X account; a spent X balance answers `402 platform_balance_spent`, an older
  token `409 reconnect_required`, and X's own rate limit `429 rate_limited`.

      {:ok, post} = FoPost.X.get_post(client, "1234567890", account.id)
      {:ok, page} = FoPost.X.search_posts(client, "from:fopost", account.id, max_results: 50)
  """

  alias FoPost.Client
  alias FoPost.Model
  alias FoPost.Result
  alias FoPost.XPost
  alias FoPost.XSearchPage

  @doc """
  One post by its X id, read through `account_id`. 404 when X has no such post.

  Wraps the API's `getXPost` operation.
  """
  @spec get_post(Client.t(), String.t(), String.t()) ::
          {:ok, XPost.t()} | {:error, FoPost.Error.t()}
  def get_post(client, post_id, account_id) do
    params = %{"account_id" => account_id}

    with {:ok, data} <- Client.request(client, :get, post_path(post_id), params: params) do
      {:ok, XPost.from_map(data)}
    end
  end

  @doc """
  Recent posts matching `q` (1 to 512 characters), read through `account_id`.

  Options: `:max_results` (10 to 100) and `:next_token` (the previous page's
  `:next_token`).

  Wraps the API's `searchXPosts` operation.
  """
  @spec search_posts(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, XSearchPage.t()} | {:error, FoPost.Error.t()}
  def search_posts(client, q, account_id, opts \\ []) do
    params =
      [q: q, account_id: account_id] ++ Model.take_params(opts, [:max_results, :next_token])

    with {:ok, data} <- Client.request(client, :get, "/x/search", params: params, unwrap: false) do
      {:ok, XSearchPage.from_map(data)}
    end
  end

  @doc "Same as `get_post/3`, but raises `FoPost.Error`."
  def get_post!(client, post_id, account_id),
    do: Result.unwrap!(get_post(client, post_id, account_id))

  @doc "Same as `search_posts/4`, but raises `FoPost.Error`."
  def search_posts!(client, q, account_id, opts \\ []),
    do: Result.unwrap!(search_posts(client, q, account_id, opts))

  defp post_path(id), do: "/x/posts/" <> URI.encode(to_string(id), &URI.char_unreserved?/1)
end
