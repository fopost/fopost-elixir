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
