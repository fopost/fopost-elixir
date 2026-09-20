defmodule FoPost.BroadcastCounts do
  @moduledoc """
  What became of a broadcast's recipients, by status.

  `:skipped` is usually the messaging window doing its job.
  """

  alias FoPost.Model

  defstruct [:total, :sent, :skipped, :failed, :pending, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      total: fields["total"] || 0,
      sent: fields["sent"] || 0,
      skipped: fields["skipped"] || 0,
      failed: fields["failed"] || 0,
      pending: fields["pending"] || 0,
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Broadcast do
  @moduledoc """
  One message, sent into conversations the workspace already has.

  `:name` is internal only and is never sent to anyone. `:status` is
  `"draft"`, `"scheduled"`, `"sending"`, `"sent"` or `"cancelled"`.
  """

  alias FoPost.BroadcastCounts
  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :text,
    :account_id,
    :audience,
    :status,
    :scheduled_at,
    :sent_at,
    :created_at,
    :counts,
    :workspace_id,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      text: fields["text"],
      account_id: fields["account_id"],
      audience: Model.normalize(fields["audience"]),
      status: fields["status"],
      scheduled_at: Model.datetime(fields["scheduled_at"]),
      sent_at: Model.datetime(fields["sent_at"]),
      created_at: Model.datetime(fields["created_at"]),
      counts: BroadcastCounts.from_map(fields["counts"]),
      workspace_id: fields["workspace_id"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.BroadcastRecipient do
  @moduledoc """
  One contact on one broadcast, and what became of their message.

  `:status` is `"pending"`, `"sent"`, `"skipped"` or `"failed"`.
  `:skip_reason` is set when the status is skipped: `"window_closed"`,
  `"no_conversation"` or `"unsupported_platform"`. `"window_closed"` means the
  network's messaging window had shut, so nothing was attempted.
  """

  alias FoPost.Model

  defstruct [:contact_id, :display_name, :status, :skip_reason, :sent_at, :error, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      contact_id: fields["contact_id"],
      display_name: fields["display_name"],
      status: fields["status"],
      skip_reason: fields["skip_reason"],
      sent_at: Model.datetime(fields["sent_at"]),
      error: fields["error"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.BroadcastSent do
  @moduledoc """
  What a send started.

  `:recipients` is how many contacts matched, not how many will be messaged —
  the messaging window decides that.
  """

  alias FoPost.Model

  defstruct [:id, :status, :recipients, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      status: fields["status"],
      recipients: fields["recipients"] || 0,
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.SequenceStep do
  @moduledoc """
  One message and how long after the previous step it goes out.

  `:delay_hours` on the first step is measured from the enrollment, so 0 means
  straight away.
  """

  alias FoPost.Model

  defstruct [:delay_hours, :text, :media_id, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      delay_hours: fields["delay_hours"] || 0,
      text: fields["text"],
      media_id: fields["media_id"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.EnrollmentCounts do
  @moduledoc "Where a sequence's enrollments stand, by status."

  alias FoPost.Model

  defstruct [:total, :active, :completed, :stopped, :failed, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      total: fields["total"] || 0,
      active: fields["active"] || 0,
      completed: fields["completed"] || 0,
      stopped: fields["stopped"] || 0,
      failed: fields["failed"] || 0,
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Sequence do
  @moduledoc """
  A series of messages, each a delay after the one before.

  `:status` is `"active"` or `"paused"`; a paused sequence fires nothing.
  """

  alias FoPost.EnrollmentCounts
  alias FoPost.Model
  alias FoPost.SequenceStep

  defstruct [
    :id,
    :name,
    :account_id,
    :steps,
    :status,
    :created_at,
    :enrollments,
    :workspace_id,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      account_id: fields["account_id"],
      steps: Model.list(SequenceStep, fields["steps"]),
      status: fields["status"],
      created_at: Model.datetime(fields["created_at"]),
      enrollments: EnrollmentCounts.from_map(fields["enrollments"]),
      workspace_id: fields["workspace_id"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Enrollment do
  @moduledoc """
  One contact walking one sequence.

  `:step` counts the steps already sent, so it is also the index of the next
  one. `:error` carries the reason when a step was skipped rather than sent.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :contact_id,
    :display_name,
    :step,
    :next_at,
    :status,
    :last_sent_at,
    :error,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      contact_id: fields["contact_id"],
      display_name: fields["display_name"],
      step: fields["step"] || 0,
      next_at: Model.datetime(fields["next_at"]),
      status: fields["status"],
      last_sent_at: Model.datetime(fields["last_sent_at"]),
      error: fields["error"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Enrolled do
  @moduledoc "How many contacts a call put on the sequence."

  alias FoPost.Model

  defstruct [:id, :enrolled, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)
    %__MODULE__{id: fields["id"], enrolled: fields["enrolled"] || 0, raw: data}
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Unenrolled do
  @moduledoc "How many enrollments a call stopped."

  alias FoPost.Model

  defstruct [:id, :stopped, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)
    %__MODULE__{id: fields["id"], stopped: fields["stopped"] || 0, raw: data}
  end

  def from_map(_data), do: nil
end
