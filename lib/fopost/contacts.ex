defmodule FoPost.Contacts do
  @moduledoc """
  Contacts — the people behind the inbox.

  One row per human, however many handles they write from. Contacts are built
  for you: an inbound inbox item files its author, a reply files whoever you
  answered, and both fold into whatever is already on file. You can also
  create one by hand or import a list.

  Every function here needs the `inbox` scope — a key that may read a message
  may read who sent it — except `conversation_analytics/2`, which answers
  counts and reads under `analytics`.

  Contacts never cross a workspace. The same handle seen in two workspaces is
  two contacts.
  """

  alias FoPost.Client
  alias FoPost.Contact
  alias FoPost.ContactConversation
  alias FoPost.ContactField
  alias FoPost.ContactImportResult
  alias FoPost.ConversationAnalytics
  alias FoPost.Model
  alias FoPost.Page

  @list_params [:workspace_id, :search, :platform, :source, :page, :per_page]
  @analytics_params [:workspace_id, :accountId, :days, :sort, :page, :per_page]

  @doc """
  Contacts, most recently active first.

  Options: `:workspace_id`, `:search` (a display name or any handle),
  `:platform`, `:source` (`"inbox"`, `"radar"` or `"import"`), `:page`,
  `:per_page`.
  """
  @spec list(Client.t(), keyword()) :: {:ok, Page.t()} | {:error, FoPost.Error.t()}
  def list(client, opts \\ []) do
    params = Model.take_params(opts, @list_params)

    with {:ok, data} <- Client.request(client, :get, "/contacts", params: params, unwrap: false) do
      {:ok, page(data)}
    end
  end

  # The contacts list names its counters `pagination` rather than `meta`.
  defp page(body) when is_map(body) do
    Page.from_map(Map.put(body, "meta", Map.get(body, "pagination")), Contact)
  end

  defp page(_body), do: %Page{}

  @doc """
  One contact.

  A contact in a workspace the key cannot reach answers `404`, exactly as an
  id that never existed does.
  """
  @spec get(Client.t(), String.t()) :: {:ok, Contact.t()} | {:error, FoPost.Error.t()}
  def get(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id)) do
      {:ok, Contact.from_map(data)}
    end
  end

  @doc """
  Files a person by hand.

  Required: `:workspace_id` and `:channels`, a list of maps carrying
  `platform` and `handle`. Optional: `:display_name`, `:note`, `:fields`.

  It folds into the contact that already holds the first channel, so it cannot
  duplicate someone the inbox has already met.
  """
  @spec create(Client.t(), keyword()) :: {:ok, Contact.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    body = Model.take_body(opts, [:workspace_id, :channels, :display_name, :note, :fields])

    with {:ok, data} <- Client.request(client, :post, "/contacts", json: body) do
      {:ok, Contact.from_map(data)}
    end
  end

  @doc """
  Changes a contact.

  Only what you pass is written. A value in `:fields` set to `nil` clears it,
  and passing `:channels` replaces the list.
  """
  @spec update(Client.t(), String.t(), keyword()) ::
          {:ok, Contact.t()} | {:error, FoPost.Error.t()}
  def update(client, id, opts) do
    body = Model.take_body(opts, [:display_name, :channels, :note, :fields])

    with {:ok, data} <- Client.request(client, :patch, path(id), json: body) do
      {:ok, Contact.from_map(data)}
    end
  end

  @doc """
  Removes a contact. The messages stay in the inbox, and a later one files the
  person again.
  """
  @spec delete(Client.t(), String.t()) :: {:ok, map()} | {:error, FoPost.Error.t()}
  def delete(client, id) do
    Client.request(client, :delete, path(id))
  end

  @doc """
  The inbox threads one contact appears in, newest first.

  Options: `:limit`, up to 100.
  """
  @spec conversations(Client.t(), String.t(), keyword()) ::
          {:ok, [ContactConversation.t()]} | {:error, FoPost.Error.t()}
  def conversations(client, id, opts \\ []) do
    params = Model.take_params(opts, [:limit])

    with {:ok, data} <-
           Client.request(client, :get, path(id) <> "/conversations", params: params) do
      {:ok, Model.list(ContactConversation, data)}
    end
  end

  @doc """
  Imports contacts from CSV text.

  `platform` and `handle` are required columns; `external_id`, `display_name`
  and `note` are optional, and every other column is read as a custom field
  key. A column matching no field is reported back rather than stored.
  """
  @spec import(Client.t(), String.t(), String.t()) ::
          {:ok, ContactImportResult.t()} | {:error, FoPost.Error.t()}
  def import(client, workspace_id, csv) do
    body = %{"workspace_id" => workspace_id, "csv" => csv}

    with {:ok, data} <- Client.request(client, :post, "/contacts/import", json: body) do
      {:ok, ContactImportResult.from_map(data)}
    end
  end

  @doc """
  The columns this workspace keeps about a contact, in display order.
  """
  @spec list_fields(Client.t(), String.t()) ::
          {:ok, [ContactField.t()]} | {:error, FoPost.Error.t()}
  def list_fields(client, workspace_id) do
    params = [workspace_id: workspace_id]

    with {:ok, data} <- Client.request(client, :get, "/contacts/fields", params: params) do
      {:ok, Model.list(ContactField, data)}
    end
  end

  @doc """
  Adds a column.

  Required: `:key` (lower-case letters, digits and underscores, starting with
  a letter) and `:name`. Optional: `:type` and `:options`; a `"select"` field
  needs at least one option. A duplicate key answers `409`.
  """
  @spec create_field(Client.t(), String.t(), keyword()) ::
          {:ok, ContactField.t()} | {:error, FoPost.Error.t()}
  def create_field(client, workspace_id, opts) do
    body =
      opts
      |> Model.take_body([:key, :name, :type, :options])
      |> Map.put("workspace_id", workspace_id)

    with {:ok, data} <-
           Client.request(client, :post, "/contacts/fields",
             params: [workspace_id: workspace_id],
             json: body
           ) do
      {:ok, ContactField.from_map(data)}
    end
  end

  @doc """
  Renames a field, changes its options, or moves it. The key and the type are
  fixed once created.
  """
  @spec update_field(Client.t(), String.t(), keyword()) ::
          {:ok, ContactField.t()} | {:error, FoPost.Error.t()}
  def update_field(client, id, opts) do
    body = Model.take_body(opts, [:name, :options, :position])

    with {:ok, data} <- Client.request(client, :patch, field_path(id), json: body) do
      {:ok, ContactField.from_map(data)}
    end
  end

  @doc """
  Removes a field and every contact answer to it.
  """
  @spec delete_field(Client.t(), String.t()) :: {:ok, map()} | {:error, FoPost.Error.t()}
  def delete_field(client, id) do
    Client.request(client, :delete, field_path(id))
  end

  @doc """
  Inbox volume and reply time per thread.

  This one needs the `analytics` scope rather than `inbox`. Options:
  `:workspace_id`, `:accountId`, `:days` (1 to 365, the API defaults to 7),
  `:sort` (`"volume"`, `"slowest"` or `"recent"`), `:page`, `:per_page`.
  """
  @spec conversation_analytics(Client.t(), keyword()) ::
          {:ok, ConversationAnalytics.t()} | {:error, FoPost.Error.t()}
  def conversation_analytics(client, opts \\ []) do
    params = Model.take_params(opts, @analytics_params)

    with {:ok, data} <-
           Client.request(client, :get, "/analytics/inbox/conversations", params: params) do
      {:ok, ConversationAnalytics.from_map(data)}
    end
  end

  defp path(id), do: "/contacts/" <> URI.encode_www_form(id)
  defp field_path(id), do: "/contacts/fields/" <> URI.encode_www_form(id)
end
