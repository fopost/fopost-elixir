defmodule FoPost.PostsTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "create sends the composed body and decodes the post", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/posts", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(raw)

      assert body["workspace_id"] == "ws_1"
      assert body["accounts"] == ["acc_1", "acc_2"]
      assert body["content"] == [%{"text" => "Hello from Elixir"}]
      assert body["status"] == "draft"
      refute Map.has_key?(body, "title")

      TestSupport.json(conn, 201, %{
        "data" => %{
          "id" => "post_1",
          "workspace_id" => "ws_1",
          "status" => "draft",
          "content" => [%{"text" => "Hello from Elixir"}],
          "accounts" => [%{"id" => "acc_1", "platform" => "twitter"}],
          "created_at" => "2026-08-30T10:00:00Z"
        }
      })
    end)

    opts = [
      workspace_id: "ws_1",
      content: "Hello from Elixir",
      accounts: ["acc_1", %{"id" => "acc_2"}],
      status: "draft"
    ]

    assert {:ok, post} = FoPost.Posts.create(TestSupport.client(bypass), opts)
    assert post.id == "post_1"
    assert [block] = post.content
    assert block.text == "Hello from Elixir"
    assert [account] = post.accounts
    assert account.platform == "twitter"
    assert post.created_at == ~U[2026-08-30 10:00:00Z]
  end

  test "a list becomes a thread and a DateTime becomes ISO 8601", %{bypass: bypass} do
    expected = [
      %{"text" => "First"},
      %{"text" => "Second", "media" => [%{"type" => "image", "url" => "u"}]}
    ]

    Bypass.expect_once(bypass, "POST", "/v1/posts", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(raw)

      assert body["content"] == expected
      assert body["schedule_at"] == "2026-09-01T10:00:00Z"
      assert body["status"] == "scheduled"

      TestSupport.json(conn, 201, %{"data" => %{"id" => "post_2"}})
    end)

    opts = [
      workspace_id: "ws_1",
      accounts: ["acc_1"],
      status: "scheduled",
      schedule_at: ~U[2026-09-01 10:00:00Z],
      content: ["First", %{text: "Second", media: [%{type: "image", url: "u"}]}]
    ]

    assert {:ok, post} = FoPost.Posts.create(TestSupport.client(bypass), opts)
    assert post.id == "post_2"
  end

  test "update sends only the keys that were passed", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PUT", "/v1/posts/post_1", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{"title" => "Renamed", "schedule_at" => nil}

      TestSupport.json(conn, 200, %{"data" => %{"id" => "post_1", "title" => "Renamed"}})
    end)

    client = TestSupport.client(bypass)
    opts = [title: "Renamed", schedule_at: nil]

    assert {:ok, post} = FoPost.Posts.update(client, "post_1", opts)
    assert post.title == "Renamed"
  end

  test "list decodes the page and its meta", %{bypass: bypass} do
    meta = %{
      "current_page" => 1,
      "per_page" => 30,
      "total" => 42,
      "last_page" => 2,
      "from" => 1,
      "to" => 2
    }

    Bypass.expect_once(bypass, "GET", "/v1/posts", fn conn ->
      assert conn.query_string =~ "workspace_id=ws_1"
      assert conn.query_string =~ "status=published"

      data = [%{"id" => "post_1"}, %{"id" => "post_2"}]

      TestSupport.json(conn, 200, %{"data" => data, "meta" => meta})
    end)

    client = TestSupport.client(bypass)
    opts = [workspace_id: "ws_1", status: "published"]

    assert {:ok, page} = FoPost.Posts.list(client, opts)
    assert Enum.map(page.data, & &1.id) == ["post_1", "post_2"]
    assert page.meta.total == 42
    assert page.meta.last_page == 2
    assert page.meta.current_page == 1
  end

  test "publish queues delivery and decodes the rows", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/posts/post_1/publish", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{"accountIds" => ["acc_1"]}

      deliveries = [%{"id" => "del_1", "accountId" => "acc_1", "status" => "queued"}]

      TestSupport.json(conn, 200, %{
        "data" => %{"post_status" => "publishing", "deliveries" => deliveries}
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, result} = FoPost.Posts.publish(client, "post_1", account_ids: ["acc_1"])
    assert result.post_status == "publishing"
    assert [delivery] = result.deliveries
    assert delivery.account_id == "acc_1"
    assert delivery.status == "queued"
  end

  test "the bang variant raises the same error", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/posts/missing", fn conn ->
      TestSupport.json(conn, 404, %{"error" => "not_found", "message" => "No such post"})
    end)

    client = TestSupport.client(bypass)

    assert_raise FoPost.Error, "FoPost: 404 not_found: No such post", fn ->
      FoPost.Posts.get!(client, "missing")
    end
  end
end
