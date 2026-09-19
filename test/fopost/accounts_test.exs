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
end
