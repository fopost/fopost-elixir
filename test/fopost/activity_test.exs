defmodule FoPost.ActivityTest do
  use ExUnit.Case, async: true

  alias FoPost.Activity
  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "reads the audit log and keeps the cursor", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/activity", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      assert conn.query_params == %{
               "workspace_id" => "ws_1",
               "kind" => "security",
               "limit" => "1"
             }

      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "id" => "evt_1",
            "workspace_id" => "ws_1",
            "kind" => "security",
            "ref_type" => "member_removed",
            "ref_id" => "usr_2",
            "summary" => "Removed sam@example.com",
            "actor" => %{"type" => "user", "name" => "Ada"},
            "time" => "2026-09-20T10:00:00Z"
          }
        ],
        "meta" => %{"next_cursor" => "42"}
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, page} = Activity.list(client, workspace_id: "ws_1", kind: "security", limit: 1)
    assert [event] = page.data
    assert event.ref_type == "member_removed"
    assert event.actor.name == "Ada"
    assert page.next_cursor == "42"
  end

  test "the end of the list is a nil cursor", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/activity", fn conn ->
      TestSupport.json(conn, 200, %{"data" => [], "meta" => %{"next_cursor" => nil}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, page} = Activity.list(client)
    assert page.data == []
    assert page.next_cursor == nil
  end
end
