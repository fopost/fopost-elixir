defmodule FoPost.ActivityActor do
  @moduledoc """
  Who did something: `"user"`, `"api_key"`, `"agent"` or `"system"`.

  `:name` is absent for a system event.
  """

  alias FoPost.Model

  defstruct [:type, :name, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{type: fields["type"], name: fields["name"], raw: data}
  end

  def from_map(_data), do: %__MODULE__{}
end

defmodule FoPost.ActivityEvent do
  @moduledoc """
  One thing that happened in a workspace. A `"security"` `:kind` is an audit row.
  """

  alias FoPost.ActivityActor
  alias FoPost.Model

  defstruct [:id, :workspace_id, :kind, :ref_type, :ref_id, :summary, :actor, :time, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      workspace_id: fields["workspace_id"],
      kind: fields["kind"],
      ref_type: fields["ref_type"],
      ref_id: fields["ref_id"],
      summary: fields["summary"],
      actor: ActivityActor.from_map(fields["actor"]),
      time: Model.datetime(fields["time"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ActivityPage do
  @moduledoc """
  One page of activity, newest first: the rows on `:data`, the cursor for the
  next page on `:next_cursor`, which is `nil` at the end of the list.
  """

  alias FoPost.ActivityEvent
  alias FoPost.Model

  defstruct data: [], next_cursor: nil

  @type t :: %__MODULE__{data: [ActivityEvent.t()], next_cursor: String.t() | nil}

  @doc false
  def from_map(body) when is_map(body) do
    meta = Model.normalize(Map.get(body, "meta"))

    %__MODULE__{
      data: Model.list(ActivityEvent, Map.get(body, "data")),
      next_cursor: meta["next_cursor"]
    }
  end

  def from_map(_body), do: %__MODULE__{}
end
