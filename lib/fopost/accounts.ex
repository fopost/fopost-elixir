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
  alias FoPost.HealthSummary
  alias FoPost.Message
  alias FoPost.MetaGreetingText
  alias FoPost.MetaIceBreaker
  alias FoPost.MetaPersistentMenuEntry
  alias FoPost.Model
  alias FoPost.Result
  alias FoPost.SlackChannel
  alias FoPost.SlackIdentity
  alias FoPost.SlackMember
  alias FoPost.TelegramBotCommand
  alias FoPost.TelegramConnectCode
  alias FoPost.TelegramConnectStatus
  alias FoPost.ValidationResult
  alias FoPost.WebhookSubscription

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

  defp path(id), do: "/accounts/" <> URI.encode(to_string(id), &URI.char_unreserved?/1)
end
