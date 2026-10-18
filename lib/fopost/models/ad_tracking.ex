defmodule FoPost.ConversionUploadResult do
  @moduledoc """
  What came of a conversion upload. `:accepted` is how many events the network
  received; `:replayed` is true when the `Idempotency-Key` had been used before and
  nothing was sent again.
  """

  alias FoPost.Model

  defstruct [:id, :accepted, :event_count, :replayed, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      accepted: fields["accepted"] || 0,
      event_count: fields["event_count"],
      replayed: fields["replayed"] || false,
      raw: data
    }
  end
end

defmodule FoPost.HashedConversionEvent do
  @moduledoc """
  One event as a batch stored it: identifiers are kept as hashes only.
  """

  alias FoPost.Model

  defstruct [
    :event_name,
    :occurred_at,
    :event_id,
    :action_source,
    :email_hash,
    :phone_hash,
    :external_id_hash,
    :value_minor,
    :currency,
    :order_id,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      event_name: fields["event_name"],
      occurred_at: Model.datetime(fields["occurred_at"]),
      event_id: fields["event_id"],
      action_source: fields["action_source"],
      email_hash: fields["email_hash"],
      phone_hash: fields["phone_hash"],
      external_id_hash: fields["external_id_hash"],
      value_minor: fields["value_minor"],
      currency: fields["currency"],
      order_id: fields["order_id"],
      raw: data
    }
  end
end

defmodule FoPost.ConversionBatch do
  @moduledoc """
  A stored conversion upload and the hashed events it carried.
  """

  alias FoPost.HashedConversionEvent
  alias FoPost.Model

  defstruct [
    :id,
    :workspace_id,
    :connection_id,
    :ad_account_id,
    :pixel_id,
    :idempotency_key,
    :event_count,
    :accepted,
    :created_at,
    :raw,
    events: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      workspace_id: fields["workspace_id"],
      connection_id: fields["connection_id"],
      ad_account_id: fields["ad_account_id"],
      pixel_id: fields["pixel_id"],
      idempotency_key: fields["idempotency_key"],
      event_count: fields["event_count"],
      accepted: fields["accepted"],
      events: Model.list(HashedConversionEvent, fields["events"]),
      created_at: Model.datetime(fields["created_at"]),
      raw: data
    }
  end
end

defmodule FoPost.AdPixel do
  @moduledoc """
  A pixel on the ad account, as the list answers it.
  """

  alias FoPost.Model

  defstruct [:id, :name, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{id: fields["id"], name: fields["name"], raw: data}
  end
end

defmodule FoPost.AdPixelDetail do
  @moduledoc """
  One pixel. `:code` is the script to place on the site; `:data_use_setting` is
  `advertising_and_analytics` or `analytics_only`.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :code,
    :created_at,
    :last_fired_at,
    :is_unavailable,
    :data_use_setting,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      code: fields["code"],
      created_at: Model.datetime(fields["created_at"]),
      last_fired_at: Model.datetime(fields["last_fired_at"]),
      is_unavailable: fields["is_unavailable"] || false,
      data_use_setting: fields["data_use_setting"],
      raw: data
    }
  end
end

defmodule FoPost.AdPixelEventCount do
  @moduledoc """
  How often one event fired on a pixel inside the stats window.
  """

  alias FoPost.Model

  defstruct [:event_name, :count, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{event_name: fields["event_name"], count: fields["count"] || 0, raw: data}
  end
end

defmodule FoPost.AdPixelStats do
  @moduledoc """
  Event counts on a pixel over the last 28 days.
  """

  alias FoPost.AdPixelEventCount
  alias FoPost.Model

  defstruct [:since, :until, :raw, events: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      since: Model.datetime(fields["since"]),
      until: Model.datetime(fields["until"]),
      events: Model.list(AdPixelEventCount, fields["events"]),
      raw: data
    }
  end
end

defmodule FoPost.EventMatchKey do
  @moduledoc """
  How much of an event's traffic carried one identifier.
  """

  alias FoPost.Model

  defstruct [:identifier, :coverage_percent, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      identifier: fields["identifier"],
      coverage_percent: fields["coverage_percent"],
      raw: data
    }
  end
end

defmodule FoPost.EventMatchQuality do
  @moduledoc """
  The network's match score for one event, out of 10, with the identifiers behind it.
  """

  alias FoPost.EventMatchKey
  alias FoPost.Model

  defstruct [:event_name, :score, :raw, match_keys: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      event_name: fields["event_name"],
      score: fields["score"],
      match_keys: Model.list(EventMatchKey, fields["match_keys"]),
      raw: data
    }
  end
end

defmodule FoPost.CustomConversionRule do
  @moduledoc """
  The pixel event and URL condition a custom conversion counts.
  """

  alias FoPost.Model

  defstruct [:event_name, :url_contains, :url_equals, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      event_name: fields["event_name"],
      url_contains: fields["url_contains"],
      url_equals: fields["url_equals"],
      raw: data
    }
  end
end

defmodule FoPost.CustomConversion do
  @moduledoc """
  A custom conversion on the ad account: a pixel event filtered by a rule and counted
  as a standard event type.
  """

  alias FoPost.CustomConversionRule
  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :pixel_id,
    :event_type,
    :rule,
    :description,
    :default_value_minor,
    :is_archived,
    :is_unavailable,
    :created_at,
    :last_fired_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      pixel_id: fields["pixel_id"],
      event_type: fields["event_type"],
      rule: Model.build(CustomConversionRule, fields["rule"]),
      description: fields["description"],
      default_value_minor: fields["default_value_minor"],
      is_archived: fields["is_archived"] || false,
      is_unavailable: fields["is_unavailable"] || false,
      created_at: Model.datetime(fields["created_at"]),
      last_fired_at: Model.datetime(fields["last_fired_at"]),
      raw: data
    }
  end
end
