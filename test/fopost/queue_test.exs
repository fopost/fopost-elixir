defmodule FoPost.QueueTest do
  use ExUnit.Case, async: true

  alias FoPost.Queue
  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "list_slots scopes to the workspace and decodes each slot", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/queue/slots", fn conn ->
      assert conn.query_string == "workspace_id=ws_1"

      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "id" => "slot_1",
            "workspace_id" => "ws_1",
            "account_id" => nil,
            "weekday" => 1,
            "time" => "09:00",
            "timezone" => "Europe/Zagreb",
            "created_at" => "2026-10-18T10:00:00Z"
          }
        ]
      })
    end)

    assert {:ok, [slot]} = Queue.list_slots(TestSupport.client(bypass), "ws_1")
    assert %FoPost.QueueSlot{id: "slot_1", weekday: 1, time: "09:00"} = slot
    assert slot.account_id == nil
    assert slot.created_at == ~U[2026-10-18 10:00:00Z]
  end

  test "create_slot sends the slot and decodes it", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/queue/slots", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "workspace_id" => "ws_1",
               "account_id" => "acc_1",
               "weekday" => 3,
               "time" => "17:30",
               "timezone" => "UTC"
             }

      TestSupport.json(conn, 201, %{
        "id" => "slot_2",
        "workspace_id" => "ws_1",
        "account_id" => "acc_1",
        "weekday" => 3,
        "time" => "17:30",
        "timezone" => "UTC",
        "created_at" => "2026-10-18T10:00:00Z"
      })
    end)

    assert {:ok, slot} =
             Queue.create_slot(TestSupport.client(bypass),
               workspace_id: "ws_1",
               account_id: "acc_1",
               weekday: 3,
               time: "17:30",
               timezone: "UTC"
             )

    assert slot.id == "slot_2"
    assert slot.account_id == "acc_1"
    assert slot.moved == []
  end

  test "update_slot sends only the given keys and reads the moved posts", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PUT", "/v1/queue/slots/slot_1", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{"time" => "10:00", "account_id" => nil}

      TestSupport.json(conn, 200, %{
        "id" => "slot_1",
        "workspace_id" => "ws_1",
        "account_id" => nil,
        "weekday" => 1,
        "time" => "10:00",
        "timezone" => "Europe/Zagreb",
        "moved" => [
          %{"id" => "post_1", "from" => "2026-10-19T09:00:00Z", "to" => "2026-10-19T10:00:00Z"}
        ]
      })
    end)

    assert {:ok, slot} =
             Queue.update_slot(TestSupport.client(bypass), "slot_1",
               time: "10:00",
               account_id: nil
             )

    assert slot.time == "10:00"
    assert [%FoPost.QueueMove{id: "post_1", to: ~U[2026-10-19 10:00:00Z]}] = slot.moved
  end

  test "delete_slot answers the deletion and the moved posts", %{bypass: bypass} do
    Bypass.expect_once(bypass, "DELETE", "/v1/queue/slots/slot_1", fn conn ->
      TestSupport.json(conn, 200, %{
        "deleted" => true,
        "moved" => [
          %{"id" => "post_1", "from" => "2026-10-19T09:00:00Z", "to" => "2026-10-20T09:00:00Z"}
        ]
      })
    end)

    assert {:ok, result} = Queue.delete_slot(TestSupport.client(bypass), "slot_1")
    assert result.deleted == true
    assert [%FoPost.QueueMove{from: ~U[2026-10-19 09:00:00Z]}] = result.moved
  end

  test "next answers a DateTime or nil", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/queue/next", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"workspace_id" => "ws_1", "account_id" => "acc_1"}

      TestSupport.json(conn, 200, %{"next" => "2026-10-19T09:00:00Z"})
    end)

    assert {:ok, ~U[2026-10-19 09:00:00Z]} =
             Queue.next(TestSupport.client(bypass), "ws_1", account_id: "acc_1")
  end

  test "preview answers the upcoming times in order", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/queue/preview", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"workspace_id" => "ws_1", "count" => "2"}

      TestSupport.json(conn, 200, %{
        "data" => ["2026-10-19T09:00:00Z", "2026-10-20T09:00:00Z"]
      })
    end)

    assert {:ok, [~U[2026-10-19 09:00:00Z], ~U[2026-10-20 09:00:00Z]]} =
             Queue.preview(TestSupport.client(bypass), "ws_1", count: 2)
  end

  test "a post can be created into the queue", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/posts", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(raw)

      assert body["schedule"] == "queue"
      refute Map.has_key?(body, "schedule_at")

      TestSupport.json(conn, 201, %{"data" => %{"id" => "post_1", "status" => "scheduled"}})
    end)

    assert {:ok, %FoPost.Post{id: "post_1"}} =
             FoPost.Posts.create(TestSupport.client(bypass),
               workspace_id: "ws_1",
               accounts: ["acc_1"],
               content: "Hello",
               schedule: "queue"
             )
  end
end
