defmodule FoPost.BroadcastsTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport

  @broadcast %{
    "id" => "bc_1",
    "name" => "September check-in",
    "text" => "New colours just landed.",
    "account_id" => "acc_1",
    "audience" => %{"platforms" => ["instagram"]},
    "status" => "sent",
    "scheduled_at" => nil,
    "sent_at" => "2026-09-19T10:04:00Z",
    "created_at" => "2026-09-19T09:58:00Z",
    "counts" => %{
      "total" => 3,
      "sent" => 2,
      "skipped" => 1,
      "failed" => 0,
      "pending" => 0
    }
  }

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "list pages on `pagination`, not `meta`, and keeps the counts", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/broadcasts", fn conn ->
      assert conn.query_string =~ "workspace_id=ws_1"
      assert conn.query_string =~ "status=sent"

      TestSupport.json(conn, 200, %{
        "data" => [@broadcast],
        "pagination" => %{"page" => 1, "per_page" => 25, "total" => 1}
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, page} = FoPost.Broadcasts.list(client, workspace_id: "ws_1", status: "sent")
    assert [broadcast] = page.data
    assert page.meta.total == 1
    assert broadcast.name == "September check-in"
    assert broadcast.counts.sent == 2
    assert broadcast.counts.skipped == 1
    assert %DateTime{} = broadcast.sent_at
  end

  test "create sends the snake_case body", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/broadcasts", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(raw)

      assert body["workspace_id"] == "ws_1"
      assert body["account_id"] == "acc_1"
      assert body["audience"] == %{"platforms" => ["instagram"]}
      # An unset field must not travel: it would claim we mean it.
      refute Map.has_key?(body, "media_id")

      TestSupport.json(conn, 201, %{"data" => @broadcast})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, broadcast} =
             FoPost.Broadcasts.create(client,
               workspace_id: "ws_1",
               account_id: "acc_1",
               name: "September check-in",
               text: "New colours just landed.",
               audience: %{"platforms" => ["instagram"]}
             )

    assert broadcast.id == "bc_1"
  end

  # A closed messaging window has to be readable, or a non-send is a mystery.
  test "a skipped recipient keeps its reason", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/broadcasts/bc_1/recipients", fn conn ->
      assert conn.query_string =~ "status=skipped"

      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "contact_id" => "con_1",
            "display_name" => "Sam Rivera",
            "status" => "skipped",
            "skip_reason" => "window_closed",
            "sent_at" => nil,
            "error" => nil
          }
        ],
        "pagination" => %{"page" => 1, "per_page" => 50, "total" => 1}
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, page} = FoPost.Broadcasts.recipients(client, "bc_1", status: "skipped")
    assert [recipient] = page.data
    assert recipient.status == "skipped"
    assert recipient.skip_reason == "window_closed"
  end

  test "send reports how many matched", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/broadcasts/bc_1/send", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => %{"id" => "bc_1", "status" => "sending", "recipients" => 3}
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, sent} = FoPost.Broadcasts.send(client, "bc_1")
    assert sent.recipients == 3
    assert sent.status == "sending"
  end

  test "sequence steps travel as given", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/sequences", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(raw)

      assert body["steps"] == [%{"delay_hours" => 0, "text" => "Hi"}]

      TestSupport.json(conn, 201, %{
        "data" => %{
          "id" => "seq_1",
          "name" => "Welcome",
          "account_id" => "acc_1",
          "steps" => [
            %{"delay_hours" => 0, "text" => "Hi"},
            %{"delay_hours" => 48, "text" => "Still here?"}
          ],
          "status" => "active",
          "created_at" => "2026-09-12T08:00:00Z"
        }
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, sequence} =
             FoPost.Sequences.create(client,
               workspace_id: "ws_1",
               account_id: "acc_1",
               name: "Welcome",
               steps: [%{"delay_hours" => 0, "text" => "Hi"}]
             )

    assert [_first, second] = sequence.steps
    assert second.delay_hours == 48
  end

  test "enroll takes ids or an audience", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/sequences/seq_1/enroll", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(raw)

      assert body["contact_ids"] == ["con_1", "con_2"]
      refute Map.has_key?(body, "audience")

      TestSupport.json(conn, 200, %{"data" => %{"id" => "seq_1", "enrolled" => 2}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, enrolled} =
             FoPost.Sequences.enroll(client, "seq_1", contact_ids: ["con_1", "con_2"])

    assert enrolled.enrolled == 2
  end

  test "unenroll names the contacts it stops", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/sequences/seq_1/unenroll", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"contact_ids" => ["con_1"]}

      TestSupport.json(conn, 200, %{"data" => %{"id" => "seq_1", "stopped" => 1}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, stopped} = FoPost.Sequences.unenroll(client, "seq_1", ["con_1"])
    assert stopped.stopped == 1
  end
end
