defmodule FoPost.Accounts do
  @moduledoc """
  Connected social accounts — what a post is actually delivered to.

  Accounts on platforms that use OAuth are connected in the FoPost dashboard; `create/2`
  is for the platforms where you already hold the credentials.
  """

  alias FoPost.Account
  alias FoPost.AccountAnalytics
  alias FoPost.AccountHealth
  alias FoPost.Client
  alias FoPost.DiscordAck
  alias FoPost.DiscordChannel
  alias FoPost.DiscordIdentity
  alias FoPost.DiscordMember
  alias FoPost.DiscordMessage
  alias FoPost.DiscordMessageRef
  alias FoPost.DiscordRole
  alias FoPost.DiscordScheduledEvent
  alias FoPost.DiscordThread
  alias FoPost.HealthSummary
  alias FoPost.Message
  alias FoPost.Model
  alias FoPost.Result
  alias FoPost.SlackChannel
  alias FoPost.SlackIdentity
  alias FoPost.SlackMember
  alias FoPost.TelegramBotCommand
  alias FoPost.TelegramConnectCode
  alias FoPost.TelegramConnectStatus
  alias FoPost.ValidationResult

  @doc """
  The connected accounts the key can reach, optionally narrowed with `:workspace_id` or
  `:group_id` (an account group).
  """
  @spec list(Client.t(), keyword()) :: {:ok, [Account.t()]} | {:error, FoPost.Error.t()}
  def list(client, opts \\ []) do
    params = Model.take_params(opts, [{:workspace_id, "workspaceId"}, :group_id])

    with {:ok, data} <- Client.request(client, :get, "/accounts", params: params) do
      {:ok, Model.list(Account, data)}
    end
  end

  @doc """
  One account.
  """
  @spec get(Client.t(), String.t()) :: {:ok, Account.t()} | {:error, FoPost.Error.t()}
  def get(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id)) do
      {:ok, Account.from_map(data)}
    end
  end

  @doc """
  Connects an account from credentials you already hold.

  Required: `:workspace_id`, `:platform`, `:username`, `:name`. Optional: `:avatar`,
  `:credentials` — a map of the platform's own fields.
  """
  @spec create(Client.t(), keyword()) :: {:ok, Account.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    body =
      Model.take_body(opts, [
        {:workspace_id, "workspaceId"},
        :platform,
        :username,
        :name,
        :avatar,
        :credentials
      ])

    with {:ok, data} <- Client.request(client, :post, "/accounts", json: body) do
      {:ok, Account.from_map(data)}
    end
  end

  @doc """
  Sets the name FoPost shows for an account. A `nil` or empty `display_name` restores the
  platform's own name, which stays readable as `:platform_name`.
  """
  @spec rename(Client.t(), String.t(), String.t() | nil) ::
          {:ok, Account.t()} | {:error, FoPost.Error.t()}
  def rename(client, id, display_name) do
    body = %{"display_name" => display_name}

    with {:ok, data} <- Client.request(client, :patch, path(id), json: body) do
      {:ok, Account.from_map(data)}
    end
  end

  @doc """
  Moves an account to another workspace the caller owns.

  A blocked move is a 409 whose `code` is `"move_blocked"`; the reasons are under
  `"blocking_tables"` in the error's body.
  """
  @spec move(Client.t(), String.t(), String.t()) ::
          {:ok, Account.t()} | {:error, FoPost.Error.t()}
  def move(client, id, workspace_id) do
    body = %{"workspace_id" => workspace_id}

    with {:ok, data} <- Client.request(client, :post, path(id) <> "/move", json: body) do
      {:ok, Account.from_map(data)}
    end
  end

  @doc """
  Disconnects an account.
  """
  @spec delete(Client.t(), String.t()) :: {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete(client, id) do
    with {:ok, data} <- Client.request(client, :delete, path(id)) do
      {:ok, Message.from_map(data)}
    end
  end

  @doc """
  Makes this the account that leads its platform in the workspace.
  """
  @spec set_primary(Client.t(), String.t()) :: {:ok, Account.t()} | {:error, FoPost.Error.t()}
  def set_primary(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id) <> "/primary") do
      {:ok, Account.from_map(data)}
    end
  end

  @doc """
  Checks an account's stored credentials against the platform.
  """
  @spec validate(Client.t(), String.t()) ::
          {:ok, ValidationResult.t()} | {:error, FoPost.Error.t()}
  def validate(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id) <> "/validate") do
      {:ok, ValidationResult.from_map(data)}
    end
  end

  @doc """
  One account's health.

  Pass `refresh: true` to check it live rather than reading the last stored result.
  """
  @spec health(Client.t(), String.t(), keyword()) ::
          {:ok, AccountHealth.t()} | {:error, FoPost.Error.t()}
  def health(client, id, opts \\ []) do
    params = Model.take_params(opts, [:refresh])

    with {:ok, data} <- Client.request(client, :get, path(id) <> "/health", params: params) do
      {:ok, AccountHealth.from_map(data)}
    end
  end

  @doc """
  Every reachable account's health, optionally narrowed with `:workspace_id`.
  """
  @spec health_summary(Client.t(), keyword()) ::
          {:ok, HealthSummary.t()} | {:error, FoPost.Error.t()}
  def health_summary(client, opts \\ []) do
    params = Model.take_params(opts, [{:workspace_id, "workspaceId"}])

    with {:ok, data} <- Client.request(client, :get, "/accounts/health", params: params) do
      {:ok, HealthSummary.from_map(data)}
    end
  end

  @doc """
  Renews an account's OAuth token ahead of its expiry.
  """
  @spec refresh_token(Client.t(), String.t()) ::
          {:ok, FoPost.TokenRefresh.t()} | {:error, FoPost.Error.t()}
  def refresh_token(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id) <> "/refresh-token") do
      {:ok, FoPost.TokenRefresh.from_map(data)}
    end
  end

  @doc """
  An account's stored follower snapshots, newest first.

  `:limit` caps how many come back; leaving it out keeps the API's own default.
  """
  @spec analytics(Client.t(), String.t(), keyword()) ::
          {:ok, AccountAnalytics.t()} | {:error, FoPost.Error.t()}
  def analytics(client, id, opts \\ []) do
    params = Model.take_params(opts, [:limit])
    url_path = path(id) <> "/analytics"

    with {:ok, data} <- Client.request(client, :get, url_path, params: params) do
      {:ok, AccountAnalytics.from_map(data)}
    end
  end

  @doc """
  Mints a one-time code, valid for 15 minutes. Sending `/connect <code>` to the bot in a
  chat connects that chat.

  `:workspace_id` may be left out for a key bound to one workspace.
  """
  @spec create_telegram_connect_code(Client.t(), keyword()) ::
          {:ok, TelegramConnectCode.t()} | {:error, FoPost.Error.t()}
  def create_telegram_connect_code(client, opts \\ []) do
    body = Model.take_body(opts, [{:workspace_id, "workspaceId"}])

    with {:ok, data} <-
           Client.request(client, :post, "/accounts/telegram/connect-code", json: body) do
      {:ok, TelegramConnectCode.from_map(data)}
    end
  end

  @doc """
  Where a Telegram connect code stands: `"pending"`, `"connected"`, `"failed"`, or
  `"expired"`.
  """
  @spec telegram_connect_status(Client.t(), String.t()) ::
          {:ok, TelegramConnectStatus.t()} | {:error, FoPost.Error.t()}
  def telegram_connect_status(client, code) do
    url_path = "/accounts/telegram/connect-code/status"

    with {:ok, data} <- Client.request(client, :get, url_path, params: %{"code" => code}) do
      {:ok, TelegramConnectStatus.from_map(data)}
    end
  end

  @doc """
  The command menu the bot shows in a connected Telegram chat.
  """
  @spec telegram_bot_commands(Client.t(), String.t()) ::
          {:ok, [TelegramBotCommand.t()]} | {:error, FoPost.Error.t()}
  def telegram_bot_commands(client, id) do
    with {:ok, data} <- Client.request(client, :get, commands_path(id)) do
      {:ok, commands(data)}
    end
  end

  @doc """
  Replaces the command menu for a connected Telegram chat.

  `commands` is a list of 1-100 maps (or `FoPost.TelegramBotCommand` structs) with
  `:command` and `:description`.
  """
  @spec set_telegram_bot_commands(Client.t(), String.t(), [map()]) ::
          {:ok, [TelegramBotCommand.t()]} | {:error, FoPost.Error.t()}
  def set_telegram_bot_commands(client, id, commands) do
    body = %{"commands" => Enum.map(commands, &command_body/1)}

    with {:ok, data} <- Client.request(client, :put, commands_path(id), json: body) do
      {:ok, commands(data)}
    end
  end

  @doc """
  Clears the command menu for a connected Telegram chat.
  """
  @spec delete_telegram_bot_commands(Client.t(), String.t()) ::
          {:ok, [TelegramBotCommand.t()]} | {:error, FoPost.Error.t()}
  def delete_telegram_bot_commands(client, id) do
    with {:ok, data} <- Client.request(client, :delete, commands_path(id)) do
      {:ok, commands(data)}
    end
  end

  @doc """
  Channels the Slack app can post to: every public channel, and private ones the app was
  invited to. A 409 whose `code` is `"webhook_connection"` means the account posts through
  a webhook.
  """
  @spec slack_channels(Client.t(), String.t()) ::
          {:ok, [SlackChannel.t()]} | {:error, FoPost.Error.t()}
  def slack_channels(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id) <> "/slack/channels") do
      {:ok, Model.list(SlackChannel, data)}
    end
  end

  @doc """
  People in the connected Slack workspace, for addressing a DM.
  """
  @spec slack_members(Client.t(), String.t()) ::
          {:ok, [SlackMember.t()]} | {:error, FoPost.Error.t()}
  def slack_members(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id) <> "/slack/members") do
      {:ok, Model.list(SlackMember, data)}
    end
  end

  @doc """
  The name and icon a Slack account posts under.
  """
  @spec slack_identity(Client.t(), String.t()) ::
          {:ok, SlackIdentity.t()} | {:error, FoPost.Error.t()}
  def slack_identity(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id) <> "/slack/identity") do
      {:ok, SlackIdentity.from_map(data)}
    end
  end

  @doc """
  Sets the name and icon a Slack account posts under.

  Options: `:username` (1-80 characters), `:icon_url` (an http(s) URL), and `:icon_emoji`
  (such as `":rocket:"`). A key left out keeps its value and `nil` clears it. Set
  `:icon_url` or `:icon_emoji`, not both; setting one clears the other.
  """
  @spec update_slack_identity(Client.t(), String.t(), keyword()) ::
          {:ok, SlackIdentity.t()} | {:error, FoPost.Error.t()}
  def update_slack_identity(client, id, opts) do
    body = Model.take_body(opts, [:username, :icon_url, :icon_emoji])

    with {:ok, data} <-
           Client.request(client, :patch, path(id) <> "/slack/identity", json: body) do
      {:ok, SlackIdentity.from_map(data)}
    end
  end

  @doc """
  Text channels the bot can post to in the connected Discord server.

  A 409 whose `code` is `"webhook_connection"` means the account posts through a webhook;
  upgrade it to the bot first. The same applies to every other Discord function here.
  """
  @spec discord_channels(Client.t(), String.t()) ::
          {:ok, [DiscordChannel.t()]} | {:error, FoPost.Error.t()}
  def discord_channels(client, id) do
    with {:ok, data} <- Client.request(client, :get, discord(id, "/channels")) do
      {:ok, Model.list(DiscordChannel, data)}
    end
  end

  @doc """
  Moves the account to another channel in the same server.
  """
  @spec switch_discord_channel(Client.t(), String.t(), String.t()) ::
          {:ok, DiscordChannel.t()} | {:error, FoPost.Error.t()}
  def switch_discord_channel(client, id, channel_id) do
    body = %{"channel_id" => channel_id}

    with {:ok, data} <-
           Client.request(client, :patch, discord(id, "/channels/current"), json: body) do
      {:ok, DiscordChannel.from_map(data)}
    end
  end

  @doc """
  The nickname and avatar the bot wears in the server.
  """
  @spec discord_identity(Client.t(), String.t()) ::
          {:ok, DiscordIdentity.t()} | {:error, FoPost.Error.t()}
  def discord_identity(client, id) do
    with {:ok, data} <- Client.request(client, :get, discord(id, "/identity")) do
      {:ok, DiscordIdentity.from_map(data)}
    end
  end

  @doc """
  Sets the nickname and avatar the bot wears in the server.

  Options: `:username` (1-32 characters) and `:avatar_url` (an http(s) URL). A key left
  out keeps its value and `nil` clears it.
  """
  @spec update_discord_identity(Client.t(), String.t(), keyword()) ::
          {:ok, DiscordIdentity.t()} | {:error, FoPost.Error.t()}
  def update_discord_identity(client, id, opts) do
    body = Model.take_body(opts, [:username, :avatar_url])

    with {:ok, data} <- Client.request(client, :patch, discord(id, "/identity"), json: body) do
      {:ok, DiscordIdentity.from_map(data)}
    end
  end

  @doc """
  Pinned messages in the account's channel.
  """
  @spec discord_pins(Client.t(), String.t()) ::
          {:ok, [DiscordMessage.t()]} | {:error, FoPost.Error.t()}
  def discord_pins(client, id) do
    with {:ok, data} <- Client.request(client, :get, discord(id, "/messages/pinned")) do
      {:ok, Model.list(DiscordMessage, data)}
    end
  end

  @doc "Removes a message from the account's channel."
  @spec delete_discord_message(Client.t(), String.t(), String.t()) ::
          {:ok, DiscordAck.t()} | {:error, FoPost.Error.t()}
  def delete_discord_message(client, id, message_id) do
    ack(client, :delete, discord(id, "/messages/" <> encode(message_id)))
  end

  @doc "Pins a message in the account's channel."
  @spec pin_discord_message(Client.t(), String.t(), String.t()) ::
          {:ok, DiscordAck.t()} | {:error, FoPost.Error.t()}
  def pin_discord_message(client, id, message_id) do
    ack(client, :post, discord(id, "/messages/" <> encode(message_id) <> "/pin"))
  end

  @doc "Unpins a message in the account's channel."
  @spec unpin_discord_message(Client.t(), String.t(), String.t()) ::
          {:ok, DiscordAck.t()} | {:error, FoPost.Error.t()}
  def unpin_discord_message(client, id, message_id) do
    ack(client, :delete, discord(id, "/messages/" <> encode(message_id) <> "/pin"))
  end

  @doc """
  Publishes an announcement-channel message to every server following the channel.
  """
  @spec crosspost_discord_message(Client.t(), String.t(), String.t()) ::
          {:ok, DiscordMessageRef.t()} | {:error, FoPost.Error.t()}
  def crosspost_discord_message(client, id, message_id) do
    path = discord(id, "/messages/" <> encode(message_id) <> "/crosspost")

    with {:ok, data} <- Client.request(client, :post, path) do
      {:ok, DiscordMessageRef.from_map(data)}
    end
  end

  @doc """
  Starts a thread on a message.

  Options: `:name` (required) and `:auto_archive_duration` — 60, 1440, 4320 or 10080
  minutes.
  """
  @spec create_discord_thread(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, DiscordThread.t()} | {:error, FoPost.Error.t()}
  def create_discord_thread(client, id, message_id, opts) do
    body = Model.take_body(opts, [:name, :auto_archive_duration])
    path = discord(id, "/messages/" <> encode(message_id) <> "/thread")

    with {:ok, data} <- Client.request(client, :post, path, json: body) do
      {:ok, DiscordThread.from_map(data)}
    end
  end

  @doc """
  Sends one message to a member of the server.
  """
  @spec send_discord_direct_message(Client.t(), String.t(), String.t(), String.t()) ::
          {:ok, DiscordMessageRef.t()} | {:error, FoPost.Error.t()}
  def send_discord_direct_message(client, id, member_id, content) do
    body = %{"member_id" => member_id, "content" => content}

    with {:ok, data} <- Client.request(client, :post, discord(id, "/dm"), json: body) do
      {:ok, DiscordMessageRef.from_map(data)}
    end
  end

  @doc "The server's scheduled events."
  @spec discord_events(Client.t(), String.t()) ::
          {:ok, [DiscordScheduledEvent.t()]} | {:error, FoPost.Error.t()}
  def discord_events(client, id) do
    with {:ok, data} <- Client.request(client, :get, discord(id, "/events")) do
      {:ok, Model.list(DiscordScheduledEvent, data)}
    end
  end

  @doc "One scheduled event."
  @spec discord_event(Client.t(), String.t(), String.t()) ::
          {:ok, DiscordScheduledEvent.t()} | {:error, FoPost.Error.t()}
  def discord_event(client, id, event_id) do
    with {:ok, data} <- Client.request(client, :get, discord(id, "/events/" <> encode(event_id))) do
      {:ok, DiscordScheduledEvent.from_map(data)}
    end
  end

  @doc """
  Adds an event to the server's calendar.

  Options: `:name`, `:start_time`, `:end_time`, `:description`, `:channel_id` and
  `:location`. Give a `:channel_id` (a voice or stage channel), or a `:location` with an
  `:end_time`.
  """
  @spec create_discord_event(Client.t(), String.t(), keyword()) ::
          {:ok, DiscordScheduledEvent.t()} | {:error, FoPost.Error.t()}
  def create_discord_event(client, id, opts) do
    with {:ok, data} <-
           Client.request(client, :post, discord(id, "/events"), json: event_body(opts)) do
      {:ok, DiscordScheduledEvent.from_map(data)}
    end
  end

  @doc """
  Changes a scheduled event. A key left out is left as it is; `:status` is `"scheduled"`,
  `"active"`, `"completed"` or `"canceled"`.
  """
  @spec update_discord_event(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, DiscordScheduledEvent.t()} | {:error, FoPost.Error.t()}
  def update_discord_event(client, id, event_id, opts) do
    path = discord(id, "/events/" <> encode(event_id))

    with {:ok, data} <- Client.request(client, :patch, path, json: event_body(opts)) do
      {:ok, DiscordScheduledEvent.from_map(data)}
    end
  end

  @doc "Removes a scheduled event."
  @spec delete_discord_event(Client.t(), String.t(), String.t()) ::
          {:ok, DiscordAck.t()} | {:error, FoPost.Error.t()}
  def delete_discord_event(client, id, event_id) do
    ack(client, :delete, discord(id, "/events/" <> encode(event_id)))
  end

  @doc """
  The server's roster, or the members matching `:q` by name prefix. Options: `:q` and
  `:limit`.
  """
  @spec discord_members(Client.t(), String.t(), keyword()) ::
          {:ok, [DiscordMember.t()]} | {:error, FoPost.Error.t()}
  def discord_members(client, id, opts \\ []) do
    params = Keyword.take(opts, [:q, :limit])

    with {:ok, data} <- Client.request(client, :get, discord(id, "/members"), params: params) do
      {:ok, Model.list(DiscordMember, data)}
    end
  end

  @doc "One member of the server."
  @spec discord_member(Client.t(), String.t(), String.t()) ::
          {:ok, DiscordMember.t()} | {:error, FoPost.Error.t()}
  def discord_member(client, id, member_id) do
    path = discord(id, "/members/" <> encode(member_id))

    with {:ok, data} <- Client.request(client, :get, path) do
      {:ok, DiscordMember.from_map(data)}
    end
  end

  @doc "The server's roles, highest first."
  @spec discord_roles(Client.t(), String.t()) ::
          {:ok, [DiscordRole.t()]} | {:error, FoPost.Error.t()}
  def discord_roles(client, id) do
    with {:ok, data} <- Client.request(client, :get, discord(id, "/roles")) do
      {:ok, Model.list(DiscordRole, data)}
    end
  end

  @doc """
  Adds a role to the server. Options: `:name`, `:color`, `:hoist`, `:mentionable` and
  `:permissions`.
  """
  @spec create_discord_role(Client.t(), String.t(), keyword()) ::
          {:ok, DiscordRole.t()} | {:error, FoPost.Error.t()}
  def create_discord_role(client, id, opts) do
    with {:ok, data} <-
           Client.request(client, :post, discord(id, "/roles"), json: role_body(opts)) do
      {:ok, DiscordRole.from_map(data)}
    end
  end

  @doc "Changes a role on the server; a key left out is left as it is."
  @spec update_discord_role(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, DiscordRole.t()} | {:error, FoPost.Error.t()}
  def update_discord_role(client, id, role_id, opts) do
    path = discord(id, "/roles/" <> encode(role_id))

    with {:ok, data} <- Client.request(client, :patch, path, json: role_body(opts)) do
      {:ok, DiscordRole.from_map(data)}
    end
  end

  @doc "Removes a role from the server."
  @spec delete_discord_role(Client.t(), String.t(), String.t()) ::
          {:ok, DiscordAck.t()} | {:error, FoPost.Error.t()}
  def delete_discord_role(client, id, role_id) do
    ack(client, :delete, discord(id, "/roles/" <> encode(role_id)))
  end

  @doc "Gives a member a role."
  @spec add_discord_member_role(Client.t(), String.t(), String.t(), String.t()) ::
          {:ok, DiscordAck.t()} | {:error, FoPost.Error.t()}
  def add_discord_member_role(client, id, role_id, member_id) do
    ack(client, :put, member_role(id, role_id, member_id))
  end

  @doc "Takes a role from a member."
  @spec remove_discord_member_role(Client.t(), String.t(), String.t(), String.t()) ::
          {:ok, DiscordAck.t()} | {:error, FoPost.Error.t()}
  def remove_discord_member_role(client, id, role_id, member_id) do
    ack(client, :delete, member_role(id, role_id, member_id))
  end

  @doc "Same as `list/2`, but raises `FoPost.Error`."
  def list!(client, opts \\ []), do: Result.unwrap!(list(client, opts))

  @doc "Same as `get/2`, but raises `FoPost.Error`."
  def get!(client, id), do: Result.unwrap!(get(client, id))

  @doc "Same as `create/2`, but raises `FoPost.Error`."
  def create!(client, opts), do: Result.unwrap!(create(client, opts))

  @doc "Same as `rename/3`, but raises `FoPost.Error`."
  def rename!(client, id, display_name), do: Result.unwrap!(rename(client, id, display_name))

  @doc "Same as `move/3`, but raises `FoPost.Error`."
  def move!(client, id, workspace_id), do: Result.unwrap!(move(client, id, workspace_id))

  @doc "Same as `delete/2`, but raises `FoPost.Error`."
  def delete!(client, id), do: Result.unwrap!(delete(client, id))

  @doc "Same as `set_primary/2`, but raises `FoPost.Error`."
  def set_primary!(client, id), do: Result.unwrap!(set_primary(client, id))

  @doc "Same as `validate/2`, but raises `FoPost.Error`."
  def validate!(client, id), do: Result.unwrap!(validate(client, id))

  @doc "Same as `health/3`, but raises `FoPost.Error`."
  def health!(client, id, opts \\ []), do: Result.unwrap!(health(client, id, opts))

  @doc "Same as `health_summary/2`, but raises `FoPost.Error`."
  def health_summary!(client, opts \\ []), do: Result.unwrap!(health_summary(client, opts))

  @doc "Same as `refresh_token/2`, but raises `FoPost.Error`."
  def refresh_token!(client, id), do: Result.unwrap!(refresh_token(client, id))

  @doc "Same as `analytics/3`, but raises `FoPost.Error`."
  def analytics!(client, id, opts \\ []), do: Result.unwrap!(analytics(client, id, opts))

  @doc "Same as `create_telegram_connect_code/2`, but raises `FoPost.Error`."
  def create_telegram_connect_code!(client, opts \\ []),
    do: Result.unwrap!(create_telegram_connect_code(client, opts))

  @doc "Same as `telegram_connect_status/2`, but raises `FoPost.Error`."
  def telegram_connect_status!(client, code),
    do: Result.unwrap!(telegram_connect_status(client, code))

  @doc "Same as `telegram_bot_commands/2`, but raises `FoPost.Error`."
  def telegram_bot_commands!(client, id), do: Result.unwrap!(telegram_bot_commands(client, id))

  @doc "Same as `set_telegram_bot_commands/3`, but raises `FoPost.Error`."
  def set_telegram_bot_commands!(client, id, commands),
    do: Result.unwrap!(set_telegram_bot_commands(client, id, commands))

  @doc "Same as `delete_telegram_bot_commands/2`, but raises `FoPost.Error`."
  def delete_telegram_bot_commands!(client, id),
    do: Result.unwrap!(delete_telegram_bot_commands(client, id))

  @doc "Same as `slack_channels/2`, but raises `FoPost.Error`."
  def slack_channels!(client, id), do: Result.unwrap!(slack_channels(client, id))

  @doc "Same as `slack_members/2`, but raises `FoPost.Error`."
  def slack_members!(client, id), do: Result.unwrap!(slack_members(client, id))

  @doc "Same as `slack_identity/2`, but raises `FoPost.Error`."
  def slack_identity!(client, id), do: Result.unwrap!(slack_identity(client, id))

  @doc "Same as `update_slack_identity/3`, but raises `FoPost.Error`."
  def update_slack_identity!(client, id, opts),
    do: Result.unwrap!(update_slack_identity(client, id, opts))

  defp commands_path(id), do: path(id) <> "/telegram/commands"

  defp commands(data), do: Model.list(TelegramBotCommand, Model.normalize(data)["commands"])

  defp command_body(command) do
    %{
      "command" => Map.get(command, :command, Map.get(command, "command")),
      "description" => Map.get(command, :description, Map.get(command, "description"))
    }
  end

  @doc "Same as `discord_channels/2`, but raises `FoPost.Error`."
  def discord_channels!(client, id), do: Result.unwrap!(discord_channels(client, id))

  @doc "Same as `switch_discord_channel/3`, but raises `FoPost.Error`."
  def switch_discord_channel!(client, id, channel_id),
    do: Result.unwrap!(switch_discord_channel(client, id, channel_id))

  @doc "Same as `discord_identity/2`, but raises `FoPost.Error`."
  def discord_identity!(client, id), do: Result.unwrap!(discord_identity(client, id))

  @doc "Same as `update_discord_identity/3`, but raises `FoPost.Error`."
  def update_discord_identity!(client, id, opts),
    do: Result.unwrap!(update_discord_identity(client, id, opts))

  @doc "Same as `discord_events/2`, but raises `FoPost.Error`."
  def discord_events!(client, id), do: Result.unwrap!(discord_events(client, id))

  @doc "Same as `create_discord_event/3`, but raises `FoPost.Error`."
  def create_discord_event!(client, id, opts),
    do: Result.unwrap!(create_discord_event(client, id, opts))

  @doc "Same as `discord_members/3`, but raises `FoPost.Error`."
  def discord_members!(client, id, opts \\ []),
    do: Result.unwrap!(discord_members(client, id, opts))

  @doc "Same as `discord_roles/2`, but raises `FoPost.Error`."
  def discord_roles!(client, id), do: Result.unwrap!(discord_roles(client, id))

  @doc "Same as `send_discord_direct_message/4`, but raises `FoPost.Error`."
  def send_discord_direct_message!(client, id, member_id, content),
    do: Result.unwrap!(send_discord_direct_message(client, id, member_id, content))

  defp discord(id, suffix), do: path(id) <> "/discord" <> suffix

  defp member_role(id, role_id, member_id),
    do: discord(id, "/roles/" <> encode(role_id) <> "/members/" <> encode(member_id))

  defp encode(value), do: URI.encode(to_string(value), &URI.char_unreserved?/1)

  defp ack(client, method, path) do
    with {:ok, data} <- Client.request(client, method, path) do
      {:ok, DiscordAck.from_map(data)}
    end
  end

  # Only the keys the caller named go out, so Discord keeps the rest.
  defp event_body(opts) do
    Model.take_body(opts, [
      :name,
      :description,
      :start_time,
      :end_time,
      :channel_id,
      :location,
      :status
    ])
  end

  defp role_body(opts) do
    Model.take_body(opts, [:name, :color, :hoist, :mentionable, :permissions])
  end

  defp path(id), do: "/accounts/" <> URI.encode(to_string(id), &URI.char_unreserved?/1)
end
