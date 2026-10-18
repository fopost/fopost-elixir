defmodule FoPost.QueueMove do
  @moduledoc """
  A queued post that moved to a new time because a slot changed.
  """

  alias FoPost.Model

  defstruct [:id, :from, :to, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      from: Model.datetime(fields["from"]),
      to: Model.datetime(fields["to"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.QueueSlot do
  @moduledoc """
  One recurring posting slot: a weekday (`0` = Sunday … `6` = Saturday) and an `HH:MM`
  time in `:timezone`. `:account_id` is `nil` for a slot that applies to every account.

  `:moved` is filled by `FoPost.Queue.update_slot/3` with the queued posts the change
  moved.
  """

  alias FoPost.Model
  alias FoPost.QueueMove

  defstruct [
    :id,
    :workspace_id,
    :account_id,
    :weekday,
    :time,
    :timezone,
    :created_at,
    :raw,
    moved: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      workspace_id: fields["workspace_id"],
      account_id: fields["account_id"],
      weekday: fields["weekday"],
      time: fields["time"],
      timezone: fields["timezone"],
      created_at: Model.datetime(fields["created_at"]),
      moved: Model.list(QueueMove, fields["moved"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.QueueSlotDeletion do
  @moduledoc """
  What `FoPost.Queue.delete_slot/2` answers: whether the slot went, and the queued posts
  that moved to another slot.
  """

  alias FoPost.Model
  alias FoPost.QueueMove

  defstruct [:deleted, :raw, moved: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      deleted: fields["deleted"],
      moved: Model.list(QueueMove, fields["moved"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
