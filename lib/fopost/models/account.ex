defmodule FoPost.Account do
  @moduledoc """
  A connected social account — the thing a post is delivered to.

  `:name` is the display name override when one is set, else the platform's own name,
  which is always `:platform_name`.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :workspace_id,
    :platform,
    :username,
    :name,
    :platform_name,
    :avatar,
    :is_primary,
    :active,
    :health_status,
    :last_health_check,
    :workspace,
    :created_at,
    :updated_at,
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
      platform_name: fields["platform_name"],
      avatar: fields["avatar"],
      is_primary: fields["is_primary"],
      active: fields["active"],
      health_status: fields["health_status"],
      last_health_check: Model.datetime(fields["last_health_check"]),
      workspace: Model.normalize(fields["workspace"]),
      created_at: Model.datetime(fields["created_at"]),
      updated_at: Model.datetime(fields["updated_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AccountHealth do
  @moduledoc """
  How an account's stored credentials are holding up.

  `:health_status` is `"healthy"`, `"degraded"`, `"expired"`, `"revoked"`, or `"unknown"`.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :workspace_id,
    :platform,
    :username,
    :active,
    :health_status,
    :last_health_check,
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
      active: fields["active"],
      health_status: fields["health_status"],
      last_health_check: Model.datetime(fields["last_health_check"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.HealthSummary do
  @moduledoc """
  Every reachable account's health, plus the counts per status.
  """

  alias FoPost.AccountHealth
  alias FoPost.Model

  defstruct [:summary, :raw, accounts: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      accounts: Model.list(AccountHealth, fields["accounts"]),
      summary: Model.normalize(fields["summary"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ValidationResult do
  @moduledoc """
  Whether an account's credentials still work against its platform.
  """

  alias FoPost.Model

  defstruct [:account_id, :platform, :valid, :health_status, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      account_id: fields["account_id"],
      platform: fields["platform"],
      valid: fields["valid"],
      health_status: fields["health_status"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.TokenRefresh do
  @moduledoc """
  When a refreshed credential now expires.
  """

  alias FoPost.Model

  defstruct [:message, :expires_at, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      message: fields["message"],
      expires_at: Model.datetime(fields["expires_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AccountSnapshot do
  @moduledoc """
  One point in an account's follower history.
  """

  alias FoPost.Model

  defstruct [:followers, :following, :total_posts, :reach, :profile_views, :fetched_at, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      followers: fields["followers"],
      following: fields["following"],
      total_posts: fields["total_posts"],
      reach: fields["reach"],
      profile_views: fields["profile_views"],
      fetched_at: Model.datetime(fields["fetched_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.AccountAnalytics do
  @moduledoc """
  An account's stored snapshots, newest first.
  """

  alias FoPost.AccountSnapshot
  alias FoPost.Model

  defstruct [:account_id, :platform, :username, :raw, history: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      account_id: fields["account_id"],
      platform: fields["platform"],
      username: fields["username"],
      history: Model.list(AccountSnapshot, fields["history"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.TelegramConnectCode do
  @moduledoc """
  A one-time code, valid for 15 minutes, that connects a Telegram chat when `:command`
  (`/connect <code>`) is sent to the bot there.

  `:deep_link` opens a private chat with the bot and `:group_link` adds it to a group, both
  with the code included; either may be `nil`, as may `:bot_username`.
  """

  alias FoPost.Model

  defstruct [:code, :command, :bot_username, :deep_link, :group_link, :expires_at, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      code: fields["code"],
      command: fields["command"],
      bot_username: fields["bot_username"],
      deep_link: fields["deep_link"],
      group_link: fields["group_link"],
      expires_at: Model.datetime(fields["expires_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.TelegramConnectStatus do
  @moduledoc """
  Where a Telegram connect code stands.

  `:status` is `"pending"`, `"connected"` (with `:account_id`), `"failed"` (with
  `:reason`: `"card_required"`, `"slot_taken"`, or `"workspace_unavailable"`), or
  `"expired"`.
  """

  alias FoPost.Model

  defstruct [:status, :account_id, :reason, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      status: fields["status"],
      account_id: fields["account_id"],
      reason: fields["reason"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.TelegramBotCommand do
  @moduledoc """
  One entry in a Telegram bot's command menu: `:command` is 1-32 lowercase letters, digits,
  or underscores without the slash, and `:description` is 1-256 characters.
  """

  alias FoPost.Model

  defstruct [:command, :description, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      command: fields["command"],
      description: fields["description"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.SlackChannel do
  @moduledoc """
  A Slack channel the app can post to. `:is_member` says whether the bot is in it and
  `:is_current` whether this account posts to it.
  """

  alias FoPost.Model

  defstruct [:id, :name, :is_private, :is_member, :is_current, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      is_private: fields["is_private"],
      is_member: fields["is_member"],
      is_current: fields["is_current"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.SlackMember do
  @moduledoc """
  A person in the connected Slack workspace. Pass `:id` as the handle to start a DM.
  `:real_name`, `:display_name`, and `:avatar` may be `nil`.
  """

  alias FoPost.Model

  defstruct [:id, :name, :real_name, :display_name, :avatar, :is_bot, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      real_name: fields["real_name"],
      display_name: fields["display_name"],
      avatar: fields["avatar"],
      is_bot: fields["is_bot"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.SlackIdentity do
  @moduledoc """
  The name and icon a Slack account posts under. A `nil` `:username` posts under the app
  name; `:icon_emoji` is a code such as `":rocket:"`.
  """

  alias FoPost.Model

  defstruct [:username, :icon_url, :icon_emoji, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      username: fields["username"],
      icon_url: fields["icon_url"],
      icon_emoji: fields["icon_emoji"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.MetaIceBreaker do
  @moduledoc """
  A tappable prompt Messenger or Instagram shows before the first message.
  `:question` is up to 80 characters and `:payload` is what your webhook receives.
  """

  alias FoPost.Model

  defstruct [:question, :payload, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{question: fields["question"], payload: fields["payload"], raw: data}
  end

  def from_map(_data), do: nil
end

defmodule FoPost.MetaMenuItem do
  @moduledoc """
  A persistent-menu item: a `"postback"` carrying `:payload`, or a `"web_url"` carrying an
  http(s) `:url`. The unused one is `nil`.
  """

  alias FoPost.Model

  defstruct [:type, :title, :payload, :url, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      type: fields["type"],
      title: fields["title"],
      payload: fields["payload"],
      url: fields["url"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.MetaPersistentMenuEntry do
  @moduledoc """
  One locale's menu; `"default"` is the fallback every language uses.
  """

  alias FoPost.{MetaMenuItem, Model}

  defstruct [:locale, :call_to_actions, :composer_input_disabled, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      locale: fields["locale"] || "default",
      call_to_actions: Model.list(MetaMenuItem, fields["call_to_actions"]),
      composer_input_disabled: fields["composer_input_disabled"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.MetaGreetingText do
  @moduledoc """
  One locale's greeting, up to 160 characters.
  """

  alias FoPost.Model

  defstruct [:locale, :text, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{locale: fields["locale"] || "default", text: fields["text"], raw: data}
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WebhookSubscription do
  @moduledoc """
  What the network delivers to the FoPost webhook for one account. `:subscribed` is false
  when the subscription lapsed or a required field is missing.
  """

  alias FoPost.Model

  defstruct [:subscribed, :fields, :missing_fields, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      subscribed: fields["subscribed"] || false,
      fields: fields["fields"] || [],
      missing_fields: fields["missing_fields"] || [],
      raw: data
    }
  end

  def from_map(_data), do: nil
end
