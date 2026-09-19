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
