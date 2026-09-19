defmodule FoPost.InboxTest do
  use ExUnit.Case, async: true

  alias FoPost.Inbox
  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "list sends snake_case filters and builds a page", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/inbox", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      assert conn.query_params == %{
               "workspace_id" => "ws_1",
               "state" => "unread",
               "type" => "comment",
               "per_page" => "10"
             }

      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "id" => "item_1",
            "workspaceId" => "ws_1",
            "platform" => "instagram",
            "type" => "comment",
            "state" => "unread",
            "direction" => "inbound",
            "authorHandle" => "yourbrand",
            "text" => "Love this",
            "attachments" => [%{"kind" => "image", "previewUrl" => "https://yourbrand.com/p"}],
            "platformCreatedAt" => "2026-09-01T10:00:00Z",
            "canReply" => true,
            "account" => %{"id" => "acc_1", "platform" => "instagram", "username" => "yourbrand"}
          }
        ],
        "meta" => %{"page" => 1, "perPage" => 10, "total" => 1}
      })
    end)

    client = TestSupport.client(bypass)
    opts = [workspace_id: "ws_1", state: "unread", type: "comment", per_page: 10, q: nil]

    assert {:ok, page} = Inbox.list(client, opts)
    assert [item] = page.data
    assert item.id == "item_1"
    assert item.workspace_id == "ws_1"
    assert item.author_handle == "yourbrand"
    assert item.platform_created_at == ~U[2026-09-01 10:00:00Z]
    assert item.can_reply
    assert [attachment] = item.attachments
    assert attachment.preview_url == "https://yourbrand.com/p"
    assert item.account.username == "yourbrand"
    assert page.meta.current_page == 1
    assert page.meta.per_page == 10
    assert page.meta.total == 1
  end

  test "update patches the state with snoozedUntil in camelCase", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PATCH", "/v1/inbox/item_1", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "state" => "snoozed",
               "snoozedUntil" => "2026-09-02T09:00:00Z"
             }

      TestSupport.json(conn, 200, %{
        "data" => %{
          "id" => "item_1",
          "state" => "snoozed",
          "snoozedUntil" => "2026-09-02T09:00:00Z"
        }
      })
    end)

    client = TestSupport.client(bypass)
    opts = [state: "snoozed", snoozed_until: ~U[2026-09-02 09:00:00Z]]

    assert {:ok, item} = Inbox.update(client, "item_1", opts)
    assert item.state == "snoozed"
    assert item.snoozed_until == ~U[2026-09-02 09:00:00Z]
  end

  test "reply posts the text and lifts the platform reply", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/inbox/item_1/reply", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"text" => "Thanks!"}

      TestSupport.json(conn, 200, %{
        "data" => %{
          "item" => %{"id" => "item_1", "state" => "read", "repliedAt" => "2026-09-01T11:00:00Z"},
          "reply" => %{"externalId" => "c_9", "externalUrl" => "https://yourbrand.com/c/9"}
        }
      })
    end)

    assert {:ok, result} = Inbox.reply(TestSupport.client(bypass), "item_1", text: "Thanks!")
    assert result.item.replied_at == ~U[2026-09-01 11:00:00Z]
    assert result.external_id == "c_9"
    assert result.external_url == "https://yourbrand.com/c/9"
  end

  test "mark_thread_read sends a snake_case body and answers the count", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/inbox/read", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "workspace_id" => "ws_1",
               "account_id" => "acc_1",
               "post_external_id" => "ext_1"
             }

      TestSupport.json(conn, 200, %{"data" => %{"updated" => 3}})
    end)

    client = TestSupport.client(bypass)
    opts = [workspace_id: "ws_1", account_id: "acc_1", post_external_id: "ext_1"]

    assert {:ok, 3} = Inbox.mark_thread_read(client, opts)
  end

  test "unread_count reads the unwrapped count", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/inbox/unread-count", fn conn ->
      TestSupport.json(conn, 200, %{"count" => 7})
    end)

    assert {:ok, 7} = Inbox.unread_count(TestSupport.client(bypass), workspace_id: "ws_1")
  end

  test "approve_reply takes an integer id and an optional text", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/inbox/approvals/42/approve", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"text" => "Edited"}

      TestSupport.json(conn, 200, %{"data" => %{"id" => 42, "outcome" => "sent"}})
    end)

    assert {:ok, decision} = Inbox.approve_reply(TestSupport.client(bypass), 42, text: "Edited")
    assert decision.id == 42
    assert decision.outcome == "sent"
  end

  test "items decode the action state and capability flags", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/inbox", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "id" => "item_1",
            "liked" => true,
            "pinned" => false,
            "reaction" => "❤",
            "editedAt" => "2026-09-01T12:00:00Z",
            "canLike" => true,
            "canPin" => true,
            "canEdit" => true,
            "canReact" => true,
            "canSendMedia" => false,
            "canQuickReply" => false,
            "canPrivateReply" => true
          }
        ],
        "meta" => %{"page" => 1, "perPage" => 20, "total" => 1}
      })
    end)

    assert {:ok, %{data: [item]}} = Inbox.list(TestSupport.client(bypass))
    assert item.liked
    refute item.pinned
    assert item.reaction == "❤"
    assert item.edited_at == ~U[2026-09-01 12:00:00Z]
    assert item.can_like and item.can_pin and item.can_edit and item.can_react
    refute item.can_send_media or item.can_quick_reply
    assert item.can_private_reply
  end

  test "accounts decode canStartConversation", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/inbox/accounts", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => [%{"id" => "acc_1", "dmSupported" => true, "canStartConversation" => true}]
      })
    end)

    assert {:ok, [account]} = Inbox.accounts(TestSupport.client(bypass))
    assert account.can_start_conversation
  end

  test "like, unlike, pin, and unpin post to their action path", %{bypass: bypass} do
    for action <- ["like", "unlike", "pin", "unpin"] do
      Bypass.expect_once(bypass, "POST", "/v1/inbox/item_1/" <> action, fn conn ->
        TestSupport.json(conn, 200, %{"data" => %{"id" => "item_1", "liked" => true}})
      end)
    end

    client = TestSupport.client(bypass)

    assert {:ok, %{id: "item_1", liked: true}} = Inbox.like(client, "item_1")
    assert {:ok, %{id: "item_1"}} = Inbox.unlike(client, "item_1")
    assert {:ok, %{id: "item_1"}} = Inbox.pin(client, "item_1")
    assert {:ok, %{id: "item_1"}} = Inbox.unpin(client, "item_1")
  end

  test "react sends the reaction, and nil as null to remove it", %{bypass: bypass} do
    Bypass.expect(bypass, "POST", "/v1/inbox/item_1/react", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      reaction = Jason.decode!(raw) |> Map.fetch!("reaction")

      TestSupport.json(conn, 200, %{"data" => %{"id" => "item_1", "reaction" => reaction}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %{reaction: "❤"}} = Inbox.react(client, "item_1", "❤")
    assert {:ok, %{reaction: nil}} = Inbox.react(client, "item_1", nil)
  end
end
