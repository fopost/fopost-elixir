defmodule FoPost.ProductCatalog do
  @moduledoc """
  A product catalog on the connection's business portfolio, read live.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :vertical,
    :product_count,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      vertical: fields["vertical"],
      product_count: fields["product_count"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.CatalogProduct do
  @moduledoc """
  One product in a catalog. `:price_minor` is minor units of `:currency`.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :retailer_id,
    :name,
    :description,
    :availability,
    :condition,
    :price_minor,
    :currency,
    :image_url,
    :url,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      retailer_id: fields["retailer_id"],
      name: fields["name"],
      description: fields["description"],
      availability: fields["availability"],
      condition: fields["condition"],
      price_minor: fields["price_minor"],
      currency: fields["currency"],
      image_url: fields["image_url"],
      url: fields["url"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.CatalogProductsPage do
  @moduledoc """
  One page of catalog products. Pass `:next_cursor` back as `:after`.
  """

  alias FoPost.Model

  defstruct [
    :products,
    :next_cursor,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      products: Model.list(FoPost.CatalogProduct, fields["products"] || []),
      next_cursor: fields["next_cursor"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.CatalogBatchResult do
  @moduledoc """
  What a catalog product batch was accepted as.
  """

  alias FoPost.Model

  defstruct [
    :handles,
    :accepted,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      handles: fields["handles"],
      accepted: fields["accepted"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ProductFeed do
  @moduledoc """
  Keeps a catalog in step with a product file you host.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :url,
    :schedule,
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
      url: fields["url"],
      schedule: fields["schedule"],
      created_at: fields["created_at"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ProductFeedUpload do
  @moduledoc """
  One run the ad platform made of a product feed.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :started_at,
    :ended_at,
    :status,
    :error_count,
    :warning_count,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      started_at: fields["started_at"],
      ended_at: fields["ended_at"],
      status: fields["status"],
      error_count: fields["error_count"],
      warning_count: fields["warning_count"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ProductSet do
  @moduledoc """
  The slice of a catalog one catalog ad runs from.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :product_count,
    :filter,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      product_count: fields["product_count"],
      filter: fields["filter"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

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

defmodule FoPost.AdLibraryEntry do
  @moduledoc """
  One public archive entry. Read live on every search and stored nowhere.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :page_id,
    :page_name,
    :bodies,
    :titles,
    :link_urls,
    :snapshot_url,
    :publisher_platforms,
    :started_at,
    :ended_at,
    :currency,
    :spend_lower,
    :spend_upper,
    :impressions_lower,
    :impressions_upper,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      page_id: fields["page_id"],
      page_name: fields["page_name"],
      bodies: fields["bodies"],
      titles: fields["titles"],
      link_urls: fields["link_urls"],
      snapshot_url: fields["snapshot_url"],
      publisher_platforms: fields["publisher_platforms"],
      started_at: fields["started_at"],
      ended_at: fields["ended_at"],
      currency: fields["currency"],
      spend_lower: fields["spend_lower"],
      spend_upper: fields["spend_upper"],
      impressions_lower: fields["impressions_lower"],
      impressions_upper: fields["impressions_upper"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AdLibraryPage do
  @moduledoc """
  One page of archive results. Pass `:next_cursor` back as `:after`.
  """

  alias FoPost.Model

  defstruct [
    :entries,
    :next_cursor,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      entries: Model.list(FoPost.AdLibraryEntry, fields["entries"] || []),
      next_cursor: fields["next_cursor"],
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
