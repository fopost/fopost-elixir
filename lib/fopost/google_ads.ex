defmodule FoPost.GoogleAds do
  @moduledoc """
  Google Ads: keywords, assets, Performance Max asset groups, Local Services leads,
  conversions, and raw GAQL.

  Campaigns, ad groups, ads, audiences, and insights are on `FoPost.Ads` and dispatch by
  connection; a connection on another network answers 400 here. Every function needs the
  `ads` scope, and anything that changes what a live account serves or bids also needs
  `publish`.

  Every call names `:connection_id` and `:customer_id`. The customer id is digits only
  and has to name an account the connection's grant reaches: any other answers 404.
  `:workspace_id` may be left out on a read, and is required on a write.

      {:ok, keywords} =
        FoPost.GoogleAds.keywords(client,
          connection_id: connection.id,
          customer_id: "1234567890"
        )

  An object id carries the account it belongs to, because a Google resource name cannot
  ride in a URL path segment: `1234567890~campaign~55`, `1234567890~adGroup~77`.
  Amounts are in the account's currency, in minor units.
  """

  alias FoPost.Client
  alias FoPost.GoogleAdScheduleSlot
  alias FoPost.GoogleAssetGroup
  alias FoPost.GoogleAssets
  alias FoPost.GoogleBidStrategy
  alias FoPost.GoogleConversionAction
  alias FoPost.GoogleKeyword
  alias FoPost.GoogleKeywordIdea
  alias FoPost.GoogleLocalServicesLead
  alias FoPost.GoogleSearchTerm
  alias FoPost.GoogleSharedSet
  alias FoPost.Model
  alias FoPost.Result

  @scope_params [:workspace_id, :connection_id, :customer_id]
  @scope_body [
    {:workspace_id, "workspaceId"},
    {:connection_id, "connectionId"},
    {:customer_id, "customerId"}
  ]

  # ── Keywords ──

  @doc """
  Keywords on the account, or on one ad group with `:ad_group_id`.
  """
  @spec keywords(Client.t(), keyword()) :: {:ok, [GoogleKeyword.t()]} | {:error, FoPost.Error.t()}
  def keywords(client, opts) do
    params = Model.take_params(opts, @scope_params ++ [:ad_group_id])

    with {:ok, data} <- Client.request(client, :get, "/ads/google/keywords", params: params) do
      {:ok, Model.list(GoogleKeyword, data)}
    end
  end

  @doc """
  Adds a keyword. Required: `:ad_group_id`, `:text`, `:match_type` (`EXACT`, `PHRASE`,
  or `BROAD`). Optional: `:cpc_bid_minor`. Needs `publish` as well as `ads`.
  """
  @spec create_keyword(Client.t(), keyword()) :: {:ok, String.t()} | {:error, FoPost.Error.t()}
  def create_keyword(client, opts) do
    body =
      Model.take_body(
        opts,
        @scope_body ++
          [
            {:ad_group_id, "adGroupId"},
            :text,
            {:match_type, "matchType"},
            {:cpc_bid_minor, "cpcBidMinor"}
          ]
      )

    created(client, :post, "/ads/google/keywords", body)
  end

  @doc """
  Pauses, resumes, or rebids a keyword. `:status` is `"active"` or `"paused"`.
  Needs `publish` as well as `ads`.
  """
  @spec update_keyword(Client.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, FoPost.Error.t()}
  def update_keyword(client, keyword_id, opts) do
    body = Model.take_body(opts, @scope_body ++ [:status, {:cpc_bid_minor, "cpcBidMinor"}])

    created(client, :patch, "/ads/google/keywords/" <> encode(keyword_id), body)
  end

  @doc """
  Removes a keyword. Needs `publish` as well as `ads`.
  """
  @spec delete_keyword(Client.t(), String.t(), keyword()) :: :ok | {:error, FoPost.Error.t()}
  def delete_keyword(client, keyword_id, opts) do
    discard(client, "/ads/google/keywords/" <> encode(keyword_id), opts)
  end

  @doc """
  Keyword ideas from `:seeds`, a `:url`, or both. Optional: `:language_id`,
  `:geo_target_ids`.
  """
  @spec keyword_ideas(Client.t(), keyword()) ::
          {:ok, [GoogleKeywordIdea.t()]} | {:error, FoPost.Error.t()}
  def keyword_ideas(client, opts) do
    body =
      Model.take_body(
        opts,
        @scope_body ++
          [:seeds, :url, {:language_id, "languageId"}, {:geo_target_ids, "geoTargetIds"}]
      )

    with {:ok, data} <-
           Client.request(client, :post, "/ads/google/keyword-ideas", json: body) do
      {:ok, Model.list(GoogleKeywordIdea, data)}
    end
  end

  @doc """
  Historical metrics for the `:keywords` given.
  """
  @spec keyword_metrics(Client.t(), keyword()) ::
          {:ok, [GoogleKeywordIdea.t()]} | {:error, FoPost.Error.t()}
  def keyword_metrics(client, opts) do
    body = Model.take_body(opts, @scope_body ++ [:keywords])

    with {:ok, data} <-
           Client.request(client, :post, "/ads/google/keyword-metrics", json: body) do
      {:ok, Model.list(GoogleKeywordIdea, data)}
    end
  end

  @doc """
  What people actually searched, with the metrics each term earned. Required:
  `:since` and `:until`, `YYYY-MM-DD`.
  """
  @spec search_terms(Client.t(), keyword()) ::
          {:ok, [GoogleSearchTerm.t()]} | {:error, FoPost.Error.t()}
  def search_terms(client, opts) do
    params = Model.take_params(opts, @scope_params ++ [:since, :until])

    with {:ok, data} <- Client.request(client, :get, "/ads/google/search-terms", params: params) do
      {:ok, Model.list(GoogleSearchTerm, data)}
    end
  end

  # ── Bid strategies and ad schedule ──

  @doc """
  The account's portfolio bid strategies.
  """
  @spec bid_strategies(Client.t(), keyword()) ::
          {:ok, [GoogleBidStrategy.t()]} | {:error, FoPost.Error.t()}
  def bid_strategies(client, opts) do
    params = Model.take_params(opts, @scope_params)

    with {:ok, data} <-
           Client.request(client, :get, "/ads/google/bid-strategies", params: params) do
      {:ok, Model.list(GoogleBidStrategy, data)}
    end
  end

  @doc """
  Adds a bid strategy. Required: `:name`, `:type`. Optional: `:target_minor`.
  Needs `publish` as well as `ads`.
  """
  @spec create_bid_strategy(Client.t(), keyword()) ::
          {:ok, String.t()} | {:error, FoPost.Error.t()}
  def create_bid_strategy(client, opts) do
    body = Model.take_body(opts, @scope_body ++ [:name, :type, {:target_minor, "targetMinor"}])

    created(client, :post, "/ads/google/bid-strategies", body)
  end

  @doc """
  A campaign's ad schedule. Required: `:campaign_id`.
  """
  @spec ad_schedule(Client.t(), keyword()) ::
          {:ok, [GoogleAdScheduleSlot.t()]} | {:error, FoPost.Error.t()}
  def ad_schedule(client, opts) do
    params = Model.take_params(opts, @scope_params ++ [:campaign_id])

    with {:ok, data} <- Client.request(client, :get, "/ads/google/ad-schedule", params: params) do
      {:ok, Model.list(GoogleAdScheduleSlot, data)}
    end
  end

  @doc """
  Replaces every slot on the campaign: Google has no partial edit for a schedule.
  Required: `:campaign_id`, `:slots`. Needs `publish` as well as `ads`.
  """
  @spec set_ad_schedule(Client.t(), keyword()) :: {:ok, integer()} | {:error, FoPost.Error.t()}
  def set_ad_schedule(client, opts) do
    body = Model.take_body(opts, @scope_body ++ [{:campaign_id, "campaignId"}, :slots])

    with {:ok, data} <- Client.request(client, :put, "/ads/google/ad-schedule", json: body) do
      {:ok, count(data, "slots")}
    end
  end

  # ── Negative keyword lists ──

  @doc """
  The account's negative keyword lists.
  """
  @spec negative_keyword_lists(Client.t(), keyword()) ::
          {:ok, [GoogleSharedSet.t()]} | {:error, FoPost.Error.t()}
  def negative_keyword_lists(client, opts) do
    params = Model.take_params(opts, @scope_params)

    with {:ok, data} <-
           Client.request(client, :get, "/ads/google/negative-keywords", params: params) do
      {:ok, Model.list(GoogleSharedSet, data)}
    end
  end

  @doc """
  Creates a negative keyword list. Required: `:name`. Needs `publish` as well as `ads`.
  """
  @spec create_negative_keyword_list(Client.t(), keyword()) ::
          {:ok, String.t()} | {:error, FoPost.Error.t()}
  def create_negative_keyword_list(client, opts) do
    body = Model.take_body(opts, @scope_body ++ [:name])

    created(client, :post, "/ads/google/negative-keywords", body)
  end

  @doc """
  Adds keywords to a list and answers how many landed. Required: `:shared_set_id`,
  `:keywords`. Needs `publish` as well as `ads`.
  """
  @spec add_negative_keywords(Client.t(), keyword()) ::
          {:ok, integer()} | {:error, FoPost.Error.t()}
  def add_negative_keywords(client, opts) do
    body = Model.take_body(opts, @scope_body ++ [{:shared_set_id, "sharedSetId"}, :keywords])

    with {:ok, data} <-
           Client.request(client, :post, "/ads/google/negative-keywords/keywords", json: body) do
      {:ok, count(data, "added")}
    end
  end

  @doc """
  Puts a negative keyword list on a campaign. Required: `:shared_set_id`,
  `:campaign_id`. Needs `publish` as well as `ads`.
  """
  @spec attach_negative_keyword_list(Client.t(), keyword()) ::
          :ok | {:error, FoPost.Error.t()}
  def attach_negative_keyword_list(client, opts) do
    body =
      Model.take_body(
        opts,
        @scope_body ++ [{:shared_set_id, "sharedSetId"}, {:campaign_id, "campaignId"}]
      )

    with {:ok, _data} <-
           Client.request(client, :post, "/ads/google/negative-keywords/attach", json: body) do
      :ok
    end
  end

  # ── Assets ──

  @doc """
  Sitelinks, callouts, and snippets, with the links that place each one.
  """
  @spec assets(Client.t(), keyword()) :: {:ok, GoogleAssets.t()} | {:error, FoPost.Error.t()}
  def assets(client, opts) do
    params = Model.take_params(opts, @scope_params)

    with {:ok, data} <- Client.request(client, :get, "/ads/google/assets", params: params) do
      {:ok, GoogleAssets.from_map(data)}
    end
  end

  @doc """
  Adds an asset to the library. Required: `:spec`, a sitelink, callout, or snippet.
  Needs `publish` as well as `ads`.
  """
  @spec create_asset(Client.t(), keyword()) :: {:ok, String.t()} | {:error, FoPost.Error.t()}
  def create_asset(client, opts) do
    body = Model.take_body(opts, @scope_body ++ [:spec])

    created(client, :post, "/ads/google/assets", body)
  end

  @doc """
  Puts an asset under the ads it belongs to. Required: `:asset_id`, `:field_type`.
  Optional: `:campaign_id`, which attaches to one campaign rather than the account.
  Needs `publish` as well as `ads`.
  """
  @spec attach_asset(Client.t(), keyword()) :: :ok | {:error, FoPost.Error.t()}
  def attach_asset(client, opts) do
    body =
      Model.take_body(
        opts,
        @scope_body ++
          [{:asset_id, "assetId"}, {:field_type, "fieldType"}, {:campaign_id, "campaignId"}]
      )

    with {:ok, _data} <- Client.request(client, :post, "/ads/google/assets/attach", json: body) do
      :ok
    end
  end

  @doc """
  Removes the links that put an asset under an ad; on Google the asset itself is
  permanent. Needs `publish` as well as `ads`.
  """
  @spec delete_asset(Client.t(), String.t(), keyword()) :: :ok | {:error, FoPost.Error.t()}
  def delete_asset(client, asset_id, opts) do
    discard(client, "/ads/google/assets/" <> encode(asset_id), opts)
  end

  # ── Performance Max asset groups ──

  @doc """
  Performance Max asset groups on the account, or on one campaign with `:campaign_id`.
  """
  @spec asset_groups(Client.t(), keyword()) ::
          {:ok, [GoogleAssetGroup.t()]} | {:error, FoPost.Error.t()}
  def asset_groups(client, opts) do
    params = Model.take_params(opts, @scope_params ++ [:campaign_id])

    with {:ok, data} <- Client.request(client, :get, "/ads/google/asset-groups", params: params) do
      {:ok, Model.list(GoogleAssetGroup, data)}
    end
  end

  @doc """
  Creates an asset group, paused unless `:status` says otherwise. Required:
  `:campaign_id`, `:name`, `:final_urls`. Needs `publish` as well as `ads`.
  """
  @spec create_asset_group(Client.t(), keyword()) ::
          {:ok, String.t()} | {:error, FoPost.Error.t()}
  def create_asset_group(client, opts) do
    body =
      Model.take_body(
        opts,
        @scope_body ++
          [{:campaign_id, "campaignId"}, :name, {:final_urls, "finalUrls"}, :status]
      )

    created(client, :post, "/ads/google/asset-groups", body)
  end

  @doc """
  Renames, pauses, or resumes an asset group. Needs `publish` as well as `ads`.
  """
  @spec update_asset_group(Client.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, FoPost.Error.t()}
  def update_asset_group(client, asset_group_id, opts) do
    body = Model.take_body(opts, @scope_body ++ [:name, :status])

    created(client, :patch, "/ads/google/asset-groups/" <> encode(asset_group_id), body)
  end

  @doc """
  Removes an asset group. Needs `publish` as well as `ads`.
  """
  @spec delete_asset_group(Client.t(), String.t(), keyword()) :: :ok | {:error, FoPost.Error.t()}
  def delete_asset_group(client, asset_group_id, opts) do
    discard(client, "/ads/google/asset-groups/" <> encode(asset_group_id), opts)
  end

  # ── Local Services leads ──

  @doc """
  Leads from Local Services Ads, read live and never stored. Required: `:since` and
  `:until`, `YYYY-MM-DD`.
  """
  @spec local_services_leads(Client.t(), keyword()) ::
          {:ok, [GoogleLocalServicesLead.t()]} | {:error, FoPost.Error.t()}
  def local_services_leads(client, opts) do
    params = Model.take_params(opts, @scope_params ++ [:since, :until])

    with {:ok, data} <-
           Client.request(client, :get, "/ads/google/local-services", params: params) do
      {:ok, Model.list(GoogleLocalServicesLead, data)}
    end
  end

  # ── Conversions ──

  @doc """
  The account's conversion actions.
  """
  @spec conversion_actions(Client.t(), keyword()) ::
          {:ok, [GoogleConversionAction.t()]} | {:error, FoPost.Error.t()}
  def conversion_actions(client, opts) do
    params = Model.take_params(opts, @scope_params)

    with {:ok, data} <- Client.request(client, :get, "/ads/google/conversions", params: params) do
      {:ok, Model.list(GoogleConversionAction, data)}
    end
  end

  @doc """
  Adds a conversion action. Required: `:name`, `:category`. Optional: `:value_minor`,
  `:counting_type`. Needs `publish` as well as `ads`.
  """
  @spec create_conversion_action(Client.t(), keyword()) ::
          {:ok, String.t()} | {:error, FoPost.Error.t()}
  def create_conversion_action(client, opts) do
    body =
      Model.take_body(
        opts,
        @scope_body ++
          [:name, :category, {:value_minor, "valueMinor"}, {:counting_type, "countingType"}]
      )

    created(client, :post, "/ads/google/conversions", body)
  end

  @doc """
  Sends offline conversions and answers how many landed. Required: `:conversions`.
  Needs `publish` as well as `ads`.
  """
  @spec upload_conversions(Client.t(), keyword()) :: {:ok, integer()} | {:error, FoPost.Error.t()}
  def upload_conversions(client, opts) do
    body = Model.take_body(opts, @scope_body ++ [:conversions])

    uploaded(client, "/ads/google/conversions/upload", body)
  end

  @doc """
  Sends conversion adjustments and answers how many landed. Required: `:adjustments`.
  Needs `publish` as well as `ads`.
  """
  @spec upload_conversion_adjustments(Client.t(), keyword()) ::
          {:ok, integer()} | {:error, FoPost.Error.t()}
  def upload_conversion_adjustments(client, opts) do
    body = Model.take_body(opts, @scope_body ++ [:adjustments])

    uploaded(client, "/ads/google/conversions/adjustments", body)
  end

  # ── GAQL ──

  @doc """
  Runs a read-only GAQL SELECT and answers the rows exactly as Google sends them.
  Required: `:query`. The account read is `:customer_id`, never anything named inside
  the query text.
  """
  @spec query(Client.t(), keyword()) :: {:ok, [map()]} | {:error, FoPost.Error.t()}
  def query(client, opts) do
    body = Model.take_body(opts, @scope_body ++ [:query])

    with {:ok, data} <- Client.request(client, :post, "/ads/insights/query", json: body) do
      {:ok, rows(data)}
    end
  end

  # ── Bang variants ──

  @doc "See `keywords/2`."
  def keywords!(client, opts), do: Result.unwrap!(keywords(client, opts))

  @doc "See `create_keyword/2`."
  def create_keyword!(client, opts), do: Result.unwrap!(create_keyword(client, opts))

  @doc "See `keyword_ideas/2`."
  def keyword_ideas!(client, opts), do: Result.unwrap!(keyword_ideas(client, opts))

  @doc "See `assets/2`."
  def assets!(client, opts), do: Result.unwrap!(assets(client, opts))

  @doc "See `asset_groups/2`."
  def asset_groups!(client, opts), do: Result.unwrap!(asset_groups(client, opts))

  @doc "See `conversion_actions/2`."
  def conversion_actions!(client, opts), do: Result.unwrap!(conversion_actions(client, opts))

  @doc "See `query/2`."
  def query!(client, opts), do: Result.unwrap!(query(client, opts))

  defp created(client, method, path, body) do
    with {:ok, data} <- Client.request(client, method, path, json: body) do
      {:ok, id(data)}
    end
  end

  defp uploaded(client, path, body) do
    with {:ok, data} <- Client.request(client, :post, path, json: body) do
      {:ok, count(data, "uploaded")}
    end
  end

  # A delete carries the scope in its body, the way the API takes it.
  defp discard(client, path, opts) do
    body = Model.take_body(opts, @scope_body)

    with {:ok, _data} <- Client.request(client, :delete, path, json: body) do
      :ok
    end
  end

  defp id(%{"id" => id}) when is_binary(id), do: id
  defp id(_data), do: ""

  defp count(data, key) when is_map(data), do: Map.get(data, key) || 0
  defp count(_data, _key), do: 0

  defp rows(%{"rows" => rows}) when is_list(rows), do: Enum.filter(rows, &is_map/1)
  defp rows(_data), do: []

  defp encode(value), do: URI.encode(to_string(value), &URI.char_unreserved?/1)
end
