defmodule FoPost.AdTargeting do
  @moduledoc """
  Who an ad is shown to. `:locations`, `:interests`, `:behaviors`, and `:income` are
  lists of maps as Meta names them, from `FoPost.Ads.search_targeting/2`.
  """

  alias FoPost.Model

  defstruct [
    :age_min,
    :age_max,
    :gender,
    :raw,
    countries: [],
    audience_ids: [],
    locations: [],
    interests: [],
    behaviors: [],
    income: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      countries: List.wrap(fields["countries"]),
      age_min: fields["age_min"],
      age_max: fields["age_max"],
      gender: fields["gender"],
      audience_ids: List.wrap(fields["audience_ids"]),
      locations: Model.maps(fields["locations"]),
      interests: Model.maps(fields["interests"]),
      behaviors: Model.maps(fields["behaviors"]),
      income: Model.maps(fields["income"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AdInsights do
  @moduledoc """
  Lifetime delivery numbers as of the ad's last refresh. `:spend_minor` is in the ad
  account's currency, minor units.
  """

  alias FoPost.Model

  defstruct [:impressions, :reach, :clicks, :spend_minor, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      impressions: fields["impressions"],
      reach: fields["reach"],
      clicks: fields["clicks"],
      spend_minor: fields["spend_minor"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Ad do
  @moduledoc """
  A boost or ad created through FoPost. `:kind` is `"boost"` or `"ad"`; `:status` is what
  you set (`"active"` or `"paused"`) and `:effective_status` is what Meta reports.
  """

  alias FoPost.AdInsights
  alias FoPost.AdTargeting
  alias FoPost.Model

  defstruct [
    :id,
    :workspace_id,
    :kind,
    :name,
    :goal,
    :status,
    :effective_status,
    :connection_id,
    :account_id,
    :platform,
    :ad_account_id,
    :source_post_id,
    :budget_minor,
    :budget_type,
    :currency,
    :end_at,
    :targeting,
    :creative,
    :insights,
    :insights_at,
    :last_error,
    :created_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      workspace_id: fields["workspace_id"],
      kind: fields["kind"],
      name: fields["name"],
      goal: fields["goal"],
      status: fields["status"],
      effective_status: fields["effective_status"],
      connection_id: fields["connection_id"],
      account_id: fields["account_id"],
      platform: fields["platform"],
      ad_account_id: fields["ad_account_id"],
      source_post_id: fields["source_post_id"],
      budget_minor: fields["budget_minor"],
      budget_type: fields["budget_type"],
      currency: fields["currency"],
      end_at: Model.datetime(fields["end_at"]),
      targeting: Model.build(AdTargeting, fields["targeting"]),
      creative: Model.normalize(fields["creative"]),
      insights: Model.build(AdInsights, fields["insights"]),
      insights_at: Model.datetime(fields["insights_at"]),
      last_error: fields["last_error"],
      created_at: Model.datetime(fields["created_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ExternalAd do
  @moduledoc """
  An ad on a connected ad account that was made outside FoPost. Read live, never stored.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :effective_status,
    :campaign_id,
    :campaign_name,
    :objective,
    :budget_minor,
    :budget_type,
    :end_at,
    :created_at,
    :connection_id,
    :ad_account_id,
    :currency,
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
      effective_status: fields["effective_status"],
      campaign_id: fields["campaign_id"],
      campaign_name: fields["campaign_name"],
      objective: fields["objective"],
      budget_minor: fields["budget_minor"],
      budget_type: fields["budget_type"],
      end_at: Model.datetime(fields["end_at"]),
      created_at: Model.datetime(fields["created_at"]),
      connection_id: fields["connection_id"],
      ad_account_id: fields["ad_account_id"],
      currency: fields["currency"],
      workspace_id: fields["workspace_id"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.BoostablePost do
  @moduledoc """
  A published post that can be boosted, with the deliveries a boost can start from.
  """

  alias FoPost.Model

  defstruct [:id, :workspace_id, :text, :thumbnail_url, :raw, deliveries: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      workspace_id: fields["workspace_id"],
      text: fields["text"],
      thumbnail_url: fields["thumbnail_url"],
      deliveries: Model.maps(fields["deliveries"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AdConnection do
  @moduledoc """
  A connected ads login. `:auth_type` says whether it was a business or a user login.
  """

  alias FoPost.Model

  defstruct [:id, :provider, :auth_type, :name, :business_id, :created_at, :workspace_id, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      provider: fields["provider"],
      auth_type: fields["auth_type"],
      name: fields["name"],
      business_id: fields["business_id"],
      created_at: Model.datetime(fields["created_at"]),
      workspace_id: fields["workspace_id"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AdSource do
  @moduledoc """
  One connection with the ad accounts and Pages its grant reaches, as lists of maps.
  `:error` is set when the provider could not be read.
  """

  alias FoPost.Model

  defstruct [:connection_id, :name, :workspace_id, :error, :raw, ad_accounts: [], pages: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      connection_id: fields["connection_id"],
      name: fields["name"],
      workspace_id: fields["workspace_id"],
      ad_accounts: Model.maps(fields["ad_accounts"]),
      pages: Model.maps(fields["pages"]),
      error: fields["error"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Audience do
  @moduledoc """
  A saved audience on an ad account.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :subtype,
    :description,
    :size_lower,
    :size_upper,
    :delivery_status,
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
      subtype: fields["subtype"],
      description: fields["description"],
      size_lower: fields["size_lower"],
      size_upper: fields["size_upper"],
      delivery_status: fields["delivery_status"],
      created_at: Model.datetime(fields["created_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AudiencesResult do
  @moduledoc """
  The audiences and pixels on an ad account. `:pixels` is a list of maps of `id` and `name`.
  """

  alias FoPost.Audience
  alias FoPost.Model

  defstruct [:workspace_id, :raw, audiences: [], pixels: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      audiences: Model.list(Audience, fields["audiences"]),
      pixels: Model.maps(fields["pixels"]),
      workspace_id: fields["workspace_id"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.CreatedAudience do
  @moduledoc """
  A newly created audience: its id and, for a customer list, how many emails were accepted.
  """

  alias FoPost.Model

  defstruct [:id, :added, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      added: fields["added"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.TargetingOption do
  @moduledoc """
  One location, interest, behaviour, or income bracket as Meta names it.
  """

  alias FoPost.Model

  defstruct [:id, :name, :detail, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      detail: fields["detail"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.LeadForm do
  @moduledoc """
  An Instant Form on a Page.
  """

  alias FoPost.Model

  defstruct [:id, :name, :status, :leads_count, :created_at, :raw, questions: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      status: fields["status"],
      leads_count: fields["leads_count"],
      created_at: Model.datetime(fields["created_at"]),
      questions: List.wrap(fields["questions"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.LeadFormSource do
  @moduledoc """
  One connection and Page with the lead forms on it.
  """

  alias FoPost.LeadForm
  alias FoPost.Model

  defstruct [
    :connection_id,
    :connection_name,
    :page_id,
    :page_name,
    :error,
    :workspace_id,
    :raw,
    forms: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      connection_id: fields["connection_id"],
      connection_name: fields["connection_name"],
      page_id: fields["page_id"],
      page_name: fields["page_name"],
      forms: Model.list(LeadForm, fields["forms"]),
      error: fields["error"],
      workspace_id: fields["workspace_id"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Lead do
  @moduledoc """
  One submission of a lead form. `:fields` is a list of maps of `name` and `values`.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :created_at,
    :ad_name,
    :campaign_name,
    :platform,
    :is_organic,
    :raw,
    fields: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      created_at: Model.datetime(fields["created_at"]),
      fields: Model.maps(fields["fields"]),
      ad_name: fields["ad_name"],
      campaign_name: fields["campaign_name"],
      platform: fields["platform"],
      is_organic: fields["is_organic"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.LeadsPage do
  @moduledoc """
  One page of leads. Pass `:next_cursor` back as `:after` for the next page; `nil` means
  there is none.
  """

  alias FoPost.Lead
  alias FoPost.Model

  defstruct [:next_cursor, :raw, leads: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      leads: Model.list(Lead, fields["leads"]),
      next_cursor: fields["next_cursor"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.NetworkAd do
  @moduledoc """
  A Meta ad inside an ad set, read live from Meta by its Meta id.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :campaign_id,
    :ad_set_id,
    :creative_id,
    :status,
    :effective_status,
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
      campaign_id: fields["campaign_id"],
      ad_set_id: fields["ad_set_id"],
      creative_id: fields["creative_id"],
      status: fields["status"],
      effective_status: fields["effective_status"],
      created_at: Model.datetime(fields["created_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AdSet do
  @moduledoc """
  A Meta ad set, read live. `:ads` is filled only inside `FoPost.AdAccountTree`.
  """

  alias FoPost.Model
  alias FoPost.NetworkAd

  defstruct [
    :id,
    :name,
    :campaign_id,
    :status,
    :effective_status,
    :budget_minor,
    :budget_type,
    :end_at,
    :optimization_goal,
    :created_at,
    :raw,
    ads: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      campaign_id: fields["campaign_id"],
      status: fields["status"],
      effective_status: fields["effective_status"],
      budget_minor: fields["budget_minor"],
      budget_type: fields["budget_type"],
      end_at: Model.datetime(fields["end_at"]),
      optimization_goal: fields["optimization_goal"],
      created_at: Model.datetime(fields["created_at"]),
      ads: Model.list(NetworkAd, fields["ads"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AdCampaign do
  @moduledoc """
  A Meta campaign, read live. `:ad_sets` is filled only inside `FoPost.AdAccountTree`.
  """

  alias FoPost.AdSet
  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :status,
    :effective_status,
    :objective,
    :budget_minor,
    :budget_type,
    :created_at,
    :raw,
    ad_sets: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      status: fields["status"],
      effective_status: fields["effective_status"],
      objective: fields["objective"],
      budget_minor: fields["budget_minor"],
      budget_type: fields["budget_type"],
      created_at: Model.datetime(fields["created_at"]),
      ad_sets: Model.list(AdSet, fields["ad_sets"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AdAccountTree do
  @moduledoc """
  The campaigns on an ad account with their ad sets and ads, read live from Meta.
  """

  alias FoPost.AdCampaign
  alias FoPost.Model

  defstruct [:ad_account_id, :currency, :workspace_id, :raw, campaigns: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      ad_account_id: fields["ad_account_id"],
      currency: fields["currency"],
      workspace_id: fields["workspace_id"],
      campaigns: Model.list(AdCampaign, fields["campaigns"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.BulkAdStatusResult do
  @moduledoc """
  The outcome for one object of `FoPost.Ads.bulk_set_status/2`.
  """

  alias FoPost.Model

  defstruct [:id, :level, :ok, :error, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      level: fields["level"],
      ok: fields["ok"],
      error: fields["error"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AdCreative do
  @moduledoc """
  A creative on an ad account. `:format` is `image`, `video`, `carousel`, `post`, or `other`.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :format,
    :status,
    :title,
    :body,
    :link,
    :thumbnail_url,
    :call_to_action,
    :url_tags,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      format: fields["format"],
      status: fields["status"],
      title: fields["title"],
      body: fields["body"],
      link: fields["link"],
      thumbnail_url: fields["thumbnail_url"],
      call_to_action: fields["call_to_action"],
      url_tags: fields["url_tags"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ReachEstimate do
  @moduledoc """
  The audience size Meta estimates for a targeting spec. `:ready` is false while Meta is still computing it.
  """

  alias FoPost.Model

  defstruct [:lower, :upper, :ready, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      lower: fields["lower"],
      upper: fields["upper"],
      ready: fields["ready"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.InsightsMetrics do
  @moduledoc """
  Delivery numbers. `:spend_minor` is in the ad account currency, minor units; `:ctr` is a percentage.
  """

  alias FoPost.Model

  defstruct [:impressions, :reach, :clicks, :spend_minor, :ctr, :leads, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      impressions: fields["impressions"],
      reach: fields["reach"],
      clicks: fields["clicks"],
      spend_minor: fields["spend_minor"],
      ctr: fields["ctr"],
      leads: fields["leads"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.InsightsBreakdownRow do
  @moduledoc """
  One row of an insights breakdown, keyed by the age band, gender, placement, or country.
  """

  alias FoPost.InsightsMetrics
  alias FoPost.Model

  defstruct [:key, :metrics, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      key: fields["key"],
      metrics: Model.build(InsightsMetrics, fields["metrics"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.InsightsTimelineRow do
  @moduledoc """
  One day of an insights timeline.
  """

  alias FoPost.InsightsMetrics
  alias FoPost.Model

  defstruct [:date, :metrics, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      date: fields["date"],
      metrics: Model.build(InsightsMetrics, fields["metrics"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AdInsightsReport do
  @moduledoc """
  Insights for one campaign, ad set, or ad over a date range.
  """

  alias FoPost.InsightsBreakdownRow
  alias FoPost.InsightsMetrics
  alias FoPost.InsightsTimelineRow
  alias FoPost.Model

  defstruct [
    :object_id,
    :currency,
    :since,
    :until,
    :breakdown_by,
    :totals,
    :raw,
    breakdown: [],
    timeline: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      object_id: fields["object_id"],
      currency: fields["currency"],
      since: fields["since"],
      until: fields["until"],
      breakdown_by: fields["breakdown_by"],
      totals: Model.build(InsightsMetrics, fields["totals"]),
      breakdown: Model.list(InsightsBreakdownRow, fields["breakdown"]),
      timeline: Model.list(InsightsTimelineRow, fields["timeline"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.LeadFormDetail do
  @moduledoc """
  One Instant Form with its questions and settings.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :status,
    :leads_count,
    :created_at,
    :page_id,
    :privacy_policy_url,
    :locale,
    :raw,
    questions: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      status: fields["status"],
      leads_count: fields["leads_count"],
      created_at: Model.datetime(fields["created_at"]),
      page_id: fields["page_id"],
      privacy_policy_url: fields["privacy_policy_url"],
      locale: fields["locale"],
      questions: List.wrap(fields["questions"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.FeedLead do
  @moduledoc """
  A lead stored from a subscribed Page. `:fields` is a list of maps of `name` and `values`.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :lead_id,
    :connection_id,
    :page_id,
    :form_id,
    :ad_id,
    :ad_name,
    :campaign_name,
    :platform,
    :is_organic,
    :submitted_at,
    :workspace_id,
    :raw,
    fields: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      lead_id: fields["lead_id"],
      connection_id: fields["connection_id"],
      page_id: fields["page_id"],
      form_id: fields["form_id"],
      ad_id: fields["ad_id"],
      ad_name: fields["ad_name"],
      campaign_name: fields["campaign_name"],
      platform: fields["platform"],
      is_organic: fields["is_organic"],
      submitted_at: Model.datetime(fields["submitted_at"]),
      workspace_id: fields["workspace_id"],
      fields: Model.maps(fields["fields"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.LeadsFeedPage do
  @moduledoc """
  One page of the leads feed. Pass `:next_cursor` back as `:cursor` for the next page; `nil` means there is none.
  """

  alias FoPost.FeedLead
  alias FoPost.Model

  defstruct [:next_cursor, :raw, leads: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      next_cursor: fields["next_cursor"],
      leads: Model.list(FeedLead, fields["leads"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.LeadPage do
  @moduledoc """
  A Page subscribed to lead delivery.
  """

  alias FoPost.Model

  defstruct [:connection_id, :page_id, :page_name, :created_at, :workspace_id, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      connection_id: fields["connection_id"],
      page_id: fields["page_id"],
      page_name: fields["page_name"],
      created_at: Model.datetime(fields["created_at"]),
      workspace_id: fields["workspace_id"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.LeadPageSubscription do
  @moduledoc """
  A new lead delivery subscription and how many existing leads were backfilled.
  """

  alias FoPost.Model

  defstruct [:page_id, :backfilled, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      page_id: fields["page_id"],
      backfilled: fields["backfilled"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AdBusinessCenter do
  @moduledoc """
  A Business Center, or the network's equivalent grouping of ad accounts.
  """

  alias FoPost.Model

  defstruct [:id, :name, :role, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      role: fields["role"],
      raw: data
    }
  end
end

defmodule FoPost.AdIdentity do
  @moduledoc """
  The account an ad runs as. Meta calls it a Page, TikTok an identity; an
  identity id is what every route calls a `page_id`. `type` is the network's
  own identity kind, e.g. `CUSTOMIZED_USER`.
  """

  alias FoPost.Model

  defstruct [:id, :type, :name, :avatar_url, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      type: fields["type"],
      name: fields["name"],
      avatar_url: fields["avatar_url"],
      raw: data
    }
  end
end

defmodule FoPost.SparkPost do
  @moduledoc """
  A post already live on the network, offered as the source of a Spark ad.
  """

  alias FoPost.Model

  defstruct [:id, :identity_id, :caption, :thumbnail_url, :created_at, :views, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      identity_id: fields["identity_id"],
      caption: fields["caption"],
      thumbnail_url: fields["thumbnail_url"],
      created_at: fields["created_at"],
      views: fields["views"],
      raw: data
    }
  end
end

defmodule FoPost.AdComment do
  @moduledoc """
  A comment on an ad, read live from the network and never stored.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :ad_id,
    :text,
    :author_name,
    :author_avatar_url,
    :created_at,
    :likes,
    :reply_count,
    :hidden,
    :parent_id,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      ad_id: fields["ad_id"],
      text: fields["text"] || "",
      author_name: fields["author_name"],
      author_avatar_url: fields["author_avatar_url"],
      created_at: fields["created_at"],
      likes: fields["likes"] || 0,
      reply_count: fields["reply_count"] || 0,
      hidden: fields["hidden"] || false,
      parent_id: fields["parent_id"],
      raw: data
    }
  end
end

defmodule FoPost.AdCommentsPage do
  @moduledoc """
  One page of an ad's comments; pass `next_cursor` back as `:after`.
  """

  alias FoPost.AdComment
  alias FoPost.Model

  defstruct comments: [], next_cursor: nil, raw: nil

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      comments: Model.list(AdComment, fields["comments"] || []),
      next_cursor: fields["next_cursor"],
      raw: data
    }
  end
end
