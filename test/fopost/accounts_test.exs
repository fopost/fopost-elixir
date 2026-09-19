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
end
