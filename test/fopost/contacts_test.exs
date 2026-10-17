defmodule FoPost.ContactsTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport

  @contact %{
    "id" => "con_1",
    "display_name" => "Ada Okafor",
    "channels" => [
      %{"platform" => "instagram", "handle" => "adaokafor", "externalId" => "178414"},
      %{"platform" => "x", "handle" => "ada_writes", "externalId" => nil}
    ],
    "source" => "inbox",
    "note" => nil,
    "first_seen_at" => "2026-04-02T09:14:00Z",
    "last_seen_at" => "2026-09-18T14:30:00Z",
    "fields" => %{"plan_tier" => "Pro"},
    "labels" => [%{"id" => "lbl_1", "name" => "VIP", "color" => "#0070f3"}]
  }

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "list pages on `pagination`, not `meta`, and decodes the channels", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/contacts", fn conn ->
      assert conn.query_string =~ "workspace_id=ws_1"
      assert conn.query_string =~ "search=ada"

      TestSupport.json(conn, 200, %{
        "data" => [@contact],
        "pagination" => %{"page" => 1, "per_page" => 25, "total" => 1}
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, page} = FoPost.Contacts.list(client, workspace_id: "ws_1", search: "ada")
    assert [contact] = page.data
    assert page.meta.total == 1
    assert page.meta.per_page == 25
    assert [instagram, x] = contact.channels
    assert instagram.handle == "adaokafor"
    assert instagram.external_id == "178414"
    assert x.external_id == nil
    assert contact.fields == %{"plan_tier" => "Pro"}
    assert %DateTime{} = contact.first_seen_at
  end

  test "update patches only what it was given", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PATCH", "/v1/contacts/con_1", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"display_name" => "Ada O."}
      TestSupport.json(conn, 200, %{"data" => @contact})
    end)

    client = TestSupport.client(bypass)
    assert {:ok, contact} = FoPost.Contacts.update(client, "con_1", display_name: "Ada O.")
    assert contact.id == "con_1"
  end

  test "import reports what it skipped and what it did not recognise", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/contacts/import", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "workspace_id" => "ws_1",
               "csv" => "platform,handle\nx,ada\n"
             }

      TestSupport.json(conn, 200, %{
        "data" => %{
          "created" => 1,
          "merged" => 0,
          "skipped" => [%{"row" => 3, "reason" => "platform and handle are both required"}],
          "unknownColumns" => ["tier"]
        }
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, result} =
             FoPost.Contacts.import(client, "ws_1", "platform,handle\nx,ada\n")

    assert result.created == 1
    assert result.unknown_columns == ["tier"]
    assert [%{"row" => 3}] = result.skipped
  end

  test "conversation analytics reads under analytics and keeps the key opaque", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/analytics/inbox/conversations", fn conn ->
      assert conn.query_string =~ "days=30"
      assert conn.query_string =~ "sort=slowest"

      TestSupport.json(conn, 200, %{
        "data" => %{
          "conversations" => [
            %{
              "key" => "9f2c7a10b4e83d5612ff0a8c4d1e6b73",
              "accountId" => "acc_1",
              "platform" => "instagram",
              "received" => 9,
              "sent" => 5,
              "answered" => 5,
              "open" => 1,
              "medianResponseMinutes" => 47,
              "firstMessageAt" => "2026-09-01T08:02:00Z",
              "lastMessageAt" => "2026-09-18T14:30:00Z"
            }
          ],
          "total" => 128,
          "page" => 1,
          "perPage" => 25
        }
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, analytics} =
             FoPost.Contacts.conversation_analytics(client, days: 30, sort: "slowest")

    assert analytics.total == 128
    assert [row] = analytics.conversations
    assert row.median_response_minutes == 47
    # The digest, not a handle: nothing about who wrote it.
    assert row.key == "9f2c7a10b4e83d5612ff0a8c4d1e6b73"
    assert %DateTime{} = row.last_message_at
  end
end
