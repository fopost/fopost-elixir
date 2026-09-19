defmodule FoPost.Inbox do
  @moduledoc """
  Comments, mentions, and direct messages on connected accounts.

  Every function needs the `inbox` scope. Lists answer a `FoPost.Page` whose
  `meta.current_page`, `meta.per_page`, and `meta.total` are set.

      {:ok, page} = FoPost.Inbox.list(client, workspace_id: id, state: "unread")
      {:ok, result} = FoPost.Inbox.reply(client, item.id, text: "Thanks!")
  """

  alias FoPost.Client
  alias FoPost.InboxAccount
  alias FoPost.InboxApproval
  alias FoPost.InboxConversation
  alias FoPost.InboxConversationStart
  alias FoPost.InboxDecision
  alias FoPost.InboxItem
  alias FoPost.InboxPlatform
  alias FoPost.InboxRefreshResult
  alias FoPost.InboxReplyResult
  alias FoPost.InboxThread
  alias FoPost.Message
  alias FoPost.Model
  alias FoPost.Page
  alias FoPost.Result

  @list_params [
    :workspace_id,
    :type,
    :state,
    :platform,
    :account_id,
    :post_id,
    :post_external_id,
    :conversation_id,
    :direction,
    :q,
    :sort,
    :page,
    :per_page
  ]

  @thread_params [
    :workspace_id,
    :kind,
    :platform,
    :account_id,
    :state,
    :q,
    :sort,
    :page,
    :per_page
  ]

  @conversation_params [
    :workspace_id,
    :platform,
    :account_id,
    :state,
    :q,
    :sort,
    :page,
    :per_page
  ]

  @doc """
  One page of items, newest first.

  Filters: `:workspace_id`, `:type` (`comment`, `mention`, `dm`), `:state` (`unread`,
  `read`, `resolved`, `snoozed`), `:platform`, `:account_id`, `:post_id`,
  `:post_external_id`, `:conversation_id`, `:direction` (`inbound`, `outbound`), `:q`,
  `:sort` (`newest`, `oldest`, `unanswered`). Paging: `:page`, `:per_page`.
  """
  @spec list(Client.t(), keyword()) :: {:ok, Page.t()} | {:error, FoPost.Error.t()}
  def list(client, opts \\ []) do
    params = Model.take_params(opts, @list_params)

    with {:ok, data} <- Client.request(client, :get, "/inbox", params: params, unwrap: false) do
      {:ok, Page.from_map(data, InboxItem)}
    end
  end

  @doc """
  One page of threads: one row per post with comments, or with mentions when `:kind` is
  `"mentions"`.

  Filters: `:workspace_id`, `:kind` (`comments`, `mentions`), `:platform`, `:account_id`,
  `:state`, `:q`, `:sort`. Paging: `:page`, `:per_page`.
  """
  @spec threads(Client.t(), keyword()) :: {:ok, Page.t()} | {:error, FoPost.Error.t()}
  def threads(client, opts \\ []) do
    params = Model.take_params(opts, @thread_params)
    req = [params: params, unwrap: false]

    with {:ok, data} <- Client.request(client, :get, "/inbox/posts", req) do
      {:ok, Page.from_map(data, InboxThread)}
    end
  end

  @doc """
  One page of direct-message threads, latest first.

  Filters: `:workspace_id`, `:platform`, `:account_id`, `:state`, `:q`, `:sort`. Paging:
  `:page`, `:per_page`.
  """
  @spec conversations(Client.t(), keyword()) :: {:ok, Page.t()} | {:error, FoPost.Error.t()}
  def conversations(client, opts \\ []) do
    params = Model.take_params(opts, @conversation_params)
    req = [params: params, unwrap: false]

    with {:ok, data} <- Client.request(client, :get, "/inbox/conversations", req) do
      {:ok, Page.from_map(data, InboxConversation)}
    end
  end

  @doc """
  How many items are unread, optionally narrowed with `:workspace_id`.
  """
  @spec unread_count(Client.t(), keyword()) :: {:ok, integer()} | {:error, FoPost.Error.t()}
  def unread_count(client, opts \\ []) do
    params = Model.take_params(opts, [:workspace_id])

    with {:ok, data} <- Client.request(client, :get, "/inbox/unread-count", params: params) do
      {:ok, count(data)}
    end
  end

  @doc """
  Every active account, flagged with whether comments and DMs can be read for it.
  """
  @spec accounts(Client.t(), keyword()) ::
          {:ok, [InboxAccount.t()]} | {:error, FoPost.Error.t()}
  def accounts(client, opts \\ []) do
    params = Model.take_params(opts, [:workspace_id])

    with {:ok, data} <- Client.request(client, :get, "/inbox/accounts", params: params) do
      {:ok, Model.list(InboxAccount, data)}
    end
  end

  @doc """
  Inbox support per platform.
  """
  @spec platforms(Client.t()) :: {:ok, [InboxPlatform.t()]} | {:error, FoPost.Error.t()}
  def platforms(client) do
    with {:ok, data} <- Client.request(client, :get, "/inbox/platforms") do
      {:ok, Model.list(InboxPlatform, data)}
    end
  end

  @doc """
  Marks a whole comment thread or DM thread read; answers how many items changed.

  Required: `:workspace_id`, `:account_id`, plus `:post_external_id` for a comment thread
  or `:conversation_id` for a DM thread.
  """
  @spec mark_thread_read(Client.t(), keyword()) ::
          {:ok, integer()} | {:error, FoPost.Error.t()}
  def mark_thread_read(client, opts) do
    body =
      Model.take_body(opts, [:workspace_id, :account_id, :post_external_id, :conversation_id])

    with {:ok, data} <- Client.request(client, :post, "/inbox/read", json: body) do
      {:ok, updated(data)}
    end
  end

  @doc """
  Polls every inbox-capable account in the workspace now. Required: `:workspace_id`.
  """
  @spec refresh(Client.t(), keyword()) ::
          {:ok, InboxRefreshResult.t()} | {:error, FoPost.Error.t()}
  def refresh(client, opts) do
    body = Model.take_body(opts, [:workspace_id])

    with {:ok, data} <- Client.request(client, :post, "/inbox/refresh", json: body) do
      {:ok, InboxRefreshResult.from_map(data)}
    end
  end

  @doc """
  Sets an item's state. Required: `:state` (`unread`, `read`, `resolved`, `snoozed`);
  `:snoozed_until` goes with `"snoozed"` and accepts a `DateTime` or an ISO 8601 string.
  """
  @spec update(Client.t(), String.t(), keyword()) ::
          {:ok, InboxItem.t()} | {:error, FoPost.Error.t()}
  def update(client, id, opts) do
    body =
      opts
      |> Model.take_body([:state])
      |> put_snoozed_until(opts)

    with {:ok, data} <- Client.request(client, :patch, path(id), json: body) do
      {:ok, InboxItem.from_map(data)}
    end
  end

  @doc """
  Edits our own comment on the platform. Only where `:can_edit` is true. Also needs the
  `publish` scope.
  """
  @spec edit_comment(Client.t(), String.t(), String.t()) ::
          {:ok, InboxItem.t()} | {:error, FoPost.Error.t()}
  def edit_comment(client, id, text) do
    with {:ok, data} <- Client.request(client, :patch, path(id), json: %{"text" => text}) do
      {:ok, InboxItem.from_map(data)}
    end
  end

  @doc """
  Sends a reply on the platform as the connected account. `:text` is required unless
  `:media_ids` is given.

  A DM reply may also carry `:media_ids` (media library ids, at most 10) and
  `:quick_replies` (at most 13, each at most 20 characters); either also needs the
  `publish` scope.
  """
  @spec reply(Client.t(), String.t(), keyword()) ::
          {:ok, InboxReplyResult.t()} | {:error, FoPost.Error.t()}
  def reply(client, id, opts) do
    body = Model.take_body(opts, [:text, :media_ids, :quick_replies])

    with {:ok, data} <- Client.request(client, :post, path(id, "reply"), json: body) do
      {:ok, InboxReplyResult.from_map(data)}
    end
  end

  @doc """
  Hides a comment on the platform.
  """
  @spec hide(Client.t(), String.t()) :: {:ok, InboxItem.t()} | {:error, FoPost.Error.t()}
  def hide(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id, "hide")) do
      {:ok, InboxItem.from_map(data)}
    end
  end

  @doc """
  Shows a hidden comment again.
  """
  @spec unhide(Client.t(), String.t()) :: {:ok, InboxItem.t()} | {:error, FoPost.Error.t()}
  def unhide(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id, "unhide")) do
      {:ok, InboxItem.from_map(data)}
    end
  end

  @doc """
  Deletes a comment on the platform, someone else's or our own reply. Deleting our own
  reply also needs the `publish` scope.
  """
  @spec delete(Client.t(), String.t()) :: {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete(client, id) do
    with {:ok, data} <- Client.request(client, :delete, path(id)) do
      {:ok, Message.from_map(data)}
    end
  end

  @doc """
  Likes an item on the platform (an upvote on Reddit, a favourite on Mastodon). Only where
  `:can_like` is true. Also needs the `publish` scope.
  """
  @spec like(Client.t(), String.t()) :: {:ok, InboxItem.t()} | {:error, FoPost.Error.t()}
  def like(client, id), do: action(client, id, "like")

  @doc """
  Removes our like. Only where `:can_like` is true. Also needs the `publish` scope.
  """
  @spec unlike(Client.t(), String.t()) :: {:ok, InboxItem.t()} | {:error, FoPost.Error.t()}
  def unlike(client, id), do: action(client, id, "unlike")

  @doc """
  Votes an item up or down where the network ranks by votes (Reddit), or takes an earlier
  vote back with `"none"`.

  Only where `:can_vote` is true. An upvote is the same call a like makes, so `:liked`
  moves with it. Also needs the `publish` scope.
  """
  @spec vote(Client.t(), String.t(), String.t()) ::
          {:ok, InboxItem.t()} | {:error, FoPost.Error.t()}
  def vote(client, id, direction) do
    with {:ok, data} <-
           Client.request(client, :post, path(id, "vote"),
             json: %{"direction" => to_string(direction)}
           ) do
      {:ok, InboxItem.from_map(data)}
    end
  end

  @doc """
  Pins our own comment. Only where `:can_pin` is true. Also needs the `publish` scope.
  """
  @spec pin(Client.t(), String.t()) :: {:ok, InboxItem.t()} | {:error, FoPost.Error.t()}
  def pin(client, id), do: action(client, id, "pin")

  @doc """
  Unpins our own comment. Only where `:can_pin` is true. Also needs the `publish` scope.
  """
  @spec unpin(Client.t(), String.t()) :: {:ok, InboxItem.t()} | {:error, FoPost.Error.t()}
  def unpin(client, id), do: action(client, id, "unpin")

  @doc """
  Reacts to a message with an emoji (at most 32 characters); `nil` removes ours. Only where
  `:can_react` is true. Also needs the `publish` scope.
  """
  @spec react(Client.t(), String.t(), String.t() | nil) ::
          {:ok, InboxItem.t()} | {:error, FoPost.Error.t()}
  def react(client, id, reaction) do
    body = %{"reaction" => reaction}

    with {:ok, data} <- Client.request(client, :post, path(id, "react"), json: body) do
      {:ok, InboxItem.from_map(data)}
    end
  end

  @doc """
  Opens a direct-message conversation and sends the first message. Also needs the
  `publish` scope.

  Required: `:text`, plus either `:handle` and `:account_id` (where the account's
  `:can_start_conversation` is true), or `:comment_id` for a private reply to an inbox
  comment (where the item's `:can_private_reply` is true). Optional: `:media_ids`, at
  most 10.
  """
  @spec start_conversation(Client.t(), keyword()) ::
          {:ok, InboxConversationStart.t()} | {:error, FoPost.Error.t()}
  def start_conversation(client, opts) do
    body = Model.take_body(opts, [:account_id, :handle, :comment_id, :text, :media_ids])

    with {:ok, data} <- Client.request(client, :post, "/inbox/conversations", json: body) do
      {:ok, InboxConversationStart.from_map(data)}
    end
  end

  @doc """
  Shows the typing indicator in a DM thread, or clears it with `on: false`; answers
  whether it is now on. `conversation_id` is the thread's `:conversation_id`. Required:
  `:account_id`. Also needs the `publish` scope.
  """
  @spec set_typing(Client.t(), String.t(), keyword()) ::
          {:ok, boolean()} | {:error, FoPost.Error.t()}
  def set_typing(client, conversation_id, opts) do
    body = Model.take_body(opts, [:account_id, :on])
    typing_path = "/inbox/conversations/" <> encode(conversation_id) <> "/typing"

    with {:ok, data} <- Client.request(client, :post, typing_path, json: body) do
      {:ok, typing(data)}
    end
  end

  @doc """
  Replies an automation or the agent drafted that a person still has to send.
  """
  @spec approvals(Client.t(), keyword()) ::
          {:ok, [InboxApproval.t()]} | {:error, FoPost.Error.t()}
  def approvals(client, opts \\ []) do
    params = Model.take_params(opts, [:workspace_id])

    with {:ok, data} <- Client.request(client, :get, "/inbox/approvals", params: params) do
      {:ok, Model.list(InboxApproval, data)}
    end
  end

  @doc """
  Sends a drafted reply, or `:text` in its place. `id` is the approval's integer id.
  """
  @spec approve_reply(Client.t(), integer(), keyword()) ::
          {:ok, InboxDecision.t()} | {:error, FoPost.Error.t()}
  def approve_reply(client, id, opts \\ []) do
    body = Model.take_body(opts, [:text])

    with {:ok, data} <- Client.request(client, :post, approval_path(id, "approve"), json: body) do
      {:ok, InboxDecision.from_map(data)}
    end
  end

  @doc """
  Discards a drafted reply. `id` is the approval's integer id.
  """
  @spec reject_reply(Client.t(), integer()) ::
          {:ok, InboxDecision.t()} | {:error, FoPost.Error.t()}
  def reject_reply(client, id) do
    with {:ok, data} <- Client.request(client, :post, approval_path(id, "reject")) do
      {:ok, InboxDecision.from_map(data)}
    end
  end

  @doc "Same as `list/2`, but raises `FoPost.Error`."
  def list!(client, opts \\ []), do: Result.unwrap!(list(client, opts))

  @doc "Same as `threads/2`, but raises `FoPost.Error`."
  def threads!(client, opts \\ []), do: Result.unwrap!(threads(client, opts))

  @doc "Same as `conversations/2`, but raises `FoPost.Error`."
  def conversations!(client, opts \\ []), do: Result.unwrap!(conversations(client, opts))

  @doc "Same as `unread_count/2`, but raises `FoPost.Error`."
  def unread_count!(client, opts \\ []), do: Result.unwrap!(unread_count(client, opts))

  @doc "Same as `accounts/2`, but raises `FoPost.Error`."
  def accounts!(client, opts \\ []), do: Result.unwrap!(accounts(client, opts))

  @doc "Same as `platforms/1`, but raises `FoPost.Error`."
  def platforms!(client), do: Result.unwrap!(platforms(client))

  @doc "Same as `mark_thread_read/2`, but raises `FoPost.Error`."
  def mark_thread_read!(client, opts), do: Result.unwrap!(mark_thread_read(client, opts))

  @doc "Same as `refresh/2`, but raises `FoPost.Error`."
  def refresh!(client, opts), do: Result.unwrap!(refresh(client, opts))

  @doc "Same as `update/3`, but raises `FoPost.Error`."
  def update!(client, id, opts), do: Result.unwrap!(update(client, id, opts))

  @doc "Same as `edit_comment/3`, but raises `FoPost.Error`."
  def edit_comment!(client, id, text), do: Result.unwrap!(edit_comment(client, id, text))

  @doc "Same as `reply/3`, but raises `FoPost.Error`."
  def reply!(client, id, opts), do: Result.unwrap!(reply(client, id, opts))

  @doc "Same as `hide/2`, but raises `FoPost.Error`."
  def hide!(client, id), do: Result.unwrap!(hide(client, id))

  @doc "Same as `unhide/2`, but raises `FoPost.Error`."
  def unhide!(client, id), do: Result.unwrap!(unhide(client, id))

  @doc "Same as `delete/2`, but raises `FoPost.Error`."
  def delete!(client, id), do: Result.unwrap!(delete(client, id))

  @doc "Same as `like/2`, but raises `FoPost.Error`."
  def like!(client, id), do: Result.unwrap!(like(client, id))

  @doc "Same as `unlike/2`, but raises `FoPost.Error`."
  def unlike!(client, id), do: Result.unwrap!(unlike(client, id))

  @doc "Same as `vote/3`, but raises `FoPost.Error`."
  def vote!(client, id, direction), do: Result.unwrap!(vote(client, id, direction))

  @doc "Same as `pin/2`, but raises `FoPost.Error`."
  def pin!(client, id), do: Result.unwrap!(pin(client, id))

  @doc "Same as `unpin/2`, but raises `FoPost.Error`."
  def unpin!(client, id), do: Result.unwrap!(unpin(client, id))

  @doc "Same as `react/3`, but raises `FoPost.Error`."
  def react!(client, id, reaction), do: Result.unwrap!(react(client, id, reaction))

  @doc "Same as `start_conversation/2`, but raises `FoPost.Error`."
  def start_conversation!(client, opts), do: Result.unwrap!(start_conversation(client, opts))

  @doc "Same as `set_typing/3`, but raises `FoPost.Error`."
  def set_typing!(client, conversation_id, opts),
    do: Result.unwrap!(set_typing(client, conversation_id, opts))

  @doc "Same as `approvals/2`, but raises `FoPost.Error`."
  def approvals!(client, opts \\ []), do: Result.unwrap!(approvals(client, opts))

  @doc "Same as `approve_reply/3`, but raises `FoPost.Error`."
  def approve_reply!(client, id, opts \\ []), do: Result.unwrap!(approve_reply(client, id, opts))

  @doc "Same as `reject_reply/2`, but raises `FoPost.Error`."
  def reject_reply!(client, id), do: Result.unwrap!(reject_reply(client, id))

  defp action(client, id, action) do
    with {:ok, data} <- Client.request(client, :post, path(id, action)) do
      {:ok, InboxItem.from_map(data)}
    end
  end

  defp put_snoozed_until(body, opts) do
    case Keyword.fetch(opts, :snoozed_until) do
      {:ok, value} -> Map.put(body, "snoozedUntil", Model.to_iso8601(value))
      :error -> body
    end
  end

  defp count(%{"count" => count}) when is_integer(count), do: count
  defp count(_data), do: 0

  defp typing(%{"typing" => typing}) when is_boolean(typing), do: typing
  defp typing(_data), do: false

  defp updated(%{"updated" => updated}) when is_integer(updated), do: updated
  defp updated(_data), do: 0

  defp path(id), do: "/inbox/" <> encode(id)
  defp path(id, action), do: path(id) <> "/" <> action

  defp approval_path(id, action), do: "/inbox/approvals/" <> encode(id) <> "/" <> action

  defp encode(id), do: URI.encode(to_string(id), &URI.char_unreserved?/1)
end
