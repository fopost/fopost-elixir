defmodule FoPost.Validate do
  @moduledoc """
  Checks content against platform rules without creating a post.

  Nothing is stored server-side, and every call needs the `posts` scope. `subreddit/2` is
  the exception that reads a connected account, so that account has to be one the key sees.

      {:ok, result} =
        FoPost.Validate.post(client, content: "Hello", platforms: ["twitter", "linkedin"])

      result.ready
  """

  alias FoPost.Client
  alias FoPost.Model
  alias FoPost.Result
  alias FoPost.Validate.LengthResult
  alias FoPost.Validate.MediaResult
  alias FoPost.Validate.PostResult
  alias FoPost.Validate.SubredditResult

  @doc """
  Checks a whole post against each platform.

  Required: `:platforms`. Optional: `:content` and `:media`, a list of maps carrying
  `url`, `mime_type`, and optionally `size`.
  """
  @spec post(Client.t(), keyword()) :: {:ok, PostResult.t()} | {:error, FoPost.Error.t()}
  def post(client, opts) do
    body = Model.take_body(opts, [:content, :media, :platforms])

    with {:ok, data} <- Client.request(client, :post, "/validate/post", json: body) do
      {:ok, PostResult.from_map(data)}
    end
  end

  @doc """
  Measures text the way each platform counts it. Required: `:text` and `:platforms`.
  """
  @spec length(Client.t(), keyword()) :: {:ok, LengthResult.t()} | {:error, FoPost.Error.t()}
  def length(client, opts) do
    body = Model.take_body(opts, [:text, :platforms])

    with {:ok, data} <- Client.request(client, :post, "/validate/length", json: body) do
      {:ok, LengthResult.from_map(data)}
    end
  end

  @doc """
  Fetches a public file and checks it. Required: `:url`. A file that fails a check still
  answers `{:ok, result}` with `ok: false`.
  """
  @spec media(Client.t(), keyword()) :: {:ok, MediaResult.t()} | {:error, FoPost.Error.t()}
  def media(client, opts) do
    body = Model.take_body(opts, [:url])

    with {:ok, data} <- Client.request(client, :post, "/validate/media", json: body) do
      {:ok, MediaResult.from_map(data)}
    end
  end

  @doc """
  Whether a subreddit exists and takes a post from one account.

  Required: `:account_id` (a connected Reddit account, whose token the check runs with) and
  `:name` (a subreddit without the `r/` prefix). A private, banned, or missing subreddit
  answers `{:ok, result}` with `exists: false`.
  """
  @spec subreddit(Client.t(), keyword()) ::
          {:ok, SubredditResult.t()} | {:error, FoPost.Error.t()}
  def subreddit(client, opts) do
    params = %{
      "account_id" => Keyword.fetch!(opts, :account_id),
      "name" => Keyword.fetch!(opts, :name)
    }

    with {:ok, data} <- Client.request(client, :get, "/validate/subreddit", params: params) do
      {:ok, SubredditResult.from_map(data)}
    end
  end

  @doc "Same as `post/2`, but raises `FoPost.Error`."
  def post!(client, opts), do: Result.unwrap!(post(client, opts))

  @doc "Same as `length/2`, but raises `FoPost.Error`."
  def length!(client, opts), do: Result.unwrap!(length(client, opts))

  @doc "Same as `media/2`, but raises `FoPost.Error`."
  def media!(client, opts), do: Result.unwrap!(media(client, opts))

  @doc "Same as `subreddit/2`, but raises `FoPost.Error`."
  def subreddit!(client, opts), do: Result.unwrap!(subreddit(client, opts))
end
