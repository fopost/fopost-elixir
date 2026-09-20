defmodule FoPost.Broadcasts do
  @moduledoc """
  Broadcasts — one message into every conversation the workspace already has
  with a segment of its contacts.

  A broadcast is not a post and not a cold DM: every message lands in a
  direct-message thread the contact already started.

  Nothing is sent into a closed messaging window. Messenger and Instagram take
  a business-initiated message only within 24 hours of the contact's last one,
  so recipients outside it come back skipped with `"window_closed"` and
  nothing is attempted — which is why the number sent is often lower than the
  audience. Telegram, Slack, Bluesky and Reddit have no window.

  Reading needs the `inbox` scope; `send/2` and `cancel/2` also need
  `publish`.
  """

  alias FoPost.Broadcast
  alias FoPost.BroadcastRecipient
  alias FoPost.BroadcastSent
  alias FoPost.Client
  alias FoPost.Model
  alias FoPost.Page

  @list_params [:workspace_id, :status, :page, :per_page]
  @recipient_params [:status, :page, :per_page]
  @create_body [:workspace_id, :account_id, :name, :text, :media_id, :audience, :scheduled_at]
  @update_body [:name, :text, :media_id, :audience, :scheduled_at]

  @doc """
  Broadcasts, newest first.

  Options: `:workspace_id`, `:status` (`"draft"`, `"scheduled"`, `"sending"`,
  `"sent"` or `"cancelled"`), `:page`, `:per_page`.
  """
  @spec list(Client.t(), keyword()) :: {:ok, Page.t()} | {:error, FoPost.Error.t()}
  def list(client, opts \\ []) do
    params = Model.take_params(opts, @list_params)

    with {:ok, data} <- Client.request(client, :get, "/broadcasts", params: params, unwrap: false) do
      {:ok, page(data, Broadcast)}
    end
  end

  @doc """
  One broadcast.

  A broadcast in a workspace the key cannot reach answers `404`, exactly as an
  id that never existed does.
  """
  @spec get(Client.t(), String.t()) :: {:ok, Broadcast.t()} | {:error, FoPost.Error.t()}
  def get(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id)) do
      {:ok, Broadcast.from_map(data)}
    end
  end

  @doc """
  Writes a broadcast without sending it.

  Required: `:workspace_id`, `:account_id`, `:name` and `:text`. Optional:
  `:media_id`, `:audience` (a map of clauses over contacts) and
  `:scheduled_at`, which has it go out on its own at that time. An omitted
  audience means every contact in the workspace.
  """
  @spec create(Client.t(), keyword()) :: {:ok, Broadcast.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    body = Model.take_body(opts, @create_body)

    with {:ok, data} <- Client.request(client, :post, "/broadcasts", json: body) do
      {:ok, Broadcast.from_map(data)}
    end
  end

  @doc """
  Changes a broadcast. Only a draft or scheduled broadcast can be edited.
  """
  @spec update(Client.t(), String.t(), keyword()) ::
          {:ok, Broadcast.t()} | {:error, FoPost.Error.t()}
  def update(client, id, opts) do
    body = Model.take_body(opts, @update_body)

    with {:ok, data} <- Client.request(client, :patch, path(id), json: body) do
      {:ok, Broadcast.from_map(data)}
    end
  end

  @doc """
  Freezes the audience into a recipient list and starts sending.

  The returned `:recipients` is how many contacts matched, not how many will
  be messaged — the messaging window decides that. Needs the `publish` scope
  as well as `inbox`.
  """
  @spec send(Client.t(), String.t()) :: {:ok, BroadcastSent.t()} | {:error, FoPost.Error.t()}
  def send(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id) <> "/send", json: %{}) do
      {:ok, BroadcastSent.from_map(data)}
    end
  end

  @doc """
  Stops a broadcast where it stands.

  Anyone not yet written to stays unsent; messages already delivered are not
  recalled. Needs the `publish` scope.
  """
  @spec cancel(Client.t(), String.t()) :: {:ok, Broadcast.t()} | {:error, FoPost.Error.t()}
  def cancel(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id) <> "/cancel", json: %{}) do
      {:ok, Broadcast.from_map(data)}
    end
  end

  @doc """
  One row per contact, with what became of their message.

  A skipped row carries its `:skip_reason`. Options: `:status`, `:page`,
  `:per_page`.
  """
  @spec recipients(Client.t(), String.t(), keyword()) ::
          {:ok, Page.t()} | {:error, FoPost.Error.t()}
  def recipients(client, id, opts \\ []) do
    params = Model.take_params(opts, @recipient_params)

    with {:ok, data} <-
           Client.request(client, :get, path(id) <> "/recipients",
             params: params,
             unwrap: false
           ) do
      {:ok, page(data, BroadcastRecipient)}
    end
  end

  @doc """
  Removes a broadcast and its recipient records.

  Messages already sent stay in the conversations they went to.
  """
  @spec delete(Client.t(), String.t()) :: {:ok, map()} | {:error, FoPost.Error.t()}
  def delete(client, id) do
    Client.request(client, :delete, path(id))
  end

  # These lists name their counters `pagination` rather than `meta`, like contacts.
  defp page(body, module) when is_map(body) do
    Page.from_map(Map.put(body, "meta", Map.get(body, "pagination")), module)
  end

  defp page(_body, _module), do: %Page{}

  defp path(id), do: "/broadcasts/" <> URI.encode(to_string(id))
end
