defmodule FoPost.VideoEdits do
  @moduledoc """
  Video edits: trim, cut, subtitle, reframe, and more, run as a background job on a video
  in the media library.

      {:ok, job} =
        FoPost.VideoEdits.create(client,
          workspace_id: workspace.id,
          media_id: video.id,
          operations: [
            %{op: "trim", params: %{startSec: 0, endSec: 30}},
            %{op: "reframe", params: %{aspect: "9:16"}}
          ]
        )

      {:ok, job} = FoPost.VideoEdits.get(client, job.id)
      job.status

  Operations run in order. Each operation's `params` is sent as given, in the API's
  own field names. `ops/1` lists which operations are available. Every function needs
  the `posts` scope and the workspace's create access; an operation with `uses_ai` also
  needs the `ai` scope.
  """

  alias FoPost.Client
  alias FoPost.Model
  alias FoPost.Result
  alias FoPost.VideoEdit
  alias FoPost.VideoEditOp

  @doc """
  The operations the API offers, and whether each is available and uses AI.
  """
  @spec ops(Client.t()) :: {:ok, [VideoEditOp.t()]} | {:error, FoPost.Error.t()}
  def ops(client) do
    with {:ok, data} <- Client.request(client, :get, "/video-edits/ops") do
      {:ok, Model.list(VideoEditOp, data)}
    end
  end

  @doc """
  Recent video edit jobs, newest first.

  Options: `:workspace_id`, `:media_id` to list one video's edits, `:limit`.
  """
  @spec list(Client.t(), keyword()) :: {:ok, [VideoEdit.t()]} | {:error, FoPost.Error.t()}
  def list(client, opts \\ []) do
    params = Model.take_params(opts, [:workspace_id, :media_id, :limit])

    with {:ok, data} <- Client.request(client, :get, "/video-edits", params: params) do
      {:ok, Model.list(VideoEdit, data)}
    end
  end

  @doc """
  Starts a video edit job.

  Required: `:media_id`, `:operations` (a list of maps of `:op` and optionally
  `:params`). Optional: `:workspace_id`, `:idempotency_key`, sent as the
  `Idempotency-Key` header.
  """
  @spec create(Client.t(), keyword()) :: {:ok, VideoEdit.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    body = Model.take_body(opts, [:workspace_id, :media_id, :operations])

    headers =
      case Keyword.get(opts, :idempotency_key) do
        nil -> []
        key -> [{"idempotency-key", key}]
      end

    with {:ok, data} <-
           Client.request(client, :post, "/video-edits", json: body, headers: headers) do
      {:ok, VideoEdit.from_map(data)}
    end
  end

  @doc """
  One video edit job. Optional: `:workspace_id`.
  """
  @spec get(Client.t(), String.t(), keyword()) ::
          {:ok, VideoEdit.t()} | {:error, FoPost.Error.t()}
  def get(client, id, opts \\ []) do
    path = "/video-edits/" <> URI.encode(to_string(id), &URI.char_unreserved?/1)
    params = Model.take_params(opts, [:workspace_id])

    with {:ok, data} <- Client.request(client, :get, path, params: params) do
      {:ok, VideoEdit.from_map(data)}
    end
  end

  @doc "Same as `ops/1`, but raises `FoPost.Error`."
  def ops!(client), do: Result.unwrap!(ops(client))

  @doc "Same as `list/2`, but raises `FoPost.Error`."
  def list!(client, opts \\ []), do: Result.unwrap!(list(client, opts))

  @doc "Same as `create/2`, but raises `FoPost.Error`."
  def create!(client, opts), do: Result.unwrap!(create(client, opts))

  @doc "Same as `get/3`, but raises `FoPost.Error`."
  def get!(client, id, opts \\ []), do: Result.unwrap!(get(client, id, opts))
end
