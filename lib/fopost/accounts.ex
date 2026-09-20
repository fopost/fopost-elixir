defmodule FoPost.Accounts do
  @moduledoc """
  Connected social accounts — what a post is actually delivered to.

  Accounts on platforms that use OAuth are connected in the FoPost dashboard; `create/2`
  is for the platforms where you already hold the credentials.
  """

  alias FoPost.Account
  alias FoPost.AccountAnalytics
  alias FoPost.AccountHealth
  alias FoPost.AccountPlatformMetrics
  alias FoPost.BlueskyLanguages
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
  alias FoPost.InstagramAudio
  alias FoPost.InstagramPublishingLimit
  alias FoPost.InstagramStory
  alias FoPost.InstagramStoryInsights
  alias FoPost.LinkedInMention
  alias FoPost.Message
  alias FoPost.MetaGreetingText
  alias FoPost.MetaIceBreaker
  alias FoPost.MetaPersistentMenuEntry
  alias FoPost.Model
  alias FoPost.PinterestBoard
  alias FoPost.Result
  alias FoPost.SlackChannel
  alias FoPost.SlackIdentity
  alias FoPost.SlackMember
  alias FoPost.TelegramBotCommand
  alias FoPost.TelegramConnectCode
  alias FoPost.TelegramConnectStatus
  alias FoPost.TikTokCreatorInfo
  alias FoPost.TikTokMusic
  alias FoPost.TikTokPlace
  alias FoPost.TikTokVideoSource
  alias FoPost.ValidationResult
  alias FoPost.WebhookSubscription
  alias FoPost.YouTubeCaptionTrack
  alias FoPost.YouTubePlaylist
  alias FoPost.YouTubeTranscript

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
  The numbers only this account's network reports, in its own vocabulary: ad-break
  earnings, story taps, a retention curve, the search terms behind a listing.

  Keyed by the platform's own metric names, read from the newest collected snapshot
  rather than fetched live. Needs the `analytics` scope. A network whose metric access
  has not been granted yet answers `503` (`platform_metrics_unavailable`) rather than an
  empty set.
  """
  @spec platform_metrics(Client.t(), String.t()) ::
          {:ok, AccountPlatformMetrics.t()} | {:error, FoPost.Error.t()}
  def platform_metrics(client, id) do
    with {:ok, data} <-
           Client.request(client, :get, path(id) <> "/insights", params: [{"raw", "true"}]) do
      {:ok, AccountPlatformMetrics.from_map(data)}
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
  The prompts Messenger or Instagram shows before the first message.

  A network without ice breakers answers `400`.
  """
  @spec ice_breakers(Client.t(), String.t()) ::
          {:ok, [MetaIceBreaker.t()]} | {:error, FoPost.Error.t()}
  def ice_breakers(client, id) do
    with {:ok, data} <- Client.request(client, :get, messaging_path(id, "ice-breakers")) do
      {:ok, ice_breaker_list(data)}
    end
  end

  @doc """
  Replaces the ice breakers, up to four.

  `ice_breakers` is a list of maps (or `FoPost.MetaIceBreaker` structs) with `:question`
  and `:payload`.
  """
  @spec set_ice_breakers(Client.t(), String.t(), [map()]) ::
          {:ok, [MetaIceBreaker.t()]} | {:error, FoPost.Error.t()}
  def set_ice_breakers(client, id, ice_breakers) do
    body = %{"ice_breakers" => Enum.map(ice_breakers, &ice_breaker_body/1)}

    with {:ok, data} <-
           Client.request(client, :put, messaging_path(id, "ice-breakers"), json: body) do
      {:ok, ice_breaker_list(data)}
    end
  end

  @doc "Clears the ice breakers."
  @spec delete_ice_breakers(Client.t(), String.t()) ::
          {:ok, [MetaIceBreaker.t()]} | {:error, FoPost.Error.t()}
  def delete_ice_breakers(client, id) do
    with {:ok, data} <- Client.request(client, :delete, messaging_path(id, "ice-breakers")) do
      {:ok, ice_breaker_list(data)}
    end
  end

  @doc """
  The always-visible Messenger menu. Facebook Pages only; other networks answer `400`.
  """
  @spec persistent_menu(Client.t(), String.t()) ::
          {:ok, [MetaPersistentMenuEntry.t()]} | {:error, FoPost.Error.t()}
  def persistent_menu(client, id) do
    with {:ok, data} <- Client.request(client, :get, messaging_path(id, "persistent-menu")) do
      {:ok, menu_list(data)}
    end
  end

  @doc """
  Replaces the menu, one entry per locale, up to three items each.

  Each entry is a map with `:locale` and `:call_to_actions`; each item is a map with
  `:type` (`"postback"` or `"web_url"`), `:title`, and either `:payload` or `:url`.
  """
  @spec set_persistent_menu(Client.t(), String.t(), [map()]) ::
          {:ok, [MetaPersistentMenuEntry.t()]} | {:error, FoPost.Error.t()}
  def set_persistent_menu(client, id, menu) do
    body = %{"persistent_menu" => Enum.map(menu, &menu_entry_body/1)}

    with {:ok, data} <-
           Client.request(client, :put, messaging_path(id, "persistent-menu"), json: body) do
      {:ok, menu_list(data)}
    end
  end

  @doc "Clears the menu."
  @spec delete_persistent_menu(Client.t(), String.t()) ::
          {:ok, [MetaPersistentMenuEntry.t()]} | {:error, FoPost.Error.t()}
  def delete_persistent_menu(client, id) do
    with {:ok, data} <- Client.request(client, :delete, messaging_path(id, "persistent-menu")) do
      {:ok, menu_list(data)}
    end
  end

  @doc """
  The text shown before a Messenger conversation starts. Facebook Pages only.
  """
  @spec greeting(Client.t(), String.t()) ::
          {:ok, [MetaGreetingText.t()]} | {:error, FoPost.Error.t()}
  def greeting(client, id) do
    with {:ok, data} <- Client.request(client, :get, messaging_path(id, "greeting")) do
      {:ok, greeting_list(data)}
    end
  end

  @doc """
  Replaces the greeting, one entry per locale, each up to 160 characters.

  Each entry is a map with `:text` and an optional `:locale`, which defaults to
  `"default"`.
  """
  @spec set_greeting(Client.t(), String.t(), [map()]) ::
          {:ok, [MetaGreetingText.t()]} | {:error, FoPost.Error.t()}
  def set_greeting(client, id, greeting) do
    body = %{"greeting" => Enum.map(greeting, &greeting_body/1)}

    with {:ok, data} <- Client.request(client, :put, messaging_path(id, "greeting"), json: body) do
      {:ok, greeting_list(data)}
    end
  end

  @doc "Clears the greeting."
  @spec delete_greeting(Client.t(), String.t()) ::
          {:ok, [MetaGreetingText.t()]} | {:error, FoPost.Error.t()}
  def delete_greeting(client, id) do
    with {:ok, data} <- Client.request(client, :delete, messaging_path(id, "greeting")) do
      {:ok, greeting_list(data)}
    end
  end

  @doc """
  What the network is delivering to the FoPost webhook for this account.
  """
  @spec webhook_subscription(Client.t(), String.t()) ::
          {:ok, WebhookSubscription.t()} | {:error, FoPost.Error.t()}
  def webhook_subscription(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id) <> "/webhook-subscription") do
      {:ok, WebhookSubscription.from_map(data)}
    end
  end

  @doc "Subscribes to every field this account needs, lapsed or not."
  @spec resubscribe_webhook(Client.t(), String.t()) ::
          {:ok, WebhookSubscription.t()} | {:error, FoPost.Error.t()}
  def resubscribe_webhook(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id) <> "/webhook-subscription") do
      {:ok, WebhookSubscription.from_map(data)}
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

  @doc """
  Boards this Pinterest connection can pin to.
  """
  @spec pinterest_boards(Client.t(), String.t()) ::
          {:ok, [PinterestBoard.t()]} | {:error, FoPost.Error.t()}
  def pinterest_boards(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id) <> "/pinterest/boards") do
      {:ok, Model.list(PinterestBoard, data)}
    end
  end

  @doc """
  Creates a board on the connected Pinterest account.

  Options: `:name` (required), `:description`, and `:privacy`, which is `"PUBLIC"`,
  `"PROTECTED"` or `"SECRET"` and defaults to public.
  """
  @spec create_pinterest_board(Client.t(), String.t(), keyword()) ::
          {:ok, PinterestBoard.t()} | {:error, FoPost.Error.t()}
  def create_pinterest_board(client, id, opts) do
    body = Model.take_body(opts, [:name, :description, :privacy])

    with {:ok, data} <-
           Client.request(client, :post, path(id) <> "/pinterest/boards", json: body) do
      {:ok, PinterestBoard.from_map(data)}
    end
  end

  @doc """
  The channel's own playlists, with the stored default marked.
  """
  @spec youtube_playlists(Client.t(), String.t()) ::
          {:ok, [YouTubePlaylist.t()]} | {:error, FoPost.Error.t()}
  def youtube_playlists(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id) <> "/youtube/playlists") do
      {:ok, Model.list(YouTubePlaylist, data)}
    end
  end

  @doc """
  Creates a playlist on the connected channel.

  Options: `:title` (required), `:description`, and `:privacy`, which is `"public"`,
  `"unlisted"` or `"private"` and defaults to private.
  """
  @spec create_youtube_playlist(Client.t(), String.t(), keyword()) ::
          {:ok, YouTubePlaylist.t()} | {:error, FoPost.Error.t()}
  def create_youtube_playlist(client, id, opts) do
    body = Model.take_body(opts, [:title, :description, :privacy])

    with {:ok, data} <-
           Client.request(client, :post, path(id) <> "/youtube/playlists", json: body) do
      {:ok, YouTubePlaylist.from_map(data)}
    end
  end

  @doc """
  The playlist a new video joins when the post picks none. A `nil` `playlist_id` clears
  it; the stored value comes back.
  """
  @spec set_default_youtube_playlist(Client.t(), String.t(), String.t() | nil) ::
          {:ok, String.t() | nil} | {:error, FoPost.Error.t()}
  def set_default_youtube_playlist(client, id, playlist_id) do
    body = %{"playlist_id" => playlist_id}

    with {:ok, data} <-
           Client.request(client, :put, path(id) <> "/youtube/playlists/default", json: body) do
      {:ok, Model.normalize(data)["playlist_id"]}
    end
  end

  @doc """
  Caption tracks on one of the channel's videos.
  """
  @spec youtube_captions(Client.t(), String.t(), String.t()) ::
          {:ok, [YouTubeCaptionTrack.t()]} | {:error, FoPost.Error.t()}
  def youtube_captions(client, id, video_id) do
    with {:ok, data} <-
           Client.request(client, :get, path(id) <> "/youtube/videos/#{video_id}/captions") do
      {:ok, Model.list(YouTubeCaptionTrack, data)}
    end
  end

  @doc """
  Uploads a caption track.

  Options: `:language` (a BCP-47 tag) and `:body` (the subtitle file itself) are required;
  `:name` and `:is_draft` are optional. YouTube reads SRT and WebVTT and works out which
  from the bytes, so the format is not declared.
  """
  @spec upload_youtube_captions(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, YouTubeCaptionTrack.t()} | {:error, FoPost.Error.t()}
  def upload_youtube_captions(client, id, video_id, opts) do
    body = Model.take_body(opts, [:language, :body, :name, :is_draft])

    with {:ok, data} <-
           Client.request(client, :post, path(id) <> "/youtube/videos/#{video_id}/captions",
             json: body
           ) do
      {:ok, YouTubeCaptionTrack.from_map(data)}
    end
  end

  @doc """
  One caption track read back as text.
  """
  @spec youtube_transcript(Client.t(), String.t(), String.t()) ::
          {:ok, YouTubeTranscript.t()} | {:error, FoPost.Error.t()}
  def youtube_transcript(client, id, caption_id) do
    with {:ok, data} <-
           Client.request(client, :get, path(id) <> "/youtube/captions/#{caption_id}") do
      {:ok, YouTubeTranscript.from_map(data)}
    end
  end

  @doc """
  What a post from this Bluesky connection is written in when the post does not say.
  """
  @spec bluesky_languages(Client.t(), String.t()) ::
          {:ok, BlueskyLanguages.t()} | {:error, FoPost.Error.t()}
  def bluesky_languages(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id) <> "/bluesky/languages") do
      {:ok, BlueskyLanguages.from_map(data)}
    end
  end

  @doc """
  Stores up to three BCP-47 tags. An empty list clears the default.
  """
  @spec set_bluesky_languages(Client.t(), String.t(), [String.t()]) ::
          {:ok, BlueskyLanguages.t()} | {:error, FoPost.Error.t()}
  def set_bluesky_languages(client, id, languages) when is_list(languages) do
    with {:ok, data} <-
           Client.request(client, :put, path(id) <> "/bluesky/languages",
             json: %{"languages" => languages}
           ) do
      {:ok, BlueskyLanguages.from_map(data)}
    end
  end

  @doc """
  The switches TikTok enforces at publish time, which are changed in the TikTok app.
  """
  @spec tiktok_creator_info(Client.t(), String.t()) ::
          {:ok, TikTokCreatorInfo.t()} | {:error, FoPost.Error.t()}
  def tiktok_creator_info(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id) <> "/tiktok/creator-info") do
      {:ok, TikTokCreatorInfo.from_map(data)}
    end
  end

  @doc """
  TikTok's Commercial Music Library. `:limit` is 1 to 50 and defaults to 20.

  Needs the Marketing API product on the TikTok app; without it the call answers a 403
  naming what to enable rather than an empty list.
  """
  @spec tiktok_music(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, [TikTokMusic.t()]} | {:error, FoPost.Error.t()}
  def tiktok_music(client, id, query, opts \\ []) do
    params = Keyword.put(Model.take_params(opts, [:limit]) |> Enum.to_list(), :q, query)

    with {:ok, data} <-
           Client.request(client, :get, path(id) <> "/tiktok/music", params: params) do
      {:ok, Model.list(TikTokMusic, data)}
    end
  end

  @doc """
  Places a post can be tagged with. Same TikTok product as the music library.
  """
  @spec tiktok_locations(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, [TikTokPlace.t()]} | {:error, FoPost.Error.t()}
  def tiktok_locations(client, id, query, opts \\ []) do
    params = Keyword.put(Model.take_params(opts, [:limit]) |> Enum.to_list(), :q, query)

    with {:ok, data} <-
           Client.request(client, :get, path(id) <> "/tiktok/locations", params: params) do
      {:ok, Model.list(TikTokPlace, data)}
    end
  end

  @doc """
  Resolves a share link to one of this account's own videos, for repurposing. A link to
  someone else's video answers 404.
  """
  @spec tiktok_video_lookup(Client.t(), String.t(), String.t()) ::
          {:ok, TikTokVideoSource.t()} | {:error, FoPost.Error.t()}
  def tiktok_video_lookup(client, id, url) do
    body = %{"url" => url}

    with {:ok, data} <-
           Client.request(client, :post, path(id) <> "/tiktok/video-download", json: body) do
      {:ok, TikTokVideoSource.from_map(data)}
    end
  end

  @doc """
  Tracks a Reel can carry. Options: `:q` and `:audio_type` (`"music"`, the default, or
  `"original_sound"`). With no `:q` Instagram answers with what is trending.
  """
  @spec instagram_audio(Client.t(), String.t(), keyword()) ::
          {:ok, [InstagramAudio.t()]} | {:error, FoPost.Error.t()}
  def instagram_audio(client, id, opts \\ []) do
    params = Model.take_params(opts, [:q, :audio_type])

    with {:ok, data} <-
           Client.request(client, :get, path(id) <> "/instagram/audio", params: params) do
      {:ok, Model.list(InstagramAudio, data)}
    end
  end

  @doc """
  How many posts are left before Instagram refuses the next one.
  """
  @spec instagram_publishing_limit(Client.t(), String.t()) ::
          {:ok, InstagramPublishingLimit.t()} | {:error, FoPost.Error.t()}
  def instagram_publishing_limit(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id) <> "/instagram/publishing-limit") do
      {:ok, InstagramPublishingLimit.from_map(data)}
    end
  end

  @doc """
  Stories still inside their 24 hours, posted through FoPost or not. Pass
  `insights: true` to fetch each story's insights, at one extra call per story.
  """
  @spec instagram_stories(Client.t(), String.t(), keyword()) ::
          {:ok, [InstagramStory.t()]} | {:error, FoPost.Error.t()}
  def instagram_stories(client, id, opts \\ []) do
    params = Model.take_params(opts, [:insights])

    with {:ok, data} <-
           Client.request(client, :get, path(id) <> "/instagram/stories", params: params) do
      {:ok, Model.list(InstagramStory, data)}
    end
  end

  @doc """
  The insight set for one story.
  """
  @spec instagram_story_insights(Client.t(), String.t(), String.t()) ::
          {:ok, InstagramStoryInsights.t()} | {:error, FoPost.Error.t()}
  def instagram_story_insights(client, id, story_id) do
    with {:ok, data} <-
           Client.request(client, :get, path(id) <> "/instagram/stories/#{story_id}/insights") do
      {:ok, InstagramStoryInsights.from_map(data)}
    end
  end

  @doc """
  Organizations a LinkedIn post can mention. People are not searchable: LinkedIn has no
  public person search, so a member mention needs a URN you already hold.
  """
  @spec linkedin_mentions(Client.t(), String.t(), String.t()) ::
          {:ok, [LinkedInMention.t()]} | {:error, FoPost.Error.t()}
  def linkedin_mentions(client, id, query) do
    with {:ok, data} <-
           Client.request(client, :get, path(id) <> "/linkedin/mentions", params: [q: query]) do
      {:ok, Model.list(LinkedInMention, data)}
    end
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

  @doc "Same as `ice_breakers/2`, but raises `FoPost.Error`."
  def ice_breakers!(client, id), do: Result.unwrap!(ice_breakers(client, id))

  @doc "Same as `set_ice_breakers/3`, but raises `FoPost.Error`."
  def set_ice_breakers!(client, id, ice_breakers),
    do: Result.unwrap!(set_ice_breakers(client, id, ice_breakers))

  @doc "Same as `delete_ice_breakers/2`, but raises `FoPost.Error`."
  def delete_ice_breakers!(client, id), do: Result.unwrap!(delete_ice_breakers(client, id))

  @doc "Same as `persistent_menu/2`, but raises `FoPost.Error`."
  def persistent_menu!(client, id), do: Result.unwrap!(persistent_menu(client, id))

  @doc "Same as `set_persistent_menu/3`, but raises `FoPost.Error`."
  def set_persistent_menu!(client, id, menu),
    do: Result.unwrap!(set_persistent_menu(client, id, menu))

  @doc "Same as `delete_persistent_menu/2`, but raises `FoPost.Error`."
  def delete_persistent_menu!(client, id), do: Result.unwrap!(delete_persistent_menu(client, id))

  @doc "Same as `greeting/2`, but raises `FoPost.Error`."
  def greeting!(client, id), do: Result.unwrap!(greeting(client, id))

  @doc "Same as `set_greeting/3`, but raises `FoPost.Error`."
  def set_greeting!(client, id, greeting), do: Result.unwrap!(set_greeting(client, id, greeting))

  @doc "Same as `delete_greeting/2`, but raises `FoPost.Error`."
  def delete_greeting!(client, id), do: Result.unwrap!(delete_greeting(client, id))

  @doc "Same as `webhook_subscription/2`, but raises `FoPost.Error`."
  def webhook_subscription!(client, id), do: Result.unwrap!(webhook_subscription(client, id))

  @doc "Same as `resubscribe_webhook/2`, but raises `FoPost.Error`."
  def resubscribe_webhook!(client, id), do: Result.unwrap!(resubscribe_webhook(client, id))

  defp commands_path(id), do: path(id) <> "/telegram/commands"

  defp messaging_path(id, field), do: path(id) <> "/messaging/" <> field

  defp ice_breaker_list(data),
    do: Model.list(MetaIceBreaker, Model.normalize(data)["ice_breakers"])

  defp menu_list(data),
    do: Model.list(MetaPersistentMenuEntry, Model.normalize(data)["persistent_menu"])

  defp greeting_list(data), do: Model.list(MetaGreetingText, Model.normalize(data)["greeting"])

  defp ice_breaker_body(breaker) do
    %{"question" => field(breaker, :question), "payload" => field(breaker, :payload)}
  end

  defp greeting_body(greeting) do
    %{"locale" => field(greeting, :locale) || "default", "text" => field(greeting, :text)}
  end

  defp menu_entry_body(entry) do
    %{
      "locale" => field(entry, :locale) || "default",
      "call_to_actions" => Enum.map(field(entry, :call_to_actions) || [], &menu_item_body/1)
    }
  end

  # A postback carries a payload and a link a url; the unused key is left out.
  defp menu_item_body(item) do
    %{"type" => field(item, :type), "title" => field(item, :title)}
    |> put_present("payload", field(item, :payload))
    |> put_present("url", field(item, :url))
  end

  defp put_present(map, _key, nil), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)

  defp field(source, key), do: Map.get(source, key, Map.get(source, to_string(key)))

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
