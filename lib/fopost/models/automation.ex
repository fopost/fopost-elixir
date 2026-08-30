defmodule FoPost.AutomationStep do
  @moduledoc """
  One action in an automation, in position order.

  `:action_type` is `"publish"`, `"delay"`, or `"transform"`; `:action_config` is the
  action's own options, passed through unchanged.
  """

  alias FoPost.Model

  defstruct [:id, :position, :action_type, :action_config, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      position: fields["position"],
      action_type: fields["action_type"],
      action_config: fields["action_config"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Automation do
  @moduledoc """
  A trigger and the steps behind it.

  `:trigger_type` is `"cross_post"`, `"rss_feed"`, `"api_webhook"`, or `"schedule"`.
  `:secret` comes back once, from `FoPost.Automations.create/2`, for an `api_webhook`
  trigger.
  """

  alias FoPost.AutomationStep
  alias FoPost.Model

  defstruct [
    :id,
    :workspace_id,
    :name,
    :trigger_type,
    :trigger_config,
    :active,
    :last_triggered_at,
    :run_count,
    :secret,
    :created_at,
    :updated_at,
    :raw,
    steps: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      workspace_id: fields["workspace_id"],
      name: fields["name"],
      trigger_type: fields["trigger_type"],
      trigger_config: fields["trigger_config"],
      active: fields["active"],
      last_triggered_at: Model.datetime(fields["last_triggered_at"]),
      run_count: fields["run_count"],
      steps: Model.list(AutomationStep, fields["steps"]),
      secret: fields["secret"],
      created_at: Model.datetime(fields["created_at"]),
      updated_at: Model.datetime(fields["updated_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AutomationRun do
  @moduledoc """
  One execution of an automation, with a log per step when fetched on its own.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :automation_id,
    :status,
    :current_step,
    :trigger_event,
    :context,
    :started_at,
    :completed_at,
    :error_message,
    :raw,
    logs: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      automation_id: fields["automation_id"],
      status: fields["status"],
      current_step: fields["current_step"],
      trigger_event: fields["trigger_event"],
      context: fields["context"],
      started_at: Model.datetime(fields["started_at"]),
      completed_at: Model.datetime(fields["completed_at"]),
      error_message: fields["error_message"],
      logs: Model.maps(fields["logs"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AutomationStats do
  @moduledoc """
  Automation counts and the runs of the last day.
  """

  alias FoPost.Model

  defstruct [
    :total_automations,
    :active_automations,
    :total_runs_24h,
    :runs_by_status,
    :raw,
    recent_runs: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      total_automations: fields["total_automations"],
      active_automations: fields["active_automations"],
      total_runs_24h: fields["total_runs24h"],
      runs_by_status: fields["runs_by_status"],
      recent_runs: Model.maps(fields["recent_runs"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
