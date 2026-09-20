defmodule FoPost.Whatsapp do
  @moduledoc """
  WhatsApp Business — a number the customer already owns.

  The platform owns templates, flows, the business profile and the commerce
  settings, so every function here is a live read or write against the customer's
  own WhatsApp Business Account. Nothing is cached, and all of it answers 503
  until WhatsApp is set up on the deployment.

  Every function needs the `accounts` scope, except the sandbox, which sends a
  template and needs `publish`.
  """

  alias FoPost.Client
  alias FoPost.Model
  alias FoPost.Result

  alias FoPost.WhatsappBlockResult
  alias FoPost.WhatsappCommerceSettings
  alias FoPost.WhatsappEncryptionKeyStatus
  alias FoPost.WhatsappFlow
  alias FoPost.WhatsappFlowJsonResult
  alias FoPost.WhatsappFlowResponse
  alias FoPost.WhatsappGroup
  alias FoPost.WhatsappProfile
  alias FoPost.WhatsappSandboxSession
  alias FoPost.WhatsappTemplate

  # ─── Profile ────────────────────────────────────────────────────────────

  @doc """
  The profile on the number, plus its quality rating and messaging limit tier.
  """
  @spec profile(Client.t(), String.t()) ::
          {:ok, WhatsappProfile.t()} | {:error, FoPost.Error.t()}
  def profile(client, account_id) do
    with {:ok, data} <- Client.request(client, :get, base(account_id) <> "/profile") do
      {:ok, WhatsappProfile.from_map(data)}
    end
  end

  @doc """
  A partial profile update. A key the caller never passed keeps its value.

  Takes `:about`, `:address`, `:description`, `:vertical`, `:websites` and
  `:profile_picture_media_id`.
  """
  @spec update_profile(Client.t(), String.t(), keyword()) ::
          {:ok, WhatsappProfile.t()} | {:error, FoPost.Error.t()}
  def update_profile(client, account_id, opts) do
    body =
      Model.take_body(opts, [
        :about,
        :address,
        :description,
        :vertical,
        :websites,
        :profile_picture_media_id
      ])

    with {:ok, data} <-
           Client.request(client, :patch, base(account_id) <> "/profile", json: body) do
      {:ok, WhatsappProfile.from_map(data)}
    end
  end

  @doc """
  Files a display name change for review. A review, not a write: the number keeps
  its old name until the review passes.
  """
  @spec request_display_name(Client.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, FoPost.Error.t()}
  def request_display_name(client, account_id, display_name) do
    body = %{"display_name" => display_name}

    with {:ok, data} <-
           Client.request(client, :post, base(account_id) <> "/profile/display-name", json: body) do
      {:ok, Model.normalize(data)}
    end
  end

  @doc """
  Sets the public username on the number.
  """
  @spec set_username(Client.t(), String.t(), String.t()) ::
          {:ok, WhatsappProfile.t()} | {:error, FoPost.Error.t()}
  def set_username(client, account_id, username) do
    body = %{"username" => username}

    with {:ok, data} <-
           Client.request(client, :put, base(account_id) <> "/profile/username", json: body) do
      {:ok, WhatsappProfile.from_map(data)}
    end
  end

  # ─── Templates ──────────────────────────────────────────────────────────

  @doc """
  Every template on the account, with the review status the platform assigned.
  Cursor paginated with `:after`.
  """
  @spec templates(Client.t(), String.t(), keyword()) ::
          {:ok, [WhatsappTemplate.t()]} | {:error, FoPost.Error.t()}
  def templates(client, account_id, opts \\ []) do
    params = Model.take_params(opts, [:after])

    with {:ok, data} <-
           Client.request(client, :get, base(account_id) <> "/templates", params: params) do
      {:ok, Model.list(WhatsappTemplate, data)}
    end
  end

  @doc """
  The pre-written templates the platform offers, for adapting instead of drafting.
  """
  @spec template_library(Client.t(), String.t(), keyword()) ::
          {:ok, [map()]} | {:error, FoPost.Error.t()}
  def template_library(client, account_id, opts \\ []) do
    params = Model.take_params(opts, [:search])

    with {:ok, data} <-
           Client.request(client, :get, base(account_id) <> "/templates/library", params: params) do
      {:ok, Model.maps(data)}
    end
  end

  @doc """
  One template and the review status it currently has.
  """
  @spec template(Client.t(), String.t(), String.t()) ::
          {:ok, WhatsappTemplate.t()} | {:error, FoPost.Error.t()}
  def template(client, account_id, template_id) do
    with {:ok, data} <-
           Client.request(client, :get, template_path(account_id, template_id)) do
      {:ok, WhatsappTemplate.from_map(data)}
    end
  end

  @doc """
  Files a template for review.

  Required: `:name`, `:language`, `:category`, `:components`. Optional:
  `:allow_category_change`. The result carries the status the platform assigned,
  which is `"PENDING"` on a normal submission — nothing marks a template approved
  but the platform.
  """
  @spec create_template(Client.t(), String.t(), keyword()) ::
          {:ok, WhatsappTemplate.t()} | {:error, FoPost.Error.t()}
  def create_template(client, account_id, opts) do
    body =
      Model.take_body(opts, [:name, :language, :category, :components, :allow_category_change])

    with {:ok, data} <-
           Client.request(client, :post, base(account_id) <> "/templates", json: body) do
      {:ok, WhatsappTemplate.from_map(data)}
    end
  end

  @doc """
  Creates a template from one of the platform's library entries.

  Required: `:library_template_name`, `:name`, `:language`, `:category`.
  """
  @spec import_template(Client.t(), String.t(), keyword()) ::
          {:ok, WhatsappTemplate.t()} | {:error, FoPost.Error.t()}
  def import_template(client, account_id, opts) do
    body =
      Model.take_body(opts, [
        :library_template_name,
        :name,
        :language,
        :category,
        :library_template_button_inputs
      ])

    with {:ok, data} <-
           Client.request(client, :post, base(account_id) <> "/templates/import", json: body) do
      {:ok, WhatsappTemplate.from_map(data)}
    end
  end

  @doc """
  Edits a template's `:category` or `:components`. The name cannot change.
  """
  @spec update_template(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, WhatsappTemplate.t()} | {:error, FoPost.Error.t()}
  def update_template(client, account_id, template_id, opts) do
    body = Model.take_body(opts, [:category, :components])

    with {:ok, data} <-
           Client.request(client, :patch, template_path(account_id, template_id), json: body) do
      {:ok, WhatsappTemplate.from_map(data)}
    end
  end

  @doc """
  Removes a template. The `:name` is required: it is what the platform deletes by.
  """
  @spec delete_template(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, FoPost.Error.t()}
  def delete_template(client, account_id, template_id, opts) do
    params = Model.take_params(opts, [:name])

    with {:ok, data} <-
           Client.request(client, :delete, template_path(account_id, template_id), params: params) do
      {:ok, Model.normalize(data)}
    end
  end

  # ─── Groups ─────────────────────────────────────────────────────────────

  @doc """
  The groups this number created.
  """
  @spec groups(Client.t(), String.t()) ::
          {:ok, [WhatsappGroup.t()]} | {:error, FoPost.Error.t()}
  def groups(client, account_id) do
    with {:ok, data} <- Client.request(client, :get, base(account_id) <> "/groups") do
      {:ok, Model.list(WhatsappGroup, data)}
    end
  end

  @doc """
  Creates a group. Required: `:subject`.

  Participation is invite-only: no endpoint adds someone, so the invite link is
  what you send them.
  """
  @spec create_group(Client.t(), String.t(), keyword()) ::
          {:ok, WhatsappGroup.t()} | {:error, FoPost.Error.t()}
  def create_group(client, account_id, opts) do
    body = Model.take_body(opts, [:subject, :description])

    with {:ok, data} <- Client.request(client, :post, base(account_id) <> "/groups", json: body) do
      {:ok, WhatsappGroup.from_map(data)}
    end
  end

  @doc """
  One group and its participant count.
  """
  @spec group(Client.t(), String.t(), String.t()) ::
          {:ok, WhatsappGroup.t()} | {:error, FoPost.Error.t()}
  def group(client, account_id, group_id) do
    with {:ok, data} <- Client.request(client, :get, group_path(account_id, group_id)) do
      {:ok, WhatsappGroup.from_map(data)}
    end
  end

  @doc """
  Changes a group's `:subject` or `:description`.
  """
  @spec update_group(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, WhatsappGroup.t()} | {:error, FoPost.Error.t()}
  def update_group(client, account_id, group_id, opts) do
    body = Model.take_body(opts, [:subject, :description])

    with {:ok, data} <-
           Client.request(client, :patch, group_path(account_id, group_id), json: body) do
      {:ok, WhatsappGroup.from_map(data)}
    end
  end

  @doc """
  Removes the group.
  """
  @spec delete_group(Client.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, FoPost.Error.t()}
  def delete_group(client, account_id, group_id) do
    with {:ok, data} <- Client.request(client, :delete, group_path(account_id, group_id)) do
      {:ok, Model.normalize(data)}
    end
  end

  @doc """
  The link someone joins the group with.
  """
  @spec group_invite_link(Client.t(), String.t(), String.t()) ::
          {:ok, String.t() | nil} | {:error, FoPost.Error.t()}
  def group_invite_link(client, account_id, group_id) do
    with {:ok, data} <-
           Client.request(client, :get, group_path(account_id, group_id) <> "/invite-link") do
      {:ok, Model.normalize(data)["invite_link"]}
    end
  end

  @doc """
  Issues a new invite link and invalidates the old one.
  """
  @spec reset_group_invite_link(Client.t(), String.t(), String.t()) ::
          {:ok, String.t() | nil} | {:error, FoPost.Error.t()}
  def reset_group_invite_link(client, account_id, group_id) do
    with {:ok, data} <-
           Client.request(client, :post, group_path(account_id, group_id) <> "/invite-link") do
      {:ok, Model.normalize(data)["invite_link"]}
    end
  end

  @doc """
  Removes people from the group. There is no matching add.
  """
  @spec remove_group_participants(Client.t(), String.t(), String.t(), [String.t()]) ::
          {:ok, map()} | {:error, FoPost.Error.t()}
  def remove_group_participants(client, account_id, group_id, users) do
    body = %{"users" => users}

    with {:ok, data} <-
           Client.request(client, :delete, group_path(account_id, group_id) <> "/participants",
             json: body
           ) do
      {:ok, Model.normalize(data)}
    end
  end

  # ─── Blocking ───────────────────────────────────────────────────────────

  @doc """
  The numbers this account has blocked. Cursor paginated with `:after`.
  """
  @spec blocked(Client.t(), String.t(), keyword()) ::
          {:ok, [String.t()]} | {:error, FoPost.Error.t()}
  def blocked(client, account_id, opts \\ []) do
    params = Model.take_params(opts, [:after])

    with {:ok, data} <-
           Client.request(client, :get, base(account_id) <> "/block", params: params) do
      {:ok, if(is_list(data), do: data, else: [])}
    end
  end

  @doc """
  Blocks up to 100 numbers, and names the ones the platform refused.
  """
  @spec block_users(Client.t(), String.t(), [String.t()]) ::
          {:ok, WhatsappBlockResult.t()} | {:error, FoPost.Error.t()}
  def block_users(client, account_id, users) do
    body = %{"users" => users}

    with {:ok, data} <- Client.request(client, :post, base(account_id) <> "/block", json: body) do
      {:ok, WhatsappBlockResult.from_map(data)}
    end
  end

  @doc """
  Unblocks up to 100 numbers.
  """
  @spec unblock_users(Client.t(), String.t(), [String.t()]) ::
          {:ok, WhatsappBlockResult.t()} | {:error, FoPost.Error.t()}
  def unblock_users(client, account_id, users) do
    body = %{"users" => users}

    with {:ok, data} <-
           Client.request(client, :delete, base(account_id) <> "/block", json: body) do
      {:ok, WhatsappBlockResult.from_map(data)}
    end
  end

  # ─── Commerce ───────────────────────────────────────────────────────────

  @doc """
  Whether the cart and catalog show on the number, and which catalog is linked.
  """
  @spec commerce_settings(Client.t(), String.t()) ::
          {:ok, WhatsappCommerceSettings.t()} | {:error, FoPost.Error.t()}
  def commerce_settings(client, account_id) do
    with {:ok, data} <- Client.request(client, :get, base(account_id) <> "/commerce") do
      {:ok, WhatsappCommerceSettings.from_map(data)}
    end
  end

  @doc """
  Turns the cart or the catalog on or off. Takes `:cart_enabled` and
  `:catalog_visible`.
  """
  @spec update_commerce_settings(Client.t(), String.t(), keyword()) ::
          {:ok, WhatsappCommerceSettings.t()} | {:error, FoPost.Error.t()}
  def update_commerce_settings(client, account_id, opts) do
    body =
      Model.take_body(opts, [
        {:cart_enabled, "is_cart_enabled"},
        {:catalog_visible, "is_catalog_visible"}
      ])

    with {:ok, data} <-
           Client.request(client, :patch, base(account_id) <> "/commerce", json: body) do
      {:ok, WhatsappCommerceSettings.from_map(data)}
    end
  end

  @doc """
  Points the number at a catalog the customer already owns.
  """
  @spec link_catalog(Client.t(), String.t(), String.t()) ::
          {:ok, WhatsappCommerceSettings.t()} | {:error, FoPost.Error.t()}
  def link_catalog(client, account_id, catalog_id) do
    body = %{"catalog_id" => catalog_id}

    with {:ok, data} <-
           Client.request(client, :post, base(account_id) <> "/commerce/catalog", json: body) do
      {:ok, WhatsappCommerceSettings.from_map(data)}
    end
  end

  # ─── Flows ──────────────────────────────────────────────────────────────

  @doc """
  The in-chat forms on this account, with their validation errors.
  """
  @spec flows(Client.t(), String.t()) :: {:ok, [WhatsappFlow.t()]} | {:error, FoPost.Error.t()}
  def flows(client, account_id) do
    with {:ok, data} <- Client.request(client, :get, base(account_id) <> "/flows") do
      {:ok, Model.list(WhatsappFlow, data)}
    end
  end

  @doc """
  One flow and what the platform found wrong with it.
  """
  @spec flow(Client.t(), String.t(), String.t()) ::
          {:ok, WhatsappFlow.t()} | {:error, FoPost.Error.t()}
  def flow(client, account_id, flow_id) do
    with {:ok, data} <- Client.request(client, :get, flow_path(account_id, flow_id)) do
      {:ok, WhatsappFlow.from_map(data)}
    end
  end

  @doc """
  Creates a draft flow. Required: `:name`, `:categories`. Its screens are
  uploaded separately with `upload_flow_json/4`.
  """
  @spec create_flow(Client.t(), String.t(), keyword()) ::
          {:ok, WhatsappFlow.t()} | {:error, FoPost.Error.t()}
  def create_flow(client, account_id, opts) do
    body = Model.take_body(opts, [:name, :categories, :endpoint_uri, :clone_flow_id])

    with {:ok, data} <- Client.request(client, :post, base(account_id) <> "/flows", json: body) do
      {:ok, WhatsappFlow.from_map(data)}
    end
  end

  @doc """
  Changes a flow's `:name`, `:categories` or `:endpoint_uri`.
  """
  @spec update_flow(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, WhatsappFlow.t()} | {:error, FoPost.Error.t()}
  def update_flow(client, account_id, flow_id, opts) do
    body = Model.take_body(opts, [:name, :categories, :endpoint_uri])

    with {:ok, data} <- Client.request(client, :patch, flow_path(account_id, flow_id), json: body) do
      {:ok, WhatsappFlow.from_map(data)}
    end
  end

  @doc """
  Deletes a draft flow. A published flow is deprecated instead.
  """
  @spec delete_flow(Client.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, FoPost.Error.t()}
  def delete_flow(client, account_id, flow_id) do
    with {:ok, data} <- Client.request(client, :delete, flow_path(account_id, flow_id)) do
      {:ok, Model.normalize(data)}
    end
  end

  @doc """
  Replaces the flow's screens. The platform answers with its validation errors
  rather than refusing, so they come back as data.
  """
  @spec upload_flow_json(Client.t(), String.t(), String.t(), map()) ::
          {:ok, WhatsappFlowJsonResult.t()} | {:error, FoPost.Error.t()}
  def upload_flow_json(client, account_id, flow_id, flow_json) do
    body = %{"flow_json" => flow_json}

    with {:ok, data} <-
           Client.request(client, :put, flow_path(account_id, flow_id) <> "/json", json: body) do
      {:ok, WhatsappFlowJsonResult.from_map(data)}
    end
  end

  @doc """
  Makes the flow sendable. A published flow can no longer be deleted.
  """
  @spec publish_flow(Client.t(), String.t(), String.t()) ::
          {:ok, WhatsappFlow.t()} | {:error, FoPost.Error.t()}
  def publish_flow(client, account_id, flow_id) do
    with {:ok, data} <-
           Client.request(client, :post, flow_path(account_id, flow_id) <> "/publish") do
      {:ok, WhatsappFlow.from_map(data)}
    end
  end

  @doc """
  Retires a published flow.
  """
  @spec deprecate_flow(Client.t(), String.t(), String.t()) ::
          {:ok, WhatsappFlow.t()} | {:error, FoPost.Error.t()}
  def deprecate_flow(client, account_id, flow_id) do
    with {:ok, data} <-
           Client.request(client, :post, flow_path(account_id, flow_id) <> "/deprecate") do
      {:ok, WhatsappFlow.from_map(data)}
    end
  end

  @doc """
  What people submitted through this account's flows, newest first.
  """
  @spec flow_responses(Client.t(), String.t()) ::
          {:ok, [WhatsappFlowResponse.t()]} | {:error, FoPost.Error.t()}
  def flow_responses(client, account_id) do
    with {:ok, data} <- Client.request(client, :get, base(account_id) <> "/flows/responses") do
      {:ok, Model.list(WhatsappFlowResponse, data)}
    end
  end

  @doc """
  Whether a business public key is registered, and how the platform judged its
  signature. The key itself is never returned.
  """
  @spec encryption_key_status(Client.t(), String.t()) ::
          {:ok, WhatsappEncryptionKeyStatus.t()} | {:error, FoPost.Error.t()}
  def encryption_key_status(client, account_id) do
    with {:ok, data} <-
           Client.request(client, :get, base(account_id) <> "/flows/encryption-key") do
      {:ok, WhatsappEncryptionKeyStatus.from_map(data)}
    end
  end

  @doc """
  Registers the public half of the key the platform encrypts a flow endpoint's
  payloads with. The private half stays with the customer.
  """
  @spec set_encryption_key(Client.t(), String.t(), String.t()) ::
          {:ok, WhatsappEncryptionKeyStatus.t()} | {:error, FoPost.Error.t()}
  def set_encryption_key(client, account_id, business_public_key) do
    body = %{"business_public_key" => business_public_key}

    with {:ok, data} <-
           Client.request(client, :put, base(account_id) <> "/flows/encryption-key", json: body) do
      {:ok, WhatsappEncryptionKeyStatus.from_map(data)}
    end
  end

  # ─── Account state and sandbox ──────────────────────────────────────────

  @doc """
  The account review and verification state, plus the number's quality rating,
  name status and messaging limit tier.
  """
  @spec account_events(Client.t(), String.t()) :: {:ok, map()} | {:error, FoPost.Error.t()}
  def account_events(client, account_id) do
    with {:ok, data} <- Client.request(client, :get, base(account_id) <> "/events") do
      {:ok, Model.normalize(data)}
    end
  end

  @doc """
  Sandbox invitations for a workspace. Required: `:workspace_id`.
  """
  @spec sandbox_sessions(Client.t(), keyword()) ::
          {:ok, [WhatsappSandboxSession.t()]} | {:error, FoPost.Error.t()}
  def sandbox_sessions(client, opts) do
    params = Model.take_params(opts, [{:workspace_id, "workspaceId"}])

    with {:ok, data} <-
           Client.request(client, :get, "/whatsapp/sandbox/sessions", params: params) do
      {:ok, Model.list(WhatsappSandboxSession, data)}
    end
  end

  @doc """
  Invites one tester to the platform-owned test number. Required:
  `:workspace_id`, `:phone_number`.

  Inviting sends a template, so this needs the `publish` scope.
  """
  @spec create_sandbox_session(Client.t(), keyword()) ::
          {:ok, WhatsappSandboxSession.t()} | {:error, FoPost.Error.t()}
  def create_sandbox_session(client, opts) do
    body =
      Model.take_body(opts, [{:workspace_id, "workspaceId"}, {:phone_number, "phoneNumber"}])

    with {:ok, data} <-
           Client.request(client, :post, "/whatsapp/sandbox/sessions", json: body) do
      {:ok, WhatsappSandboxSession.from_map(data)}
    end
  end

  # ─── Raising variants ───────────────────────────────────────────────────

  @doc "Same as `profile/2`, but raises `FoPost.Error`."
  def profile!(client, account_id), do: Result.unwrap!(profile(client, account_id))

  @doc "Same as `templates/3`, but raises `FoPost.Error`."
  def templates!(client, account_id, opts \\ []),
    do: Result.unwrap!(templates(client, account_id, opts))

  @doc "Same as `create_template/3`, but raises `FoPost.Error`."
  def create_template!(client, account_id, opts),
    do: Result.unwrap!(create_template(client, account_id, opts))

  @doc "Same as `flows/2`, but raises `FoPost.Error`."
  def flows!(client, account_id), do: Result.unwrap!(flows(client, account_id))

  @doc "Same as `create_flow/3`, but raises `FoPost.Error`."
  def create_flow!(client, account_id, opts),
    do: Result.unwrap!(create_flow(client, account_id, opts))

  @doc "Same as `create_sandbox_session/2`, but raises `FoPost.Error`."
  def create_sandbox_session!(client, opts),
    do: Result.unwrap!(create_sandbox_session(client, opts))

  defp base(account_id), do: "/accounts/" <> encode(account_id) <> "/whatsapp"

  defp template_path(account_id, template_id),
    do: base(account_id) <> "/templates/" <> encode(template_id)

  defp group_path(account_id, group_id), do: base(account_id) <> "/groups/" <> encode(group_id)

  defp flow_path(account_id, flow_id), do: base(account_id) <> "/flows/" <> encode(flow_id)

  defp encode(id), do: URI.encode(to_string(id), &URI.char_unreserved?/1)
end
