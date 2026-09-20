defmodule FoPost.GoogleKeyword do
  @moduledoc """
  A keyword on an ad group.

  `id` is `<customer_id>~keyword~<ad_group_id>~<criterion_id>`: a Google resource name
  has slashes and cannot ride in a URL path segment, so every id here carries the
  account it belongs to.
  """

  alias FoPost.Model

  defstruct [:id, :ad_group_id, :text, :match_type, :status, :cpc_bid_minor, :negative, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      ad_group_id: fields["ad_group_id"],
      text: fields["text"],
      match_type: fields["match_type"],
      status: fields["status"],
      cpc_bid_minor: fields["cpc_bid_minor"],
      negative: fields["negative"] || false,
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.GoogleKeywordIdea do
  @moduledoc """
  A keyword idea, or the historical metrics of one.
  """

  alias FoPost.Model

  defstruct [
    :text,
    :avg_monthly_searches,
    :competition,
    :low_top_of_page_bid_minor,
    :high_top_of_page_bid_minor,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      text: fields["text"],
      avg_monthly_searches: fields["avg_monthly_searches"] || 0,
      competition: fields["competition"],
      low_top_of_page_bid_minor: fields["low_top_of_page_bid_minor"],
      high_top_of_page_bid_minor: fields["high_top_of_page_bid_minor"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.GoogleSearchTerm do
  @moduledoc """
  What someone actually searched, with the metrics it earned.
  """

  alias FoPost.Model

  defstruct [:term, :ad_group_id, :status, :metrics, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      term: fields["term"],
      ad_group_id: fields["ad_group_id"],
      status: fields["status"],
      metrics: fields["metrics"] || %{},
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.GoogleBidStrategy do
  @moduledoc """
  A portfolio bid strategy on the account.
  """

  alias FoPost.Model

  defstruct [:id, :name, :type, :status, :campaign_count, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      type: fields["type"],
      status: fields["status"],
      campaign_count: fields["campaign_count"] || 0,
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.GoogleAdScheduleSlot do
  @moduledoc """
  One slot of a campaign's ad schedule.
  """

  alias FoPost.Model

  defstruct [:id, :day_of_week, :start_hour, :end_hour, :bid_modifier, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      day_of_week: fields["day_of_week"],
      start_hour: fields["start_hour"] || 0,
      end_hour: fields["end_hour"] || 0,
      bid_modifier: fields["bid_modifier"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.GoogleSharedSet do
  @moduledoc """
  A negative keyword list.
  """

  alias FoPost.Model

  defstruct [:id, :name, :type, :member_count, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      type: fields["type"],
      member_count: fields["member_count"] || 0,
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.GoogleAsset do
  @moduledoc """
  A sitelink, callout, or structured snippet.
  """

  alias FoPost.Model

  defstruct [:id, :name, :type, :text, :final_url, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      type: fields["type"],
      text: fields["text"],
      final_url: fields["final_url"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.GoogleAssetLink do
  @moduledoc """
  Where an asset is attached; one with no links serves nowhere.
  """

  alias FoPost.Model

  defstruct [:id, :asset_id, :level, :owner_id, :field_type, :status, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      asset_id: fields["asset_id"],
      level: fields["level"],
      owner_id: fields["owner_id"],
      field_type: fields["field_type"],
      status: fields["status"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.GoogleAssets do
  @moduledoc """
  The account's assets with the links that place them.
  """

  alias FoPost.GoogleAsset
  alias FoPost.GoogleAssetLink
  alias FoPost.Model

  defstruct assets: [], links: [], raw: nil

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      assets: Model.list(GoogleAsset, fields["assets"] || []),
      links: Model.list(GoogleAssetLink, fields["links"] || []),
      raw: data
    }
  end

  def from_map(_data), do: %__MODULE__{}
end

defmodule FoPost.GoogleAssetGroup do
  @moduledoc """
  A Performance Max asset group.
  """

  alias FoPost.Model

  defstruct [:id, :campaign_id, :name, :status, :final_urls, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      campaign_id: fields["campaign_id"],
      name: fields["name"],
      status: fields["status"],
      final_urls: fields["final_urls"] || [],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.GoogleLocalServicesLead do
  @moduledoc """
  A lead from Local Services Ads, read live and never stored.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :category,
    :service,
    :contact_name,
    :phone,
    :email,
    :status,
    :type,
    :created_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      category: fields["category"],
      service: fields["service"],
      contact_name: fields["contact_name"],
      phone: fields["phone"],
      email: fields["email"],
      status: fields["status"],
      type: fields["type"],
      created_at: fields["created_at"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.GoogleConversionAction do
  @moduledoc """
  A conversion action on the account.
  """

  alias FoPost.Model

  defstruct [:id, :name, :category, :status, :type, :counting_type, :value_minor, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      category: fields["category"],
      status: fields["status"],
      type: fields["type"],
      counting_type: fields["counting_type"],
      value_minor: fields["value_minor"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end
