defmodule FoPost.ReachFrequencyPrediction do
  @moduledoc """
  A priced flight. Nothing is bought until it is reserved; `:reserved` says whether it is.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :status,
    :reach,
    :impressions,
    :frequency_cap,
    :budget_minor,
    :start_at,
    :end_at,
    :reserved,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      status: fields["status"],
      reach: fields["reach"],
      impressions: fields["impressions"],
      frequency_cap: fields["frequency_cap"],
      budget_minor: fields["budget_minor"],
      start_at: fields["start_at"],
      end_at: fields["end_at"],
      reserved: fields["reserved"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ReachFrequencyResult do
  @moduledoc """
  The reach-and-frequency predictions on one ad account.
  """

  alias FoPost.Model

  defstruct [
    :predictions,
    :workspace_id,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      predictions: Model.list(FoPost.ReachFrequencyPrediction, fields["predictions"] || []),
      workspace_id: fields["workspace_id"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.PartnershipCreator do
  @moduledoc """
  A creator who allowlisted this advertiser for partnership ads.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :username,
    :name,
    :status,
    :permissions,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      username: fields["username"],
      name: fields["name"],
      status: fields["status"],
      permissions: fields["permissions"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AdActivity do
  @moduledoc """
  One change recorded on an ad account.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :event_type,
    :actor_name,
    :object_name,
    :object_type,
    :extra_data,
    :created_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      event_type: fields["event_type"],
      actor_name: fields["actor_name"],
      object_name: fields["object_name"],
      object_type: fields["object_type"],
      extra_data: fields["extra_data"],
      created_at: fields["created_at"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AdActivityResult do
  @moduledoc """
  The change log of one ad account.
  """

  alias FoPost.Model

  defstruct [
    :activity,
    :workspace_id,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      activity: Model.list(FoPost.AdActivity, fields["activity"] || []),
      workspace_id: fields["workspace_id"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AdLabel do
  @moduledoc """
  Groups campaigns, ad sets, and ads for reporting.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :created_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      created_at: fields["created_at"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AdStudy do
  @moduledoc """
  An A/B study splitting traffic across its cells.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :description,
    :type,
    :status,
    :start_at,
    :end_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      description: fields["description"],
      type: fields["type"],
      status: fields["status"],
      start_at: fields["start_at"],
      end_at: fields["end_at"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.IosCampaignLimits do
  @moduledoc """
  How many iOS 14 campaigns an ad account may run at once, per app.
  """

  alias FoPost.Model

  defstruct [
    :limit,
    :used,
    :app_id,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      limit: fields["limit"],
      used: fields["used"],
      app_id: fields["app_id"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.HighDemandPeriod do
  @moduledoc """
  A window the ad platform should expect heavier spend over.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :start_at,
    :end_at,
    :budget_value,
    :budget_value_type,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      start_at: fields["start_at"],
      end_at: fields["end_at"],
      budget_value: fields["budget_value"],
      budget_value_type: fields["budget_value_type"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ValueRuleSet do
  @moduledoc """
  Weights conversions so some audiences count for more than others.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :status,
    :rules,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      status: fields["status"],
      rules: fields["rules"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end
