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

defmodule FoPost.AutomationTrigger do
  @moduledoc """
  The run a webhook trigger started.
  """

  alias FoPost.Model

  defstruct [:run_id, :triggered, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      run_id: fields["run_id"],
      triggered: fields["triggered"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AutomationVersionNodeRef do
  @moduledoc """
  A node a version added or removed, by id and kind.
  """

  alias FoPost.Model

  defstruct [:id, :kind, :label, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{id: fields["id"], kind: fields["kind"], label: fields["label"], raw: data}
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WorkflowNode do
  @moduledoc """
  One node of an automation's graph. `:config` is the node's own settings, passed
  through unchanged; `:layout` is its canvas position as a map of `"x"` and `"y"`.
  """

  alias FoPost.Model

  defstruct [:id, :kind, :label, :config, :position, :layout, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      kind: fields["kind"],
      label: fields["label"],
      config: fields["config"],
      position: fields["position"],
      layout: fields["layout"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WorkflowEdge do
  @moduledoc """
  One connection between two nodes of an automation's graph.
  """

  alias FoPost.Model

  defstruct [:id, :source, :source_handle, :target, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      source: fields["source"],
      source_handle: fields["source_handle"],
      target: fields["target"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WorkflowGraph do
  @moduledoc """
  The nodes and edges of an automation at one version.
  """

  alias FoPost.Model
  alias FoPost.WorkflowEdge
  alias FoPost.WorkflowNode

  defstruct [:raw, nodes: [], edges: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      nodes: Model.list(WorkflowNode, fields["nodes"]),
      edges: Model.list(WorkflowEdge, fields["edges"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AutomationVersion do
  @moduledoc """
  One saved version of an automation.

  The list view carries `:node_count` and what changed (`:nodes_added`,
  `:nodes_removed`); `FoPost.Automations.version/3` fills `:graph` instead.
  `:created_by` is a map with the author's `"name"`, or `nil`.
  """

  alias FoPost.AutomationVersionNodeRef
  alias FoPost.Model
  alias FoPost.WorkflowGraph

  defstruct [
    :version,
    :note,
    :created_by,
    :created_at,
    :node_count,
    :graph,
    :raw,
    nodes_added: [],
    nodes_removed: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      version: fields["version"],
      note: fields["note"],
      created_by: author(fields["created_by"]),
      created_at: Model.datetime(fields["created_at"]),
      node_count: fields["node_count"],
      nodes_added: Model.list(AutomationVersionNodeRef, fields["nodes_added"]),
      nodes_removed: Model.list(AutomationVersionNodeRef, fields["nodes_removed"]),
      graph: Model.build(WorkflowGraph, fields["graph"]),
      raw: data
    }
  end

  def from_map(_data), do: nil

  defp author(nil), do: nil
  defp author(data), do: Model.normalize(data)
end

defmodule FoPost.AutomationRestore do
  @moduledoc """
  What restoring a version answers: the new version number, the graph now in force,
  and the steps compiled from it.
  """

  alias FoPost.AutomationStep
  alias FoPost.Model
  alias FoPost.WorkflowGraph

  defstruct [:version, :graph, :raw, steps: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      version: fields["version"],
      graph: Model.build(WorkflowGraph, fields["graph"]),
      steps: Model.list(AutomationStep, fields["steps"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
