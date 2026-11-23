defmodule FoPost.GoogleAds do
  @moduledoc """
  Google Ads: bid strategies, ad schedules, Local Services leads, conversions, and raw
  GAQL.

  Ads, audiences, and insights are on `FoPost.Ads` and dispatch by connection; a
  connection on another network answers 400 here. Every function needs the `ads` scope,
  and anything that changes what a live account serves or bids also needs `publish`.

  Every call names `:connection_id` and `:customer_id`. The customer id is digits only
  and has to name an account the connection's grant reaches: any other answers 404.
  `:workspace_id` may be left out on a read, and is required on a write.

      {:ok, strategies} =
        FoPost.GoogleAds.bid_strategies(client,
          connection_id: connection.id,
          customer_id: "1234567890"
        )

  An object id carries the account it belongs to, because a Google resource name cannot
  ride in a URL path segment: `1234567890~campaign~55`, `1234567890~adGroup~77`.
  Amounts are in the account's currency, in minor units.
  """

  alias FoPost.Client
  alias FoPost.GoogleAdScheduleSlot
  alias FoPost.GoogleBidStrategy
  alias FoPost.GoogleConversionAction
  alias FoPost.GoogleLocalServicesLead
  alias FoPost.Model
  alias FoPost.Result

  @scope_params [:workspace_id, :connection_id, :customer_id]
  @scope_body [
    {:workspace_id, "workspaceId"},
    {:connection_id, "connectionId"},
    {:customer_id, "customerId"}
  ]

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

  @doc "See `conversion_actions/2`."
  def conversion_actions!(client, opts), do: Result.unwrap!(conversion_actions(client, opts))

  @doc "See `query/2`."
  def query!(client, opts), do: Result.unwrap!(query(client, opts))

  defp created(client, method, path, body) do
    with {:ok, data} <- Client.request(client, method, path, json: body) do
      {:ok, id(data)}
    end
  end

  defp uploaded(client, path, body), do: counted(client, path, body, "uploaded")

  defp counted(client, path, body, key) do
    with {:ok, data} <- Client.request(client, :post, path, json: body) do
      {:ok, count(data, key)}
    end
  end

  defp id(%{"id" => id}) when is_binary(id), do: id
  defp id(_data), do: ""

  defp count(data, key) when is_map(data), do: Map.get(data, key) || 0
  defp count(_data, _key), do: 0

  defp rows(%{"rows" => rows}) when is_list(rows), do: Enum.filter(rows, &is_map/1)
  defp rows(_data), do: []
end
