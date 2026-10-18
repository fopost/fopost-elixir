defmodule FoPost.Blogs do
  @moduledoc """
  Articles and products that already live on a connected site.

  Every id here is the platform's own, never a FoPost id. Reads need the `posts`
  scope; anything that changes the site needs `posts` and `publish`. An account
  on a platform that cannot manage articles answers 400 `unsupported_platform`.

  An update changes the live article in place and never creates a second post,
  so a link already shared keeps working.
  """

  alias FoPost.Client
  alias FoPost.Model
  alias FoPost.RemoteArticle
  alias FoPost.RemoteBlog
  alias FoPost.RemoteProduct
  alias FoPost.Result

  @article_fields [:title, :body, :excerpt, :status, :tags, :author_name, :image_url]
  @product_fields [:title, :description, :status, :tags, :product_type, :vendor]

  @doc """
  The blogs the account can write to.

  WordPress reports its one implicit blog, under the id `"default"`.
  """
  @spec list_blogs(Client.t(), String.t()) ::
          {:ok, [RemoteBlog.t()]} | {:error, FoPost.Error.t()}
  def list_blogs(client, account_id) do
    with {:ok, data} <- Client.request(client, :get, blogs_path(account_id)) do
      {:ok, Model.list(RemoteBlog, data)}
    end
  end

  @doc """
  The blog's articles, newest first, drafts included.

  Optional: `:limit` (1 to 50), `:status`, `:q`.
  """
  @spec list_articles(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, [RemoteArticle.t()]} | {:error, FoPost.Error.t()}
  def list_articles(client, account_id, blog_id, opts \\ []) do
    params = Model.take_params(opts, [:limit, :status, :q])

    with {:ok, data} <-
           Client.request(client, :get, articles_path(account_id, blog_id), params: params) do
      {:ok, Model.list(RemoteArticle, data)}
    end
  end

  @doc """
  One article in full.
  """
  @spec get_article(Client.t(), String.t(), String.t(), String.t()) ::
          {:ok, RemoteArticle.t()} | {:error, FoPost.Error.t()}
  def get_article(client, account_id, blog_id, article_id) do
    with {:ok, data} <-
           Client.request(client, :get, article_path(account_id, blog_id, article_id)) do
      {:ok, RemoteArticle.from_map(data)}
    end
  end

  @doc """
  Writes a new article to the site. Needs the `publish` scope.

  Required: `:title`, `:body`. `:body` is FoPost body markup; the site's own
  format is rendered from it. Optional: `:excerpt`, `:status`, `:tags`,
  `:author_name`, `:image_url`.
  """
  @spec create_article(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, RemoteArticle.t()} | {:error, FoPost.Error.t()}
  def create_article(client, account_id, blog_id, opts) do
    body = Model.take_body(opts, @article_fields)

    with {:ok, data} <-
           Client.request(client, :post, articles_path(account_id, blog_id), json: body) do
      {:ok, RemoteArticle.from_map(data)}
    end
  end

  @doc """
  Changes the live article in place. Needs the `publish` scope.

  Only what is passed changes, and the article is addressed by its own id, so
  this never creates a second post. Set at least one field.
  """
  @spec update_article(Client.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, RemoteArticle.t()} | {:error, FoPost.Error.t()}
  def update_article(client, account_id, blog_id, article_id, opts) do
    body = Model.take_body(opts, @article_fields)

    with {:ok, data} <-
           Client.request(client, :patch, article_path(account_id, blog_id, article_id),
             json: body
           ) do
      {:ok, RemoteArticle.from_map(data)}
    end
  end

  @doc """
  Removes the article from the site. This cannot be undone.
  """
  @spec delete_article(Client.t(), String.t(), String.t(), String.t()) ::
          :ok | {:error, FoPost.Error.t()}
  def delete_article(client, account_id, blog_id, article_id) do
    with {:ok, _data} <-
           Client.request(client, :delete, article_path(account_id, blog_id, article_id)) do
      :ok
    end
  end

  @doc """
  The store's products. Optional: `:limit`, `:status`, `:q`.
  """
  @spec list_products(Client.t(), String.t(), keyword()) ::
          {:ok, [RemoteProduct.t()]} | {:error, FoPost.Error.t()}
  def list_products(client, account_id, opts \\ []) do
    params = Model.take_params(opts, [:limit, :status, :q])

    with {:ok, data} <-
           Client.request(client, :get, products_path(account_id), params: params) do
      {:ok, Model.list(RemoteProduct, data)}
    end
  end

  @doc """
  Changes a product on the store. Only what is passed changes; set at least one.
  """
  @spec update_product(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, RemoteProduct.t()} | {:error, FoPost.Error.t()}
  def update_product(client, account_id, product_id, opts) do
    body = Model.take_body(opts, @product_fields)

    with {:ok, data} <-
           Client.request(client, :patch, product_path(account_id, product_id), json: body) do
      {:ok, RemoteProduct.from_map(data)}
    end
  end

  @doc "Same as `list_blogs/2`, but raises `FoPost.Error`."
  def list_blogs!(client, account_id), do: Result.unwrap!(list_blogs(client, account_id))

  @doc "Same as `list_articles/4`, but raises `FoPost.Error`."
  def list_articles!(client, account_id, blog_id, opts \\ []),
    do: Result.unwrap!(list_articles(client, account_id, blog_id, opts))

  @doc "Same as `get_article/4`, but raises `FoPost.Error`."
  def get_article!(client, account_id, blog_id, article_id),
    do: Result.unwrap!(get_article(client, account_id, blog_id, article_id))

  @doc "Same as `create_article/4`, but raises `FoPost.Error`."
  def create_article!(client, account_id, blog_id, opts),
    do: Result.unwrap!(create_article(client, account_id, blog_id, opts))

  @doc "Same as `update_article/5`, but raises `FoPost.Error`."
  def update_article!(client, account_id, blog_id, article_id, opts),
    do: Result.unwrap!(update_article(client, account_id, blog_id, article_id, opts))

  @doc "Same as `delete_article/4`, but raises `FoPost.Error`."
  def delete_article!(client, account_id, blog_id, article_id),
    do: Result.unwrap!(delete_article(client, account_id, blog_id, article_id))

  @doc "Same as `list_products/3`, but raises `FoPost.Error`."
  def list_products!(client, account_id, opts \\ []),
    do: Result.unwrap!(list_products(client, account_id, opts))

  @doc "Same as `update_product/4`, but raises `FoPost.Error`."
  def update_product!(client, account_id, product_id, opts),
    do: Result.unwrap!(update_product(client, account_id, product_id, opts))

  defp segment(value), do: URI.encode(to_string(value), &URI.char_unreserved?/1)

  defp blogs_path(account_id), do: "/accounts/" <> segment(account_id) <> "/blogs"

  defp articles_path(account_id, blog_id),
    do: blogs_path(account_id) <> "/" <> segment(blog_id) <> "/articles"

  defp article_path(account_id, blog_id, article_id),
    do: articles_path(account_id, blog_id) <> "/" <> segment(article_id)

  defp products_path(account_id), do: "/accounts/" <> segment(account_id) <> "/products"

  defp product_path(account_id, product_id),
    do: products_path(account_id) <> "/" <> segment(product_id)
end
