defmodule FoPost.GoogleBusiness do
  @moduledoc """
  Manage a connected Google Business Profile location: the profile itself,
  attributes, food menus, services, photos, place action links, verification
  and performance.

  Google grants Business Profile API access per project. Until that grant lands
  on a deployment every call here answers `{:error, %FoPost.Error{status: 503}}`
  with the code `configuration_error`.

  Responses relay Google's own shape, field for field, so they come back as
  plain maps rather than structs we would have to keep chasing.
  """

  alias FoPost.Account
  alias FoPost.Client
  alias FoPost.Model

  @type payload :: map()
  @type result :: {:ok, payload()} | {:error, FoPost.Error.t()}

  @doc """
  The daily metrics fetched when a caller names none.
  """
  @spec default_daily_metrics() :: [String.t()]
  def default_daily_metrics do
    [
      "BUSINESS_IMPRESSIONS_DESKTOP_MAPS",
      "BUSINESS_IMPRESSIONS_DESKTOP_SEARCH",
      "BUSINESS_IMPRESSIONS_MOBILE_MAPS",
      "BUSINESS_IMPRESSIONS_MOBILE_SEARCH",
      "CALL_CLICKS",
      "WEBSITE_CLICKS",
      "BUSINESS_DIRECTION_REQUESTS"
    ]
  end

  @doc """
  The connected location, in the Business Information shape.
  """
  @spec get_location(Client.t(), String.t()) :: result()
  def get_location(client, id), do: read(client, :get, path(id, "/location"))

  @doc """
  Patches the profile.

  Only the keys `fields` carries change, and a `nil` clears that field. Keys are
  the API's own snake_case names: `"title"`, `"description"`, `"website_uri"`,
  `"primary_phone"`, `"additional_phones"`, `"store_code"`, `"regular_hours"`.
  """
  @spec update_location(Client.t(), String.t(), map()) :: result()
  def update_location(client, id, fields) when is_map(fields) do
    read(client, :patch, path(id, "/location"), json: fields)
  end

  @doc """
  The attribute values set on the location.

  `available: true` lists the attributes Google offers for the location's
  category and region instead. Also takes `:category_name`, `:region_code` and
  `:language_code`.
  """
  @spec get_attributes(Client.t(), String.t(), keyword()) :: result()
  def get_attributes(client, id, opts \\ []) do
    params =
      Model.take_params(opts, [:available, :category_name, :region_code, :language_code])

    read(client, :get, path(id, "/attributes"), params: params)
  end

  @doc """
  Changes only the named attributes; every other one is left alone.
  """
  @spec update_attributes(Client.t(), String.t(), [map()]) :: result()
  def update_attributes(client, id, attributes) when is_list(attributes) do
    read(client, :patch, path(id, "/attributes"), json: %{"attributes" => attributes})
  end

  @doc """
  The location's food menus.
  """
  @spec get_menus(Client.t(), String.t()) :: result()
  def get_menus(client, id), do: read(client, :get, path(id, "/menus"))

  @doc """
  Replaces the whole menu set; Google has no per-section patch.
  """
  @spec replace_menus(Client.t(), String.t(), [map()]) :: result()
  def replace_menus(client, id, menus) when is_list(menus) do
    read(client, :put, path(id, "/menus"), json: %{"menus" => menus})
  end

  @doc """
  The location's service list.
  """
  @spec get_services(Client.t(), String.t()) :: result()
  def get_services(client, id), do: read(client, :get, path(id, "/services"))

  @doc """
  Replaces the whole service list.
  """
  @spec replace_services(Client.t(), String.t(), [map()]) :: result()
  def replace_services(client, id, service_items) when is_list(service_items) do
    read(client, :put, path(id, "/services"), json: %{"service_items" => service_items})
  end

  @doc """
  The photos on the location. Takes `:page_size` and `:page_token`.
  """
  @spec list_media(Client.t(), String.t(), keyword()) :: result()
  def list_media(client, id, opts \\ []) do
    read(client, :get, path(id, "/media"),
      params: Model.take_params(opts, [:page_size, :page_token])
    )
  end

  @doc """
  Adds a photo from the media library.

  The asset has to be in a workspace the caller can reach, and JPEG or PNG.
  Takes `:media_id` (required), `:category` and `:description`.
  """
  @spec add_media(Client.t(), String.t(), keyword()) :: result()
  def add_media(client, id, opts) do
    body =
      opts
      |> Model.take_body([:media_id, :category, :description])
      |> Map.put_new("category", "ADDITIONAL")

    read(client, :post, path(id, "/media"), json: body)
  end

  @doc """
  Removes a photo by the media key Google returned.
  """
  @spec delete_media(Client.t(), String.t(), String.t()) :: result()
  def delete_media(client, id, media_key) do
    read(client, :delete, path(id, "/media/#{URI.encode(media_key)}"))
  end

  @doc """
  The Book, Order and Reserve links on the listing.
  """
  @spec list_place_actions(Client.t(), String.t()) :: result()
  def list_place_actions(client, id), do: read(client, :get, path(id, "/place-actions"))

  @doc """
  Adds an action link to the listing.

  Takes `:uri` and `:place_action_type` (both required) and `:is_preferred`.
  """
  @spec create_place_action(Client.t(), String.t(), keyword()) :: result()
  def create_place_action(client, id, opts) do
    body = Model.take_body(opts, [:uri, :place_action_type, :is_preferred])
    read(client, :post, path(id, "/place-actions"), json: body)
  end

  @doc """
  Patches one action link. An omitted key is left alone. Takes `:uri` and
  `:is_preferred`.
  """
  @spec update_place_action(Client.t(), String.t(), String.t(), keyword()) :: result()
  def update_place_action(client, id, link_id, opts) do
    body = Model.take_body(opts, [:uri, :is_preferred])
    read(client, :patch, path(id, "/place-actions/#{URI.encode(link_id)}"), json: body)
  end

  @doc """
  Removes one action link.
  """
  @spec delete_place_action(Client.t(), String.t(), String.t()) :: result()
  def delete_place_action(client, id, link_id) do
    read(client, :delete, path(id, "/place-actions/#{URI.encode(link_id)}"))
  end

  @doc """
  The ways Google will let this location be verified. Takes `:language_code`.
  """
  @spec get_verification_options(Client.t(), String.t(), keyword()) :: result()
  def get_verification_options(client, id, opts \\ []) do
    read(client, :get, path(id, "/verification"),
      params: Model.take_params(opts, [:language_code])
    )
  end

  @doc """
  Starts a verification.

  `:method` is `"ADDRESS"`, `"EMAIL"`, `"PHONE_CALL"`, `"SMS"`, `"AUTO"` or
  `"VETTED_PARTNER"`; the response names the pending verification to complete
  with the PIN. Also takes `:language_code`, `:phone_number`, `:email_address`
  and `:mailer_contact_name`.
  """
  @spec start_verification(Client.t(), String.t(), keyword()) :: result()
  def start_verification(client, id, opts) do
    body =
      Model.take_body(opts, [
        :method,
        :language_code,
        :phone_number,
        :email_address,
        :mailer_contact_name
      ])

    read(client, :post, path(id, "/verification/start"), json: body)
  end

  @doc """
  Completes a pending verification with the PIN Google sent.
  """
  @spec complete_verification(Client.t(), String.t(), String.t(), String.t()) :: result()
  def complete_verification(client, id, verification_name, pin) do
    body = %{"verification_name" => verification_name, "pin" => pin}
    read(client, :post, path(id, "/verification/complete"), json: body)
  end

  @doc """
  Daily impressions, calls, direction requests and clicks for the range.

  `:start_date` and `:end_date` are ISO dates. `:daily_metrics` is a list; left
  out, the API uses its own default set.
  """
  @spec get_performance(Client.t(), String.t(), keyword()) :: result()
  def get_performance(client, id, opts) do
    # Req cannot encode a list query value, so the metrics go as one
    # comma-separated value, which the API reads as well as repeated ones.
    opts = Keyword.replace_lazy(opts, :daily_metrics, &Enum.join(List.wrap(&1), ","))
    params = Model.take_params(opts, [:start_date, :end_date, :daily_metrics])
    read(client, :get, path(id, "/performance"), params: params)
  end

  @doc """
  The search terms people used to find the listing, by month.

  Takes `:start_date` and `:end_date` (both required) and `:page_token`.
  """
  @spec get_search_keywords(Client.t(), String.t(), keyword()) :: result()
  def get_search_keywords(client, id, opts) do
    params =
      [{"keywords", "true"} | Model.take_params(opts, [:start_date, :end_date, :page_token])]

    read(client, :get, path(id, "/performance"), params: params)
  end

  @doc """
  Hands the location to another workspace the caller owns.

  The connection and every row keyed to it move in one transaction.
  """
  @spec assign(Client.t(), String.t(), String.t()) ::
          {:ok, Account.t()} | {:error, FoPost.Error.t()}
  def assign(client, id, workspace_id) do
    body = %{"workspace_id" => workspace_id}

    with {:ok, data} <- Client.request(client, :post, path(id, "/assign"), json: body) do
      {:ok, Account.from_map(data)}
    end
  end

  defp read(client, method, path, opts \\ []) do
    with {:ok, data} <- Client.request(client, method, path, opts) do
      {:ok, if(is_map(data), do: data, else: %{"data" => data})}
    end
  end

  defp path(id, suffix), do: "/accounts/#{URI.encode(id)}/gbp#{suffix}"
end
