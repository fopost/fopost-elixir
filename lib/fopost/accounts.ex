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
  alias FoPost.Model
  alias FoPost.RedditFlair
  alias FoPost.RedditSubreddit
  alias FoPost.RedditSubredditRule
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
  Subreddits the account is subscribed to, busiest first, plus its own profile page.

  `:can_post` is false where the account may read but not submit, and `:is_default` marks
  the subreddit posts go to when a post names none. A 409 whose `code` is
  `"reconnect_required"` means the account has to be reconnected first.
  """
  @spec reddit_subreddits(Client.t(), String.t()) ::
          {:ok, [RedditSubreddit.t()]} | {:error, FoPost.Error.t()}
  def reddit_subreddits(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id) <> "/reddit/subreddits") do
      {:ok, Model.list(RedditSubreddit, data)}
    end
  end

  @doc """
  The rules a subreddit publishes, in its own order. `subreddit` carries no `r/` prefix.
  """
  @spec reddit_subreddit_rules(Client.t(), String.t(), String.t()) ::
          {:ok, [RedditSubredditRule.t()]} | {:error, FoPost.Error.t()}
  def reddit_subreddit_rules(client, id, subreddit) do
    url_path = path(id) <> "/reddit/subreddits/" <> encode(subreddit) <> "/rules"

    with {:ok, data} <- Client.request(client, :get, url_path) do
      {:ok, Model.list(RedditSubredditRule, Model.normalize(data)["rules"])}
    end
  end

  @doc """
  Post flairs one subreddit offers.

  A flair id is valid only in the subreddit it came from: pass it as `flair_id` in the
  post's Reddit platform settings, and preflight rejects an id from anywhere else.
  """
  @spec reddit_flairs(Client.t(), String.t(), String.t()) ::
          {:ok, [RedditFlair.t()]} | {:error, FoPost.Error.t()}
  def reddit_flairs(client, id, subreddit) do
    url_path = path(id) <> "/reddit/flairs"

    with {:ok, data} <-
           Client.request(client, :get, url_path, params: %{"subreddit" => subreddit}) do
      {:ok, Model.list(RedditFlair, Model.normalize(data)["flairs"])}
    end
  end

  @doc """
  Sets where posts from a Reddit account go when a post names no subreddit.

  `nil` falls back to the account's own profile page, which always takes a post. Returns
  the subreddit that is now in effect.
  """
  @spec set_reddit_default_subreddit(Client.t(), String.t(), String.t() | nil) ::
          {:ok, String.t() | nil} | {:error, FoPost.Error.t()}
  def set_reddit_default_subreddit(client, id, subreddit) do
    url_path = path(id) <> "/reddit/default-subreddit"

    with {:ok, data} <-
           Client.request(client, :put, url_path, json: %{"subreddit" => subreddit}) do
      {:ok, Model.normalize(data)["subreddit"]}
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

  @doc "Same as `reddit_subreddits/2`, but raises `FoPost.Error`."
  def reddit_subreddits!(client, id), do: Result.unwrap!(reddit_subreddits(client, id))

  @doc "Same as `reddit_subreddit_rules/3`, but raises `FoPost.Error`."
  def reddit_subreddit_rules!(client, id, subreddit),
    do: Result.unwrap!(reddit_subreddit_rules(client, id, subreddit))

  @doc "Same as `reddit_flairs/3`, but raises `FoPost.Error`."
  def reddit_flairs!(client, id, subreddit),
    do: Result.unwrap!(reddit_flairs(client, id, subreddit))

  @doc "Same as `set_reddit_default_subreddit/3`, but raises `FoPost.Error`."
  def set_reddit_default_subreddit!(client, id, subreddit),
    do: Result.unwrap!(set_reddit_default_subreddit(client, id, subreddit))

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

  defp path(id), do: "/accounts/" <> encode(id)

  defp encode(value), do: URI.encode(to_string(value), &URI.char_unreserved?/1)
end
