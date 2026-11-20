defmodule FoPost.VideoEditOp do
  @moduledoc """
  One video edit operation the API offers. `:available` is `false` when it cannot run on
  this deployment; `:uses_ai` operations spend AI balance and need the `ai` scope.
  """

  alias FoPost.Model

  defstruct [:name, :available, :uses_ai, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      name: fields["name"],
      available: fields["available"],
      uses_ai: fields["uses_ai"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.VideoEditOutput do
  @moduledoc """
  A file a video edit produced besides its main result, such as one clip or a subtitle
  track.
  """

  alias FoPost.Model

  defstruct [:media_id, :label, :mime, :preview_url, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      media_id: fields["media_id"],
      label: fields["label"],
      mime: fields["mime"],
      preview_url: fields["preview_url"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.VideoEdit do
  @moduledoc """
  A video edit job. `:status` moves `"queued"` → `"running"` → `"succeeded"` or
  `"failed"`, with `:progress` from `0` to `1`.

  `:operations` is the list sent, each a map of `"op"` and `"params"`. `:result_media`
  is a map of `"id"`, `"preview_url"`, and `"mime_type"` once the job has succeeded;
  `:result` holds anything else an operation reported.
  """

  alias FoPost.Model
  alias FoPost.VideoEditOutput

  defstruct [
    :id,
    :status,
    :progress,
    :source_media_id,
    :result_media_id,
    :result_media,
    :result,
    :error,
    :created_at,
    :updated_at,
    :completed_at,
    :raw,
    operations: [],
    extra_outputs: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      status: fields["status"],
      progress: fields["progress"],
      source_media_id: fields["source_media_id"],
      operations: fields["operations"] || [],
      result_media_id: fields["result_media_id"],
      result_media: fields["result_media"],
      extra_outputs: Model.list(VideoEditOutput, fields["extra_outputs"]),
      result: fields["result"],
      error: fields["error"],
      created_at: Model.datetime(fields["created_at"]),
      updated_at: Model.datetime(fields["updated_at"]),
      completed_at: Model.datetime(fields["completed_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
