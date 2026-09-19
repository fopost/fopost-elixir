defmodule FoPost.Ads do
  @moduledoc """
  Meta ads: boosts, standalone ads, audiences, targeting, and lead forms.

  Every function needs the `ads` scope. `boost/2`, `create/2`, `set_status/3`, and
  `delete/3` spend money and also need the `publish` scope. A boost or an ad starts
  paused unless `:paused` is `false`.

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
  alias FoPost.AdConnection
  alias FoPost.AdSource
  alias FoPost.AudiencesResult
  alias FoPost.BoostablePost
  alias FoPost.Client
  alias FoPost.CreatedAudience
  alias FoPost.ExternalAd
  alias FoPost.LeadFormSource
  alias FoPost.LeadsPage
  alias FoPost.Message
  alias FoPost.Model
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
                     {:media_url, "mediaUrl"}
                   ]

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
  The Meta login URL; finish it in a browser. Required: `:workspace_id`. Optional:
  `:method` (`business`, `user`), `:return_to`.
  """
  @spec authorize_meta(Client.t(), keyword()) :: {:ok, String.t()} | {:error, FoPost.Error.t()}
  def authorize_meta(client, opts) do
    body =
      Model.take_body(opts, [{:workspace_id, "workspaceId"}, :method, {:return_to, "returnTo"}])

    with {:ok, data} <-
           Client.request(client, :post, "/ads/connections/meta/authorize", json: body) do
      {:ok, url(data)}
    end
  end

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
  `:media_url`, `:paused`.
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

  defp get(client, path, opts) do
    Client.request(client, :get, path, params: Model.take_params(opts, [:workspace_id]))
  end

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
