defmodule FoPost.AccountsTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "rename sends an explicit null to restore the platform name", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PATCH", "/v1/accounts/acc_1", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"display_name" => nil}

      TestSupport.json(conn, 200, %{
        "data" => %{"id" => "acc_1", "name" => "Acme", "platform_name" => "Acme"}
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, account} = FoPost.Accounts.rename(client, "acc_1", nil)
    assert account.platform_name == "Acme"
  end

  test "move sends the target workspace", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/accounts/acc_1/move", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"workspace_id" => "ws_2"}
      TestSupport.json(conn, 200, %{"data" => %{"id" => "acc_1", "workspace_id" => "ws_2"}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %FoPost.Account{workspace_id: "ws_2"}} =
             FoPost.Accounts.move(client, "acc_1", "ws_2")
  end

  test "a blocked move keeps the blocking tables on the error", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/accounts/acc_1/move", fn conn ->
      TestSupport.json(conn, 409, %{
        "error" => "move_blocked",
        "message" => "Blocked",
        "blocking_tables" => ["ads"]
      })
    end)

    client = TestSupport.client(bypass)

    assert {:error, %FoPost.Error{status: 409, code: "move_blocked", body: body}} =
             FoPost.Accounts.move(client, "acc_1", "ws_2")

    assert body["blocking_tables"] == ["ads"]
  end

  test "list filters by group and reads the platform name", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/accounts", fn conn ->
      assert conn.query_string == "group_id=grp_1"

      TestSupport.json(conn, 200, %{
        "data" => [%{"id" => "acc_1", "name" => "Brand", "platformName" => "Acme"}]
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [account]} = FoPost.Accounts.list(client, group_id: "grp_1")
    assert account.name == "Brand"
    assert account.platform_name == "Acme"
  end

  test "create_telegram_connect_code sends the workspace", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/accounts/telegram/connect-code", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"workspaceId" => "ws_1"}

      TestSupport.json(conn, 201, %{
        "data" => %{
          "code" => "ABC123",
          "command" => "/connect ABC123",
          "bot_username" => "fopost_bot",
          "deep_link" => nil,
          "group_link" => nil,
          "expires_at" => "2026-09-19T12:15:00.000Z"
        }
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, code} =
             FoPost.Accounts.create_telegram_connect_code(client, workspace_id: "ws_1")

    assert code.command == "/connect ABC123"
    assert code.bot_username == "fopost_bot"
    assert code.deep_link == nil
    assert %DateTime{} = code.expires_at
  end

  test "telegram_connect_status reads the failure reason", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/accounts/telegram/connect-code/status", fn conn ->
      assert conn.query_string == "code=ABC123"

      TestSupport.json(conn, 200, %{
        "data" => %{"status" => "failed", "account_id" => nil, "reason" => "card_required"}
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %FoPost.TelegramConnectStatus{status: "failed", reason: "card_required"}} =
             FoPost.Accounts.telegram_connect_status(client, "ABC123")
  end

  test "Telegram bot commands are read, replaced, and cleared", %{bypass: bypass} do
    menu = %{"commands" => [%{"command" => "start", "description" => "Start"}]}

    Bypass.expect(bypass, fn conn ->
      assert conn.request_path == "/v1/accounts/acc_1/telegram/commands"

      case conn.method do
        "GET" ->
          TestSupport.json(conn, 200, %{"data" => menu})

        "PUT" ->
          {:ok, raw, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(raw) == menu
          TestSupport.json(conn, 200, %{"data" => menu})

        "DELETE" ->
          TestSupport.json(conn, 200, %{"data" => %{"commands" => []}})
      end
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [%FoPost.TelegramBotCommand{command: "start"}]} =
             FoPost.Accounts.telegram_bot_commands(client, "acc_1")

    assert {:ok, [_]} =
             FoPost.Accounts.set_telegram_bot_commands(client, "acc_1", [
               %{command: "start", description: "Start"}
             ])

    assert {:ok, []} = FoPost.Accounts.delete_telegram_bot_commands(client, "acc_1")
  end

  test "slack channels and members read the list", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      case conn.request_path do
        "/v1/accounts/acc_1/slack/channels" ->
          TestSupport.json(conn, 200, %{
            "data" => [
              %{
                "id" => "C1",
                "name" => "general",
                "is_private" => false,
                "is_member" => true,
                "is_current" => true
              }
            ]
          })

        "/v1/accounts/acc_1/slack/members" ->
          TestSupport.json(conn, 200, %{
            "data" => [
              %{
                "id" => "U1",
                "name" => "ada",
                "real_name" => "Ada",
                "display_name" => nil,
                "avatar" => nil,
                "is_bot" => false
              }
            ]
          })
      end
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [%FoPost.SlackChannel{id: "C1", is_current: true}]} =
             FoPost.Accounts.slack_channels(client, "acc_1")

    assert {:ok, [%FoPost.SlackMember{real_name: "Ada", display_name: nil}]} =
             FoPost.Accounts.slack_members(client, "acc_1")
  end

  test "update_slack_identity omits unset keys and sends nil to clear", %{bypass: bypass} do
    identity = %{"username" => "Bot", "icon_url" => nil, "icon_emoji" => ":rocket:"}

    Bypass.expect(bypass, fn conn ->
      assert conn.request_path == "/v1/accounts/acc_1/slack/identity"

      case conn.method do
        "GET" ->
          TestSupport.json(conn, 200, %{"data" => identity})

        "PATCH" ->
          {:ok, raw, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(raw) == %{"username" => "Bot", "icon_url" => nil}
          TestSupport.json(conn, 200, %{"data" => identity})
      end
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %FoPost.SlackIdentity{icon_emoji: ":rocket:"}} =
             FoPost.Accounts.slack_identity(client, "acc_1")

    assert {:ok, %FoPost.SlackIdentity{username: "Bot"}} =
             FoPost.Accounts.update_slack_identity(client, "acc_1",
               username: "Bot",
               icon_url: nil
             )
  end

  test "slack calls surface a webhook connection as a 409", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/slack/channels", fn conn ->
      TestSupport.json(conn, 409, %{"error" => "webhook_connection", "message" => "Reconnect"})
    end)

    client = TestSupport.client(bypass)

    assert {:error, %FoPost.Error{status: 409, code: "webhook_connection"}} =
             FoPost.Accounts.slack_channels(client, "acc_1")
  end

  test "discord channels list and the channel switch", %{bypass: bypass} do
    channel = %{
      "id" => "c2",
      "name" => "launches",
      "type" => 0,
      "parent_id" => nil,
      "nsfw" => false,
      "is_current" => true
    }

    Bypass.expect(bypass, fn conn ->
      case conn.method do
        "GET" ->
          assert conn.request_path == "/v1/accounts/acc_1/discord/channels"
          TestSupport.json(conn, 200, %{"data" => [channel]})

        "PATCH" ->
          assert conn.request_path == "/v1/accounts/acc_1/discord/channels/current"
          {:ok, raw, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(raw) == %{"channel_id" => "c2"}
          TestSupport.json(conn, 200, %{"data" => channel})
      end
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [%FoPost.DiscordChannel{id: "c2", is_current: true}]} =
             FoPost.Accounts.discord_channels(client, "acc_1")

    assert {:ok, %FoPost.DiscordChannel{name: "launches"}} =
             FoPost.Accounts.switch_discord_channel(client, "acc_1", "c2")
  end

  test "update_discord_identity omits unset keys", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PATCH", "/v1/accounts/acc_1/discord/identity", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      # A key left out never reaches the wire, so Discord keeps it.
      assert Jason.decode!(raw) == %{"username" => "Release Bot"}

      TestSupport.json(conn, 200, %{"data" => %{"username" => "Release Bot", "avatar_url" => nil}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %FoPost.DiscordIdentity{username: "Release Bot"}} =
             FoPost.Accounts.update_discord_identity(client, "acc_1", username: "Release Bot")
  end

  test "a discord scheduled event round-trips", %{bypass: bypass} do
    event = %{
      "id" => "e1",
      "name" => "Launch stream",
      "description" => nil,
      "channel_id" => nil,
      "location" => "https://example.com/live",
      "start_time" => "2026-10-01T18:00:00.000Z",
      "end_time" => "2026-10-01T19:00:00.000Z",
      "status" => "scheduled",
      "user_count" => 0
    }

    Bypass.expect(bypass, fn conn ->
      case conn.method do
        "POST" ->
          {:ok, raw, conn} = Plug.Conn.read_body(conn)

          assert Jason.decode!(raw) == %{
                   "name" => "Launch stream",
                   "start_time" => "2026-10-01T18:00:00.000Z",
                   "end_time" => "2026-10-01T19:00:00.000Z",
                   "location" => "https://example.com/live"
                 }

          TestSupport.json(conn, 201, %{"data" => event})

        "GET" ->
          TestSupport.json(conn, 200, %{"data" => [event]})

        "PATCH" ->
          {:ok, raw, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(raw) == %{"status" => "canceled"}
          TestSupport.json(conn, 200, %{"data" => Map.put(event, "status", "canceled")})

        "DELETE" ->
          TestSupport.json(conn, 200, %{"data" => %{"deleted" => true}})
      end
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %FoPost.DiscordScheduledEvent{id: "e1"}} =
             FoPost.Accounts.create_discord_event(client, "acc_1",
               name: "Launch stream",
               start_time: "2026-10-01T18:00:00.000Z",
               end_time: "2026-10-01T19:00:00.000Z",
               location: "https://example.com/live"
             )

    assert {:ok, [%FoPost.DiscordScheduledEvent{id: "e1"}]} =
             FoPost.Accounts.discord_events(client, "acc_1")

    assert {:ok, %FoPost.DiscordScheduledEvent{status: "canceled"}} =
             FoPost.Accounts.update_discord_event(client, "acc_1", "e1", status: "canceled")

    assert {:ok, %FoPost.DiscordAck{deleted: true}} =
             FoPost.Accounts.delete_discord_event(client, "acc_1", "e1")
  end

  test "discord members, roles and direct messages", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      case conn.request_path do
        "/v1/accounts/acc_1/discord/members" ->
          assert conn.query_string == "q=ada"

          TestSupport.json(conn, 200, %{
            "data" => [%{"id" => "u7", "username" => "ada", "is_bot" => false, "roles" => ["r1"]}]
          })

        "/v1/accounts/acc_1/discord/roles/r1/members/u7" ->
          assert conn.method == "PUT"
          TestSupport.json(conn, 200, %{"data" => %{"assigned" => true}})

        "/v1/accounts/acc_1/discord/dm" ->
          {:ok, raw, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(raw) == %{"member_id" => "u7", "content" => "hi"}
          TestSupport.json(conn, 201, %{"data" => %{"id" => "m1", "channel_id" => "dm1"}})
      end
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [%FoPost.DiscordMember{id: "u7", roles: ["r1"]}]} =
             FoPost.Accounts.discord_members(client, "acc_1", q: "ada")

    assert {:ok, %FoPost.DiscordAck{assigned: true}} =
             FoPost.Accounts.add_discord_member_role(client, "acc_1", "r1", "u7")

    assert {:ok, %FoPost.DiscordMessageRef{channel_id: "dm1"}} =
             FoPost.Accounts.send_discord_direct_message(client, "acc_1", "u7", "hi")
  end

  test "discord calls surface a webhook connection as a 409", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/discord/channels", fn conn ->
      TestSupport.json(conn, 409, %{"error" => "webhook_connection", "message" => "Upgrade it"})
    end)

    client = TestSupport.client(bypass)

    assert {:error, %FoPost.Error{status: 409, code: "webhook_connection"}} =
             FoPost.Accounts.discord_channels(client, "acc_1")
  end
end
