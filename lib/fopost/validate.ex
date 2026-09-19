defmodule FoPost.Validate do
  @moduledoc """
  Checks content against platform rules without creating a post.

  Nothing is stored server-side, and every call needs the `posts` scope.

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

  @doc "Same as `post/2`, but raises `FoPost.Error`."
  def post!(client, opts), do: Result.unwrap!(post(client, opts))

  @doc "Same as `length/2`, but raises `FoPost.Error`."
  def length!(client, opts), do: Result.unwrap!(length(client, opts))

  @doc "Same as `media/2`, but raises `FoPost.Error`."
  def media!(client, opts), do: Result.unwrap!(media(client, opts))
end
