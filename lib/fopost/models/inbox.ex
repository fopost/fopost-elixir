defmodule FoPost.InboxAccountRef do
  @moduledoc """
  The connected account an inbox item, thread, or conversation belongs to.
  """

  alias FoPost.Model

  defstruct [:id, :platform, :username, :name, :avatar, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      platform: fields["platform"],
      username: fields["username"],
      name: fields["name"],
      avatar: fields["avatar"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.InboxAttachment do
  @moduledoc """
  A file attached to an inbox item. `:url` and `:preview_url` are served by FoPost.
  """

  alias FoPost.Model

  defstruct [:kind, :name, :width, :height, :link, :url, :preview_url, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      kind: fields["kind"],
      name: fields["name"],
      width: fields["width"],
      height: fields["height"],
      link: fields["link"],
      url: fields["url"],
      preview_url: fields["preview_url"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.InboxPostContext do
  @moduledoc """
  The platform post a comment or mention sits under.
  """

  alias FoPost.Model

  defstruct [
    :external_id,
    :is_own,
    :text,
    :author_name,
    :author_handle,
    :author_avatar_url,
    :thumbnail_url,
    :permalink,
    :published_at,
    :published,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      external_id: fields["external_id"],
      is_own: fields["is_own"],
      text: fields["text"],
      author_name: fields["author_name"],
      author_handle: fields["author_handle"],
      author_avatar_url: fields["author_avatar_url"],
      thumbnail_url: fields["thumbnail_url"],
      permalink: fields["permalink"],
      published_at: Model.datetime(fields["published_at"]),
      published: Model.normalize(fields["published"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.InboxItem do
  @moduledoc """
  One comment, mention, or direct message on a connected account.

  `:type` is `"comment"`, `"mention"`, or `"dm"`; `:state` is `"unread"`, `"read"`,
  `"resolved"`, or `"snoozed"`; `:direction` is `"inbound"` or `"outbound"`. The `can_*`
  flags say which actions the platform supports for this item.
  """

  alias FoPost.InboxAccountRef
  alias FoPost.InboxAttachment
  alias FoPost.InboxPostContext
  alias FoPost.Model

  # Flat on purpose: every field mirrors one field of the API's InboxItem.
  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :workspace_id,
    :platform,
    :type,
    :state,
    :direction,
    :conversation_id,
    :author_name,
    :author_handle,
    :author_avatar_url,
    :text,
    :permalink,
    :post_external_id,
    :parent_external_id,
    :platform_created_at,
    :snoozed_until,
    :replied_at,
    :created_at,
    :can_reply,
    :hidden,
    :liked,
    :vote,
    :pinned,
    :reaction,
    :edited_at,
    :can_hide,
    :can_delete,
    :can_like,
    :can_vote,
    :can_pin,
    :can_edit,
    :can_react,
    :can_send_media,
    :can_quick_reply,
    :can_private_reply,
    :post,
    :post_context,
    :account,
    :raw,
    attachments: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      workspace_id: fields["workspace_id"],
      platform: fields["platform"],
      type: fields["type"],
      state: fields["state"],
      direction: fields["direction"],
      conversation_id: fields["conversation_id"],
      author_name: fields["author_name"],
      author_handle: fields["author_handle"],
      author_avatar_url: fields["author_avatar_url"],
      text: fields["text"],
      attachments: Model.list(InboxAttachment, fields["attachments"]),
      permalink: fields["permalink"],
      post_external_id: fields["post_external_id"],
      parent_external_id: fields["parent_external_id"],
      platform_created_at: Model.datetime(fields["platform_created_at"]),
      snoozed_until: Model.datetime(fields["snoozed_until"]),
      replied_at: Model.datetime(fields["replied_at"]),
      created_at: Model.datetime(fields["created_at"]),
      can_reply: fields["can_reply"],
      hidden: fields["hidden"],
      liked: fields["liked"],
      vote: fields["vote"],
      pinned: fields["pinned"],
      reaction: fields["reaction"],
      edited_at: Model.datetime(fields["edited_at"]),
      can_hide: fields["can_hide"],
      can_delete: fields["can_delete"],
      can_like: fields["can_like"],
      can_vote: fields["can_vote"],
      can_pin: fields["can_pin"],
      can_edit: fields["can_edit"],
      can_react: fields["can_react"],
      can_send_media: fields["can_send_media"],
      can_quick_reply: fields["can_quick_reply"],
      can_private_reply: fields["can_private_reply"],
      post: Model.normalize(fields["post"]),
      post_context: Model.build(InboxPostContext, fields["post_context"]),
      account: Model.build(InboxAccountRef, fields["account"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.InboxThread do
  @moduledoc """
  One post with comments (or mentions), rolled up: how many, how many unread, the latest.
  """

  alias FoPost.InboxAccountRef
  alias FoPost.InboxPostContext
  alias FoPost.Model

  defstruct [
    :workspace_id,
    :account_id,
    :post_external_id,
    :comment_count,
    :unread_count,
    :last_comment_at,
    :last_comment_text,
    :last_comment_author,
    :post,
    :account,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      workspace_id: fields["workspace_id"],
      account_id: fields["account_id"],
      post_external_id: fields["post_external_id"],
      comment_count: fields["comment_count"],
      unread_count: fields["unread_count"],
      last_comment_at: Model.datetime(fields["last_comment_at"]),
      last_comment_text: fields["last_comment_text"],
      last_comment_author: fields["last_comment_author"],
      post: Model.build(InboxPostContext, fields["post"]),
      account: Model.build(InboxAccountRef, fields["account"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.InboxConversation do
  @moduledoc """
  One direct-message thread, rolled up. `:participant` is the other party as a map of
  `name`, `handle`, and `avatar_url`.
  """

  alias FoPost.InboxAccountRef
  alias FoPost.Model

  defstruct [
    :workspace_id,
    :account_id,
    :conversation_id,
    :message_count,
    :unread_count,
    :last_message_at,
    :last_message_text,
    :last_message_outbound,
    :participant,
    :account,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      workspace_id: fields["workspace_id"],
      account_id: fields["account_id"],
      conversation_id: fields["conversation_id"],
      message_count: fields["message_count"],
      unread_count: fields["unread_count"],
      last_message_at: Model.datetime(fields["last_message_at"]),
      last_message_text: fields["last_message_text"],
      last_message_outbound: fields["last_message_outbound"],
      participant: Model.normalize(fields["participant"]),
      account: Model.build(InboxAccountRef, fields["account"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.InboxAccount do
  @moduledoc """
  A connected account and whether its comments (`:inbox_supported`) and direct messages
  (`:dm_supported`) can be read. The `*_pending_reason` fields say why not.
  `:can_start_conversation` says whether a new DM can be opened from it.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :workspace_id,
    :platform,
    :username,
    :name,
    :avatar,
    :inbox_supported,
    :pending_reason,
    :dm_supported,
    :dm_pending_reason,
    :can_start_conversation,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      workspace_id: fields["workspace_id"],
      platform: fields["platform"],
      username: fields["username"],
      name: fields["name"],
      avatar: fields["avatar"],
      inbox_supported: fields["inbox_supported"],
      pending_reason: fields["pending_reason"],
      dm_supported: fields["dm_supported"],
      dm_pending_reason: fields["dm_pending_reason"],
      can_start_conversation: fields["can_start_conversation"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.InboxPlatform do
  @moduledoc """
  Inbox support per platform. `:comments` and `:dms` are `"live"`, `"soon"`, or `"none"`.
  """

  alias FoPost.Model

  defstruct [:platform, :comments, :dms, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      platform: fields["platform"],
      comments: fields["comments"],
      dms: fields["dms"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.InboxApproval do
  @moduledoc """
  A reply an automation or the agent drafted that a person still has to send.

  `:id` is an integer. `:item` is the inbox item the reply answers.
  """

  alias FoPost.InboxItem
  alias FoPost.Model

  defstruct [:id, :workspace_id, :source, :reply, :created_at, :item, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      workspace_id: fields["workspace_id"],
      source: fields["source"],
      reply: fields["reply"],
      created_at: Model.datetime(fields["created_at"]),
      item: Model.build(InboxItem, fields["item"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.InboxDecision do
  @moduledoc """
  The answer to approving or rejecting a drafted reply.
  """

  alias FoPost.Model

  defstruct [:id, :outcome, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      outcome: fields["outcome"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.InboxRefreshResult do
  @moduledoc """
  What a manual inbox poll did. `:dm_reconnect` lists accounts whose DM access needs a
  fresh connection, as maps of `platform` and `account`.
  """

  alias FoPost.Model

  defstruct [:accounts_polled, :new_items, :rate_limited, :raw, dm_reconnect: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      accounts_polled: fields["accounts_polled"],
      new_items: fields["new_items"],
      rate_limited: fields["rate_limited"],
      dm_reconnect: Model.maps(fields["dm_reconnect"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.InboxReplyResult do
  @moduledoc """
  A sent reply: the updated item plus the reply's id and URL on the platform.
  """

  alias FoPost.InboxItem
  alias FoPost.Model

  defstruct [:item, :external_id, :external_url, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)
    reply = Model.normalize(fields["reply"])

    %__MODULE__{
      item: Model.build(InboxItem, fields["item"]),
      external_id: reply["external_id"],
      external_url: reply["external_url"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.InboxConversationStart do
  @moduledoc """
  A started conversation: its `:conversation_id` and the sent message as an item. Either
  may be `nil` when the platform does not report it.
  """

  alias FoPost.InboxItem
  alias FoPost.Model

  defstruct [:conversation_id, :item, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      conversation_id: fields["conversation_id"],
      item: Model.build(InboxItem, fields["item"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
