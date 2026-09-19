defmodule FoPost.AccountGroupsTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport

  @group %{
    "id" => "grp_1",
    "name" => "Launch",
    "account_ids" => ["acc_1", "acc_2"],
    "created_at" => "2026-09-19T10:00:00Z",
    "updated_at" => "2026-09-19T10:00:00Z"
  }

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "list filters by workspace and decodes each group", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/account-groups", fn conn ->
      assert conn.query_string == "workspace_id=ws_1"
      TestSupport.json(conn, 200, %{"data" => [@group]})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [group]} = FoPost.AccountGroups.list(client, workspace_id: "ws_1")
    assert group.account_ids == ["acc_1", "acc_2"]
    assert %DateTime{} = group.created_at
  end

  test "create, get, update, and delete hit their paths", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/account-groups", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "workspace_id" => "ws_1",
               "name" => "Launch",
               "account_ids" => ["acc_1"]
             }

      TestSupport.json(conn, 201, %{"data" => @group})
    end)

    Bypass.expect_once(bypass, "GET", "/v1/account-groups/grp_1", fn conn ->
      TestSupport.json(conn, 200, %{"data" => @group})
    end)

    Bypass.expect_once(bypass, "PATCH", "/v1/account-groups/grp_1", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"name" => "Renamed"}
      TestSupport.json(conn, 200, %{"data" => @group})
    end)

    Bypass.expect_once(bypass, "DELETE", "/v1/account-groups/grp_1", fn conn ->
      TestSupport.json(conn, 200, %{"message" => "Account group deleted"})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %FoPost.AccountGroup{id: "grp_1"}} =
             FoPost.AccountGroups.create(client,
               workspace_id: "ws_1",
               name: "Launch",
               account_ids: ["acc_1"]
             )

    assert {:ok, %FoPost.AccountGroup{name: "Launch"}} = FoPost.AccountGroups.get(client, "grp_1")
    assert {:ok, _group} = FoPost.AccountGroups.update(client, "grp_1", name: "Renamed")
    assert {:ok, %FoPost.Message{}} = FoPost.AccountGroups.delete(client, "grp_1")
  end

  test "set_members replaces the account ids", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PUT", "/v1/account-groups/grp_1/members", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"account_ids" => ["acc_2"]}
      TestSupport.json(conn, 200, %{"data" => @group})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %FoPost.AccountGroup{id: "grp_1"}} =
             FoPost.AccountGroups.set_members(client, "grp_1", ["acc_2"])
  end
end
