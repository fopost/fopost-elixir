defmodule FoPost.Ads do
  @moduledoc """
  Ads across ad networks: boosts, standalone ads, audiences, targeting, and lead forms.

  Every function needs the `ads` scope. `boost/2`, `create/2`, `set_status/3`,
  `delete/3`, `bulk_set_status/2`, and the create, update, delete, and duplicate
  functions for campaigns, ad sets, and network ads spend money and also need the
  `publish` scope. A boost, campaign, ad set, or ad starts paused unless `:paused` is
  `false`.

  Campaigns, ad sets, network ads, creatives, and audiences are addressed by their Meta
  id and read live from Meta, so those calls take `:connection_id` as well.

      {:ok, ad} =
        FoPost.Ads.boost(client,
          workspace_id: workspace.id,
          connection_id: connection.id,
          ad_account_id: "act_123",
          post_id: post.id,
          account_id: account.id,
          name: "Launch week",
          goal: "engagement",
          budget: %{minor: 5_000, type: "daily"},
          targeting: %{countries: ["US"], ageMin: 18, ageMax: 65, gender: "all"}
        )

  `:budget` and `:targeting` are sent as given, so spell their keys the way the API
  does (`minor`, `type`, `endAt`; `countries`, `ageMin`, `ageMax`, `gender`,
  `audienceIds`, `locations`, `interests`, `behaviors`, `income`).
  """

  alias FoPost.Ad
  alias FoPost.AdAccountTree
  alias FoPost.AdCampaign
  alias FoPost.AdConnection
  alias FoPost.AdCreative
  alias FoPost.AdInsightsReport
  alias FoPost.AdSet
  alias FoPost.AdSource
  alias FoPost.Audience
  alias FoPost.AudiencesResult
  alias FoPost.BoostablePost
  alias FoPost.BulkAdStatusResult
  alias FoPost.Client
  alias FoPost.CreatedAudience
  alias FoPost.ExternalAd
  alias FoPost.LeadFormDetail
  alias FoPost.LeadFormSource
  alias FoPost.LeadPage
  alias FoPost.LeadPageSubscription
  alias FoPost.LeadsFeedPage
  alias FoPost.LeadsPage
  alias FoPost.Message
  alias FoPost.Model
  alias FoPost.NetworkAd
  alias FoPost.ReachEstimate
  alias FoPost.Result
  alias FoPost.TargetingOption

  @spend_fields [
    {:workspace_id, "workspaceId"},
    {:connection_id, "connectionId"},
    {:ad_account_id, "adAccountId"},
    :name,
    :goal,
    :budget,
    :targeting,
    :paused
  ]

  @boost_fields @spend_fields ++ [{:post_id, "postId"}, {:account_id, "accountId"}]

  @create_fields @spend_fields ++
                   [
                     {:page_id, "pageId"},
                     :text,
                     :headline,
                     {:destination_url, "destinationUrl"},
                     {:media_url, "mediaUrl"},
                     {:url_tags, "urlTags"}
                   ]

  @campaign_fields [
    {:workspace_id, "workspaceId"},
    {:connection_id, "connectionId"},
    {:ad_account_id, "adAccountId"},
    :name,
    :goal,
    :paused
  ]

  @ad_set_fields [
    {:workspace_id, "workspaceId"},
    {:connection_id, "connectionId"},
    {:campaign_id, "campaignId"},
    {:page_id, "pageId"},
    :name,
    :goal,
    :budget,
    :targeting,
    :paused
  ]

  @ad_set_update_fields [
    :name,
    :status,
    {:budget_minor, "budgetMinor"},
    {:end_at, "endAt"},
    :targeting
  ]

  @network_ad_fields [
    {:workspace_id, "workspaceId"},
    {:connection_id, "connectionId"},
    {:ad_set_id, "adSetId"},
    {:creative_id, "creativeId"},
    :name,
    :paused
  ]

  @creative_fields [
    {:workspace_id, "workspaceId"},
    {:connection_id, "connectionId"},
    {:ad_account_id, "adAccountId"},
    {:page_id, "pageId"},
    :name,
    :format,
    :text,
    :headline,
    {:destination_url, "destinationUrl"},
    {:call_to_action, "callToAction"},
    {:url_tags, "urlTags"},
    {:media_url, "mediaUrl"},
    {:thumbnail_media_url, "thumbnailMediaUrl"},
    :cards
  ]

  @page_fields [
    {:workspace_id, "workspaceId"},
    {:connection_id, "connectionId"},
    {:page_id, "pageId"}
  ]

  @insights_params [:since, :until, :breakdown, :daily]

  @audience_fields [
    {:workspace_id, "workspaceId"},
    {:connection_id, "connectionId"},
    {:ad_account_id, "adAccountId"},
    :name,
    :description,
    :spec
  ]

  @lead_form_fields [
    {:workspace_id, "workspaceId"},
    {:connection_id, "connectionId"},
    {:page_id, "pageId"},
    :name,
    :questions,
    {:privacy_policy_url, "privacyPolicyUrl"},
    {:thank_you_message, "thankYouMessage"},
    {:follow_up_url, "followUpUrl"}
  ]

  @doc """
  Boosts and ads created through FoPost, with insights from their last refresh.
  Optionally narrowed with `:workspace_id`.
  """
  @spec list(Client.t(), keyword()) :: {:ok, [Ad.t()]} | {:error, FoPost.Error.t()}
  def list(client, opts \\ []) do
    with {:ok, data} <- get(client, "/ads", opts) do
      {:ok, Model.list(Ad, data)}
    end
  end

  @doc """
  Ads on the connected ad accounts that were made elsewhere. Read live, never stored.
  """
  @spec external(Client.t(), keyword()) :: {:ok, [ExternalAd.t()]} | {:error, FoPost.Error.t()}
  def external(client, opts \\ []) do
    with {:ok, data} <- get(client, "/ads/external", opts) do
      {:ok, Model.list(ExternalAd, data)}
    end
  end

  @doc """
  Published posts a boost can start from.
  """
  @spec boostable(Client.t(), keyword()) ::
          {:ok, [BoostablePost.t()]} | {:error, FoPost.Error.t()}
  def boostable(client, opts \\ []) do
    with {:ok, data} <- get(client, "/ads/boostable", opts) do
      {:ok, Model.list(BoostablePost, data)}
    end
  end

  @doc """
  The ads logins connected to the workspace.
  """
  @spec connections(Client.t(), keyword()) ::
          {:ok, [AdConnection.t()]} | {:error, FoPost.Error.t()}
  def connections(client, opts \\ []) do
    with {:ok, data} <- get(client, "/ads/connections", opts) do
      {:ok, Model.list(AdConnection, data)}
    end
  end

  @doc """
  Each connection with the ad accounts and Pages its grant reaches.
  """
  @spec sources(Client.t(), keyword()) :: {:ok, [AdSource.t()]} | {:error, FoPost.Error.t()}
  def sources(client, opts \\ []) do
    with {:ok, data} <- get(client, "/ads/sources", opts) do
      {:ok, Model.list(AdSource, data)}
    end
  end

  @doc """
  The ad network's login URL; finish it in a browser. Required: `:workspace_id`.
  Optional: `:provider` (the ad network, `meta` by default), `:method` (the
  network's own login method, `business` or `user` on Meta), `:return_to`.

  A network that is not available on the deployment answers 503.
  """
  @spec authorize(Client.t(), keyword()) :: {:ok, String.t()} | {:error, FoPost.Error.t()}
  def authorize(client, opts) do
    provider = Keyword.get(opts, :provider, "meta")

    body =
      Model.take_body(opts, [{:workspace_id, "workspaceId"}, :method, {:return_to, "returnTo"}])

    with {:ok, data} <-
           Client.request(client, :post, "/ads/connections/#{provider}/authorize", json: body) do
      {:ok, url(data)}
    end
  end

  @doc """
  The Meta login URL.
  """
  @deprecated "Use authorize/2, which takes a :provider"
  @spec authorize_meta(Client.t(), keyword()) :: {:ok, String.t()} | {:error, FoPost.Error.t()}
  def authorize_meta(client, opts), do: authorize(client, Keyword.delete(opts, :provider))

  @doc """
  Disconnects an ads login. Every ad record created through it is deleted too.
  Required: `:workspace_id`.
  """
  @spec delete_connection(Client.t(), String.t(), keyword()) ::
          {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete_connection(client, id, opts) do
    params = Model.take_params(opts, [:workspace_id])

    with {:ok, data} <- Client.request(client, :delete, connection_path(id), params: params) do
      {:ok, Message.from_map(data)}
    end
  end

  @doc """
  Promotes a post FoPost already published. Needs the `publish` scope as well as `ads`.
  Starts paused unless `paused: false`.

  Required: `:workspace_id`, `:connection_id`, `:ad_account_id`, `:post_id`,
  `:account_id`, `:name`, `:goal` (`engagement`, `traffic`, `awareness`, `video_views`),
  `:budget`, `:targeting`. Optional: `:paused`.
  """
  @spec boost(Client.t(), keyword()) :: {:ok, Ad.t()} | {:error, FoPost.Error.t()}
  def boost(client, opts) do
    body = Model.take_body(opts, @boost_fields)

    with {:ok, data} <- Client.request(client, :post, "/ads/boost", json: body) do
      {:ok, Ad.from_map(data)}
    end
  end

  @doc """
  Creates a standalone ad from a creative. Needs the `publish` scope as well as `ads`.
  Starts paused unless `paused: false`.

  Required: `:workspace_id`, `:connection_id`, `:ad_account_id`, `:page_id`, `:name`,
  `:goal`, `:budget`, `:targeting`, `:text`. Optional: `:headline`, `:destination_url`,
  `:media_url`, `:url_tags`, `:paused`.
  """
  @spec create(Client.t(), keyword()) :: {:ok, Ad.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    body = Model.take_body(opts, @create_fields)

    with {:ok, data} <- Client.request(client, :post, "/ads", json: body) do
      {:ok, Ad.from_map(data)}
    end
  end

  @doc """
  Reads the delivery status and lifetime insights from Meta. Required: `:workspace_id`.
  """
  @spec refresh(Client.t(), String.t(), keyword()) :: {:ok, Ad.t()} | {:error, FoPost.Error.t()}
  def refresh(client, id, opts) do
    params = Model.take_params(opts, [:workspace_id])

    with {:ok, data} <- Client.request(client, :post, ad_path(id, "refresh"), params: params) do
      {:ok, Ad.from_map(data)}
    end
  end

  @doc """
  Pauses or resumes an ad. Needs the `publish` scope as well as `ads`.
  Required: `:workspace_id`, `:status` (`active`, `paused`).
  """
  @spec set_status(Client.t(), String.t(), keyword()) ::
          {:ok, Ad.t()} | {:error, FoPost.Error.t()}
  def set_status(client, id, opts) do
    params = Model.take_params(opts, [:workspace_id])
    body = Model.take_body(opts, [:status])

    with {:ok, data} <- Client.request(client, :patch, ad_path(id), params: params, json: body) do
      {:ok, Ad.from_map(data)}
    end
  end

  @doc """
  Ends delivery and deletes the ad on Meta as well as here. Needs the `publish` scope as
  well as `ads`. Required: `:workspace_id`.
  """
  @spec delete(Client.t(), String.t(), keyword()) ::
          {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete(client, id, opts) do
    params = Model.take_params(opts, [:workspace_id])

    with {:ok, data} <- Client.request(client, :delete, ad_path(id), params: params) do
      {:ok, Message.from_map(data)}
    end
  end

  @doc """
  The saved audiences and pixels on an ad account. Required: `:connection_id`,
  `:ad_account_id`. Optional: `:workspace_id`.
  """
  @spec audiences(Client.t(), keyword()) ::
          {:ok, AudiencesResult.t()} | {:error, FoPost.Error.t()}
  def audiences(client, opts) do
    params = Model.take_params(opts, [:workspace_id, :connection_id, :ad_account_id])

    with {:ok, data} <- Client.request(client, :get, "/ads/audiences", params: params) do
      {:ok, AudiencesResult.from_map(data)}
    end
  end

  @doc """
  Creates an audience. Required: `:workspace_id`, `:connection_id`, `:ad_account_id`,
  `:name`, `:spec`. Optional: `:description`.

  `:spec` is sent as given and carries a `subtype` of `CUSTOM` (with `emails`),
  `LOOKALIKE` (with `originAudienceId`, `country`, `ratio`), or `WEBSITE` (with
  `pixelId`, `retentionDays`, `urlContains`).
  """
  @spec create_audience(Client.t(), keyword()) ::
          {:ok, CreatedAudience.t()} | {:error, FoPost.Error.t()}
  def create_audience(client, opts) do
    body = Model.take_body(opts, @audience_fields)

    with {:ok, data} <- Client.request(client, :post, "/ads/audiences", json: body) do
      {:ok, CreatedAudience.from_map(data)}
    end
  end

  @doc """
  Locations, interests, behaviours, and income brackets as Meta names them.
  Required: `:connection_id`, `:type` (`country`, `region`, `city`, `zip`, `metro`,
  `interest`, `behavior`, `income`). Optional: `:q`, `:workspace_id`.
  """
  @spec search_targeting(Client.t(), keyword()) ::
          {:ok, [TargetingOption.t()]} | {:error, FoPost.Error.t()}
  def search_targeting(client, opts) do
    params = Model.take_params(opts, [:workspace_id, :connection_id, :type, :q])

    with {:ok, data} <- Client.request(client, :get, "/ads/targeting/search", params: params) do
      {:ok, Model.list(TargetingOption, data)}
    end
  end

  @doc """
  Each connection and Page with the lead forms on it.
  """
  @spec lead_forms(Client.t(), keyword()) ::
          {:ok, [LeadFormSource.t()]} | {:error, FoPost.Error.t()}
  def lead_forms(client, opts \\ []) do
    with {:ok, data} <- get(client, "/ads/lead-forms", opts) do
      {:ok, Model.list(LeadFormSource, data)}
    end
  end

  @doc """
  Creates an Instant Form on a Page; answers its id.

  Required: `:workspace_id`, `:connection_id`, `:page_id`, `:name`, `:questions`,
  `:privacy_policy_url`, `:thank_you_message`. Optional: `:follow_up_url`.
  """
  @spec create_lead_form(Client.t(), keyword()) ::
          {:ok, String.t()} | {:error, FoPost.Error.t()}
  def create_lead_form(client, opts) do
    body = Model.take_body(opts, @lead_form_fields)

    with {:ok, data} <- Client.request(client, :post, "/ads/lead-forms", json: body) do
      {:ok, id(data)}
    end
  end

  @doc """
  One page of a form's leads. Required: `:connection_id`, `:page_id`. Optional: `:after`
  (the previous page's `next_cursor`), `:workspace_id`.
  """
  @spec leads(Client.t(), String.t(), keyword()) ::
          {:ok, LeadsPage.t()} | {:error, FoPost.Error.t()}
  def leads(client, form_id, opts) do
    params = Model.take_params(opts, [:workspace_id, :connection_id, :page_id, :after])

    with {:ok, data} <- Client.request(client, :get, leads_path(form_id), params: params) do
      {:ok, LeadsPage.from_map(data)}
    end
  end

  @doc """
  The campaigns on an ad account with their ad sets and ads, read live from Meta.
  Required: `:connection_id`. Optional: `:workspace_id`.
  """
  @spec account_tree(Client.t(), String.t(), keyword()) ::
          {:ok, AdAccountTree.t()} | {:error, FoPost.Error.t()}
  def account_tree(client, ad_account_id, opts) do
    path = "/ads/accounts/" <> encode(ad_account_id) <> "/tree"

    with {:ok, data} <- Client.request(client, :get, path, params: meta_params(opts)) do
      {:ok, AdAccountTree.from_map(data)}
    end
  end

  @doc """
  Creates a campaign. Needs the `publish` scope as well as `ads`. Starts paused unless
  `paused: false`.

  Required: `:workspace_id`, `:connection_id`, `:ad_account_id`, `:name`, `:goal`
  (`engagement`, `traffic`, `awareness`, `video_views`). Optional: `:paused`.
  """
  @spec create_campaign(Client.t(), keyword()) ::
          {:ok, AdCampaign.t()} | {:error, FoPost.Error.t()}
  def create_campaign(client, opts) do
    body = Model.take_body(opts, @campaign_fields)

    with {:ok, data} <- Client.request(client, :post, "/ads/campaigns", json: body) do
      {:ok, AdCampaign.from_map(data)}
    end
  end

  @doc """
  A campaign by its Meta id. Required: `:connection_id`. Optional: `:workspace_id`.
  """
  @spec get_campaign(Client.t(), String.t(), keyword()) ::
          {:ok, AdCampaign.t()} | {:error, FoPost.Error.t()}
  def get_campaign(client, id, opts) do
    with {:ok, data} <- get_object(client, object_path("campaigns", id), opts) do
      {:ok, AdCampaign.from_map(data)}
    end
  end

  @doc """
  Renames, pauses, or resumes a campaign. Needs the `publish` scope as well as `ads`.
  Required: `:workspace_id`, `:connection_id`. Optional: `:name`, `:status` (`active`,
  `paused`).
  """
  @spec update_campaign(Client.t(), String.t(), keyword()) ::
          {:ok, AdCampaign.t()} | {:error, FoPost.Error.t()}
  def update_campaign(client, id, opts) do
    body = Model.take_body(opts, [:name, :status])

    with {:ok, data} <- patch_object(client, object_path("campaigns", id), opts, body) do
      {:ok, AdCampaign.from_map(data)}
    end
  end

  @doc """
  Deletes a campaign on Meta. Needs the `publish` scope as well as `ads`.
  Required: `:workspace_id`, `:connection_id`.
  """
  @spec delete_campaign(Client.t(), String.t(), keyword()) ::
          {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete_campaign(client, id, opts),
    do: delete_object(client, object_path("campaigns", id), opts)

  @doc """
  Copies a campaign on Meta; answers the copy's Meta id. Needs the `publish` scope as
  well as `ads`. Required: `:workspace_id`, `:connection_id`. Optional: `:paused`.
  """
  @spec duplicate_campaign(Client.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, FoPost.Error.t()}
  def duplicate_campaign(client, id, opts),
    do: duplicate_object(client, object_path("campaigns", id), opts)

  @doc """
  Creates an ad set in a campaign. Needs the `publish` scope as well as `ads`. Starts
  paused unless `paused: false`.

  Required: `:workspace_id`, `:connection_id`, `:campaign_id`, `:page_id`, `:name`,
  `:goal`, `:budget`, `:targeting`. Optional: `:paused`.
  """
  @spec create_ad_set(Client.t(), keyword()) :: {:ok, AdSet.t()} | {:error, FoPost.Error.t()}
  def create_ad_set(client, opts) do
    body = Model.take_body(opts, @ad_set_fields)

    with {:ok, data} <- Client.request(client, :post, "/ads/ad-sets", json: body) do
      {:ok, AdSet.from_map(data)}
    end
  end

  @doc """
  An ad set by its Meta id. Required: `:connection_id`. Optional: `:workspace_id`.
  """
  @spec get_ad_set(Client.t(), String.t(), keyword()) ::
          {:ok, AdSet.t()} | {:error, FoPost.Error.t()}
  def get_ad_set(client, id, opts) do
    with {:ok, data} <- get_object(client, object_path("ad-sets", id), opts) do
      {:ok, AdSet.from_map(data)}
    end
  end

  @doc """
  Updates an ad set. Needs the `publish` scope as well as `ads`. Required:
  `:workspace_id`, `:connection_id`. Optional: `:name`, `:status`, `:budget_minor`,
  `:end_at`, `:targeting`.
  """
  @spec update_ad_set(Client.t(), String.t(), keyword()) ::
          {:ok, AdSet.t()} | {:error, FoPost.Error.t()}
  def update_ad_set(client, id, opts) do
    body = Model.take_body(opts, @ad_set_update_fields)

    with {:ok, data} <- patch_object(client, object_path("ad-sets", id), opts, body) do
      {:ok, AdSet.from_map(data)}
    end
  end

  @doc """
  Deletes an ad set on Meta. Needs the `publish` scope as well as `ads`.
  Required: `:workspace_id`, `:connection_id`.
  """
  @spec delete_ad_set(Client.t(), String.t(), keyword()) ::
          {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete_ad_set(client, id, opts), do: delete_object(client, object_path("ad-sets", id), opts)

  @doc """
  Copies an ad set on Meta; answers the copy's Meta id. Needs the `publish` scope as
  well as `ads`. Required: `:workspace_id`, `:connection_id`. Optional: `:paused`.
  """
  @spec duplicate_ad_set(Client.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, FoPost.Error.t()}
  def duplicate_ad_set(client, id, opts),
    do: duplicate_object(client, object_path("ad-sets", id), opts)

  @doc """
  Creates an ad inside an ad set from an existing creative (unlike `create/2`). Needs the
  `publish` scope as well as `ads`. Starts paused unless `paused: false`.

  Required: `:workspace_id`, `:connection_id`, `:ad_set_id`, `:creative_id`, `:name`.
  Optional: `:paused`.
  """
  @spec create_network_ad(Client.t(), keyword()) ::
          {:ok, NetworkAd.t()} | {:error, FoPost.Error.t()}
  def create_network_ad(client, opts) do
    body = Model.take_body(opts, @network_ad_fields)

    with {:ok, data} <- Client.request(client, :post, "/ads/ads", json: body) do
      {:ok, NetworkAd.from_map(data)}
    end
  end

  @doc """
  An ad by its Meta id. Required: `:connection_id`. Optional: `:workspace_id`.
  """
  @spec get_network_ad(Client.t(), String.t(), keyword()) ::
          {:ok, NetworkAd.t()} | {:error, FoPost.Error.t()}
  def get_network_ad(client, id, opts) do
    with {:ok, data} <- get_object(client, object_path("ads", id), opts) do
      {:ok, NetworkAd.from_map(data)}
    end
  end

  @doc """
  Updates an ad. Needs the `publish` scope as well as `ads`. Required: `:workspace_id`,
  `:connection_id`. Optional: `:name`, `:status`, `:creative_id`.
  """
  @spec update_network_ad(Client.t(), String.t(), keyword()) ::
          {:ok, NetworkAd.t()} | {:error, FoPost.Error.t()}
  def update_network_ad(client, id, opts) do
    body = Model.take_body(opts, [:name, :status, {:creative_id, "creativeId"}])

    with {:ok, data} <- patch_object(client, object_path("ads", id), opts, body) do
      {:ok, NetworkAd.from_map(data)}
    end
  end

  @doc """
  Deletes an ad on Meta. Needs the `publish` scope as well as `ads`.
  Required: `:workspace_id`, `:connection_id`.
  """
  @spec delete_network_ad(Client.t(), String.t(), keyword()) ::
          {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete_network_ad(client, id, opts), do: delete_object(client, object_path("ads", id), opts)

  @doc """
  Copies an ad on Meta; answers the copy's Meta id. Needs the `publish` scope as well as
  `ads`. Required: `:workspace_id`, `:connection_id`. Optional: `:paused`.
  """
  @spec duplicate_network_ad(Client.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, FoPost.Error.t()}
  def duplicate_network_ad(client, id, opts),
    do: duplicate_object(client, object_path("ads", id), opts)

  @doc """
  Pauses or activates many objects at once. Needs the `publish` scope as well as `ads`.

  Required: `:workspace_id`, `:connection_id`, `:status` (`active`, `paused`),
  `:objects` (maps of `id` and `level`: `campaign`, `ad_set`, or `ad`).
  """
  @spec bulk_set_status(Client.t(), keyword()) ::
          {:ok, [BulkAdStatusResult.t()]} | {:error, FoPost.Error.t()}
  def bulk_set_status(client, opts) do
    body =
      Model.take_body(opts, [
        {:workspace_id, "workspaceId"},
        {:connection_id, "connectionId"},
        :status,
        :objects
      ])

    with {:ok, data} <- Client.request(client, :post, "/ads/status", json: body) do
      {:ok, Model.list(BulkAdStatusResult, data)}
    end
  end

  @doc """
  The creatives on an ad account. Required: `:connection_id`, `:ad_account_id`.
  Optional: `:workspace_id`.
  """
  @spec creatives(Client.t(), keyword()) ::
          {:ok, [AdCreative.t()]} | {:error, FoPost.Error.t()}
  def creatives(client, opts) do
    params = Model.take_params(opts, [:workspace_id, :connection_id, :ad_account_id])

    with {:ok, data} <- Client.request(client, :get, "/ads/creatives", params: params) do
      {:ok, Model.list(AdCreative, creatives_list(data))}
    end
  end

  @doc """
  Creates a creative.

  Required: `:workspace_id`, `:connection_id`, `:ad_account_id`, `:page_id`, `:name`,
  `:format` (`image`, `video`, `carousel`), `:text`. Optional: `:headline`,
  `:destination_url`, `:call_to_action`, `:url_tags`, `:media_url`,
  `:thumbnail_media_url`, `:cards` (a carousel's maps of `mediaUrl`, `destinationUrl`,
  `headline`, `description`).
  """
  @spec create_creative(Client.t(), keyword()) ::
          {:ok, AdCreative.t()} | {:error, FoPost.Error.t()}
  def create_creative(client, opts) do
    body = Model.take_body(opts, @creative_fields)

    with {:ok, data} <- Client.request(client, :post, "/ads/creatives", json: body) do
      {:ok, AdCreative.from_map(data)}
    end
  end

  @doc """
  A creative by its Meta id. Required: `:connection_id`. Optional: `:workspace_id`.
  """
  @spec get_creative(Client.t(), String.t(), keyword()) ::
          {:ok, AdCreative.t()} | {:error, FoPost.Error.t()}
  def get_creative(client, id, opts) do
    with {:ok, data} <- get_object(client, object_path("creatives", id), opts) do
      {:ok, AdCreative.from_map(data)}
    end
  end

  @doc """
  Deletes a creative. Required: `:workspace_id`, `:connection_id`.
  """
  @spec delete_creative(Client.t(), String.t(), keyword()) ::
          {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete_creative(client, id, opts),
    do: delete_object(client, object_path("creatives", id), opts)

  @doc """
  An audience by its Meta id. Required: `:connection_id`. Optional: `:workspace_id`.
  """
  @spec get_audience(Client.t(), String.t(), keyword()) ::
          {:ok, Audience.t()} | {:error, FoPost.Error.t()}
  def get_audience(client, id, opts) do
    with {:ok, data} <- get_object(client, object_path("audiences", id), opts) do
      {:ok, Audience.from_map(data)}
    end
  end

  @doc """
  Renames or redescribes an audience. Required: `:workspace_id`, `:connection_id`.
  Optional: `:name`, `:description`.
  """
  @spec update_audience(Client.t(), String.t(), keyword()) ::
          {:ok, Audience.t()} | {:error, FoPost.Error.t()}
  def update_audience(client, id, opts) do
    body = Model.take_body(opts, [:name, :description])

    with {:ok, data} <- patch_object(client, object_path("audiences", id), opts, body) do
      {:ok, Audience.from_map(data)}
    end
  end

  @doc """
  Deletes an audience. Required: `:workspace_id`, `:connection_id`.
  """
  @spec delete_audience(Client.t(), String.t(), keyword()) ::
          {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete_audience(client, id, opts),
    do: delete_object(client, object_path("audiences", id), opts)

  @doc """
  Adds customers to a custom audience by email; answers how many were sent to Meta.
  Required: `:workspace_id`, `:connection_id`, `:emails`.
  """
  @spec add_audience_users(Client.t(), String.t(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, FoPost.Error.t()}
  def add_audience_users(client, id, opts) do
    path = object_path("audiences", id) <> "/users"
    body = Model.take_body(opts, [:emails])

    with {:ok, data} <-
           Client.request(client, :post, path, params: meta_params(opts), json: body) do
      {:ok, added(data)}
    end
  end

  @doc """
  Estimates the audience size for a targeting spec.
  Required: `:workspace_id`, `:connection_id`, `:ad_account_id`, `:page_id`, `:targeting`.
  """
  @spec estimate_reach(Client.t(), keyword()) ::
          {:ok, ReachEstimate.t()} | {:error, FoPost.Error.t()}
  def estimate_reach(client, opts) do
    body =
      Model.take_body(opts, [
        {:workspace_id, "workspaceId"},
        {:connection_id, "connectionId"},
        {:ad_account_id, "adAccountId"},
        {:page_id, "pageId"},
        :targeting
      ])

    with {:ok, data} <- Client.request(client, :post, "/ads/reach-estimate", json: body) do
      {:ok, ReachEstimate.from_map(data)}
    end
  end

  @doc """
  Insights for any campaign, ad set, or ad by its Meta id.

  Required: `:connection_id`, `:object_id`, `:since`, `:until` (`YYYY-MM-DD`). Optional:
  `:breakdown` (`age`, `gender`, `placement`, `country`), `:daily` (adds a per-day
  timeline), `:workspace_id`.
  """
  @spec insights(Client.t(), keyword()) ::
          {:ok, AdInsightsReport.t()} | {:error, FoPost.Error.t()}
  def insights(client, opts) do
    params =
      Model.take_params(opts, [:workspace_id, :connection_id, :object_id | @insights_params])

    with {:ok, data} <- Client.request(client, :get, "/ads/insights", params: params) do
      {:ok, AdInsightsReport.from_map(data)}
    end
  end

  @doc """
  Insights for an ad created through FoPost, by its FoPost id.

  Required: `:workspace_id`, `:since`, `:until`. Optional: `:breakdown`, `:daily`.
  """
  @spec ad_insights(Client.t(), String.t(), keyword()) ::
          {:ok, AdInsightsReport.t()} | {:error, FoPost.Error.t()}
  def ad_insights(client, id, opts) do
    params = Model.take_params(opts, [:workspace_id | @insights_params])

    with {:ok, data} <- Client.request(client, :get, ad_path(id, "insights"), params: params) do
      {:ok, AdInsightsReport.from_map(data)}
    end
  end

  @doc """
  One lead form with its questions. Required: `:connection_id`, `:page_id`. Optional:
  `:workspace_id`.
  """
  @spec get_lead_form(Client.t(), String.t(), keyword()) ::
          {:ok, LeadFormDetail.t()} | {:error, FoPost.Error.t()}
  def get_lead_form(client, form_id, opts) do
    params = Model.take_params(opts, [:workspace_id, :connection_id, :page_id])

    with {:ok, data} <- Client.request(client, :get, lead_form_path(form_id), params: params) do
      {:ok, LeadFormDetail.from_map(data)}
    end
  end

  @doc """
  Archives a lead form so it stops collecting leads.
  Required: `:workspace_id`, `:connection_id`, `:page_id`.
  """
  @spec archive_lead_form(Client.t(), String.t(), keyword()) ::
          {:ok, LeadFormDetail.t()} | {:error, FoPost.Error.t()}
  def archive_lead_form(client, form_id, opts) do
    body = Model.take_body(opts, @page_fields)
    path = lead_form_path(form_id) <> "/archive"

    with {:ok, data} <- Client.request(client, :post, path, json: body) do
      {:ok, LeadFormDetail.from_map(data)}
    end
  end

  @doc """
  Stored leads from subscribed Pages, newest first. Optional: `:form_id`, `:page_id`,
  `:cursor` (the previous page's `next_cursor`), `:limit`, `:workspace_id`.
  """
  @spec leads_feed(Client.t(), keyword()) ::
          {:ok, LeadsFeedPage.t()} | {:error, FoPost.Error.t()}
  def leads_feed(client, opts \\ []) do
    params = Model.take_params(opts, [:workspace_id, :form_id, :page_id, :cursor, :limit])

    with {:ok, data} <- Client.request(client, :get, "/ads/leads", params: params) do
      {:ok, LeadsFeedPage.from_map(data)}
    end
  end

  @doc """
  The Pages subscribed to lead delivery.
  """
  @spec lead_pages(Client.t(), keyword()) :: {:ok, [LeadPage.t()]} | {:error, FoPost.Error.t()}
  def lead_pages(client, opts \\ []) do
    with {:ok, data} <- get(client, "/ads/lead-pages", opts) do
      {:ok, Model.list(LeadPage, data)}
    end
  end

  @doc """
  Subscribes a Page to lead delivery and backfills its recent leads.
  Required: `:workspace_id`, `:connection_id`, `:page_id`.
  """
  @spec subscribe_lead_page(Client.t(), keyword()) ::
          {:ok, LeadPageSubscription.t()} | {:error, FoPost.Error.t()}
  def subscribe_lead_page(client, opts) do
    body = Model.take_body(opts, @page_fields)

    with {:ok, data} <- Client.request(client, :post, "/ads/lead-pages", json: body) do
      {:ok, LeadPageSubscription.from_map(data)}
    end
  end

  @doc """
  Stops lead delivery for a Page. Required: `:workspace_id`, `:connection_id`.
  """
  @spec unsubscribe_lead_page(Client.t(), String.t(), keyword()) ::
          {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def unsubscribe_lead_page(client, page_id, opts),
    do: delete_object(client, object_path("lead-pages", page_id), opts)

  @doc "Same as `list/2`, but raises `FoPost.Error`."
  def list!(client, opts \\ []), do: Result.unwrap!(list(client, opts))

  @doc "Same as `external/2`, but raises `FoPost.Error`."
  def external!(client, opts \\ []), do: Result.unwrap!(external(client, opts))

  @doc "Same as `boostable/2`, but raises `FoPost.Error`."
  def boostable!(client, opts \\ []), do: Result.unwrap!(boostable(client, opts))

  @doc "Same as `connections/2`, but raises `FoPost.Error`."
  def connections!(client, opts \\ []), do: Result.unwrap!(connections(client, opts))

  @doc "Same as `sources/2`, but raises `FoPost.Error`."
  def sources!(client, opts \\ []), do: Result.unwrap!(sources(client, opts))

  @doc "Same as `authorize_meta/2`, but raises `FoPost.Error`."
  def authorize_meta!(client, opts), do: Result.unwrap!(authorize_meta(client, opts))

  @doc "Same as `delete_connection/3`, but raises `FoPost.Error`."
  def delete_connection!(client, id, opts),
    do: Result.unwrap!(delete_connection(client, id, opts))

  @doc "Same as `boost/2`, but raises `FoPost.Error`."
  def boost!(client, opts), do: Result.unwrap!(boost(client, opts))

  @doc "Same as `create/2`, but raises `FoPost.Error`."
  def create!(client, opts), do: Result.unwrap!(create(client, opts))

  @doc "Same as `refresh/3`, but raises `FoPost.Error`."
  def refresh!(client, id, opts), do: Result.unwrap!(refresh(client, id, opts))

  @doc "Same as `set_status/3`, but raises `FoPost.Error`."
  def set_status!(client, id, opts), do: Result.unwrap!(set_status(client, id, opts))

  @doc "Same as `delete/3`, but raises `FoPost.Error`."
  def delete!(client, id, opts), do: Result.unwrap!(delete(client, id, opts))

  @doc "Same as `audiences/2`, but raises `FoPost.Error`."
  def audiences!(client, opts), do: Result.unwrap!(audiences(client, opts))

  @doc "Same as `create_audience/2`, but raises `FoPost.Error`."
  def create_audience!(client, opts), do: Result.unwrap!(create_audience(client, opts))

  @doc "Same as `search_targeting/2`, but raises `FoPost.Error`."
  def search_targeting!(client, opts), do: Result.unwrap!(search_targeting(client, opts))

  @doc "Same as `lead_forms/2`, but raises `FoPost.Error`."
  def lead_forms!(client, opts \\ []), do: Result.unwrap!(lead_forms(client, opts))

  @doc "Same as `create_lead_form/2`, but raises `FoPost.Error`."
  def create_lead_form!(client, opts), do: Result.unwrap!(create_lead_form(client, opts))

  @doc "Same as `leads/3`, but raises `FoPost.Error`."
  def leads!(client, form_id, opts), do: Result.unwrap!(leads(client, form_id, opts))

  @doc "Same as `account_tree/3`, but raises `FoPost.Error`."
  def account_tree!(client, id, opts), do: Result.unwrap!(account_tree(client, id, opts))

  @doc "Same as `create_campaign/2`, but raises `FoPost.Error`."
  def create_campaign!(client, opts), do: Result.unwrap!(create_campaign(client, opts))

  @doc "Same as `get_campaign/3`, but raises `FoPost.Error`."
  def get_campaign!(client, id, opts), do: Result.unwrap!(get_campaign(client, id, opts))

  @doc "Same as `update_campaign/3`, but raises `FoPost.Error`."
  def update_campaign!(client, id, opts), do: Result.unwrap!(update_campaign(client, id, opts))

  @doc "Same as `delete_campaign/3`, but raises `FoPost.Error`."
  def delete_campaign!(client, id, opts), do: Result.unwrap!(delete_campaign(client, id, opts))

  @doc "Same as `duplicate_campaign/3`, but raises `FoPost.Error`."
  def duplicate_campaign!(client, id, opts),
    do: Result.unwrap!(duplicate_campaign(client, id, opts))

  @doc "Same as `create_ad_set/2`, but raises `FoPost.Error`."
  def create_ad_set!(client, opts), do: Result.unwrap!(create_ad_set(client, opts))

  @doc "Same as `get_ad_set/3`, but raises `FoPost.Error`."
  def get_ad_set!(client, id, opts), do: Result.unwrap!(get_ad_set(client, id, opts))

  @doc "Same as `update_ad_set/3`, but raises `FoPost.Error`."
  def update_ad_set!(client, id, opts), do: Result.unwrap!(update_ad_set(client, id, opts))

  @doc "Same as `delete_ad_set/3`, but raises `FoPost.Error`."
  def delete_ad_set!(client, id, opts), do: Result.unwrap!(delete_ad_set(client, id, opts))

  @doc "Same as `duplicate_ad_set/3`, but raises `FoPost.Error`."
  def duplicate_ad_set!(client, id, opts), do: Result.unwrap!(duplicate_ad_set(client, id, opts))

  @doc "Same as `create_network_ad/2`, but raises `FoPost.Error`."
  def create_network_ad!(client, opts), do: Result.unwrap!(create_network_ad(client, opts))

  @doc "Same as `get_network_ad/3`, but raises `FoPost.Error`."
  def get_network_ad!(client, id, opts), do: Result.unwrap!(get_network_ad(client, id, opts))

  @doc "Same as `update_network_ad/3`, but raises `FoPost.Error`."
  def update_network_ad!(client, id, opts),
    do: Result.unwrap!(update_network_ad(client, id, opts))

  @doc "Same as `delete_network_ad/3`, but raises `FoPost.Error`."
  def delete_network_ad!(client, id, opts),
    do: Result.unwrap!(delete_network_ad(client, id, opts))

  @doc "Same as `duplicate_network_ad/3`, but raises `FoPost.Error`."
  def duplicate_network_ad!(client, id, opts),
    do: Result.unwrap!(duplicate_network_ad(client, id, opts))

  @doc "Same as `bulk_set_status/2`, but raises `FoPost.Error`."
  def bulk_set_status!(client, opts), do: Result.unwrap!(bulk_set_status(client, opts))

  @doc "Same as `creatives/2`, but raises `FoPost.Error`."
  def creatives!(client, opts), do: Result.unwrap!(creatives(client, opts))

  @doc "Same as `create_creative/2`, but raises `FoPost.Error`."
  def create_creative!(client, opts), do: Result.unwrap!(create_creative(client, opts))

  @doc "Same as `get_creative/3`, but raises `FoPost.Error`."
  def get_creative!(client, id, opts), do: Result.unwrap!(get_creative(client, id, opts))

  @doc "Same as `delete_creative/3`, but raises `FoPost.Error`."
  def delete_creative!(client, id, opts), do: Result.unwrap!(delete_creative(client, id, opts))

  @doc "Same as `get_audience/3`, but raises `FoPost.Error`."
  def get_audience!(client, id, opts), do: Result.unwrap!(get_audience(client, id, opts))

  @doc "Same as `update_audience/3`, but raises `FoPost.Error`."
  def update_audience!(client, id, opts), do: Result.unwrap!(update_audience(client, id, opts))

  @doc "Same as `delete_audience/3`, but raises `FoPost.Error`."
  def delete_audience!(client, id, opts), do: Result.unwrap!(delete_audience(client, id, opts))

  @doc "Same as `add_audience_users/3`, but raises `FoPost.Error`."
  def add_audience_users!(client, id, opts),
    do: Result.unwrap!(add_audience_users(client, id, opts))

  @doc "Same as `estimate_reach/2`, but raises `FoPost.Error`."
  def estimate_reach!(client, opts), do: Result.unwrap!(estimate_reach(client, opts))

  @doc "Same as `insights/2`, but raises `FoPost.Error`."
  def insights!(client, opts), do: Result.unwrap!(insights(client, opts))

  @doc "Same as `ad_insights/3`, but raises `FoPost.Error`."
  def ad_insights!(client, id, opts), do: Result.unwrap!(ad_insights(client, id, opts))

  @doc "Same as `get_lead_form/3`, but raises `FoPost.Error`."
  def get_lead_form!(client, id, opts), do: Result.unwrap!(get_lead_form(client, id, opts))

  @doc "Same as `archive_lead_form/3`, but raises `FoPost.Error`."
  def archive_lead_form!(client, id, opts),
    do: Result.unwrap!(archive_lead_form(client, id, opts))

  @doc "Same as `leads_feed/2`, but raises `FoPost.Error`."
  def leads_feed!(client, opts \\ []), do: Result.unwrap!(leads_feed(client, opts))

  @doc "Same as `lead_pages/2`, but raises `FoPost.Error`."
  def lead_pages!(client, opts \\ []), do: Result.unwrap!(lead_pages(client, opts))

  @doc "Same as `subscribe_lead_page/2`, but raises `FoPost.Error`."
  def subscribe_lead_page!(client, opts), do: Result.unwrap!(subscribe_lead_page(client, opts))

  @doc "Same as `unsubscribe_lead_page/3`, but raises `FoPost.Error`."
  def unsubscribe_lead_page!(client, id, opts),
    do: Result.unwrap!(unsubscribe_lead_page(client, id, opts))

  defp get(client, path, opts) do
    Client.request(client, :get, path, params: Model.take_params(opts, [:workspace_id]))
  end

  defp meta_params(opts), do: Model.take_params(opts, [:workspace_id, :connection_id])

  defp get_object(client, path, opts) do
    Client.request(client, :get, path, params: meta_params(opts))
  end

  defp patch_object(client, path, opts, body) do
    Client.request(client, :patch, path, params: meta_params(opts), json: body)
  end

  defp delete_object(client, path, opts) do
    with {:ok, data} <- Client.request(client, :delete, path, params: meta_params(opts)) do
      {:ok, Message.from_map(data)}
    end
  end

  defp duplicate_object(client, path, opts) do
    body = Model.take_body(opts, [:paused])

    with {:ok, data} <-
           Client.request(client, :post, path <> "/duplicate",
             params: meta_params(opts),
             json: body
           ) do
      {:ok, id(data)}
    end
  end

  defp creatives_list(%{"creatives" => creatives}), do: creatives
  defp creatives_list(_data), do: []

  defp added(%{"added" => added}) when is_integer(added), do: added
  defp added(_data), do: 0

  defp object_path(kind, id), do: "/ads/" <> kind <> "/" <> encode(id)

  defp lead_form_path(form_id), do: "/ads/lead-forms/" <> encode(form_id)

  defp url(%{"url" => url}) when is_binary(url), do: url
  defp url(_data), do: ""

  defp id(%{"id" => id}) when is_binary(id), do: id
  defp id(_data), do: ""

  defp ad_path(id), do: "/ads/" <> encode(id)
  defp ad_path(id, action), do: ad_path(id) <> "/" <> action

  defp connection_path(id), do: "/ads/connections/" <> encode(id)

  defp leads_path(form_id), do: "/ads/lead-forms/" <> encode(form_id) <> "/leads"

  defp encode(id), do: URI.encode(to_string(id), &URI.char_unreserved?/1)
end
