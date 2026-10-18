defmodule FoPost.PostsTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "create can target an account group alone", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/posts", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(raw)

      assert body["account_group_id"] == "grp_1"
      assert body["accounts"] == []
      TestSupport.json(conn, 201, %{"data" => %{"id" => "post_1"}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %FoPost.Post{id: "post_1"}} =
             FoPost.Posts.create(client,
               workspace_id: "ws_1",
               account_group_id: "grp_1",
               content: "Hello"
             )
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

  describe "files on a post" do
    defp presigned_slot(bypass) do
      %{
        "uploadId" => "up_1",
        "uploadUrl" => "http://localhost:#{bypass.port}/bucket/up_1",
        "method" => "PUT",
        "headers" => %{"Content-Type" => "video/mp4"}
      }
    end

    defp limits(conn, multipart_max_file_bytes) do
      TestSupport.json(conn, 200, %{
        "data" => %{
          "maxFileBytes" => 5_368_709_120,
          "multipartMaxFileBytes" => multipart_max_file_bytes
        }
      })
    end

    test "small files travel with the post as one multipart request", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/v1/media/limits", fn conn ->
        assert conn.query_string == "workspaceId=ws_1"
        limits(conn, 104_857_600)
      end)

      Bypass.expect_once(bypass, "POST", "/v1/posts", fn conn ->
        assert [content_type] = Plug.Conn.get_req_header(conn, "content-type")
        assert content_type =~ "multipart/form-data"

        {:ok, raw, conn} = Plug.Conn.read_body(conn)

        assert raw =~ ~s(name="post")
        assert raw =~ ~s("workspace_id":"ws_1")
        assert raw =~ ~s("content":[{"text":"Hello"}])
        assert raw =~ ~s(name="files"; filename="chart.png")
        assert raw =~ "content-type: image/png"
        assert raw =~ "PNGBYTES"

        TestSupport.json(conn, 201, %{"data" => %{"id" => "post_1"}})
      end)

      assert {:ok, %FoPost.Post{id: "post_1"}} =
               FoPost.Posts.create(TestSupport.client(bypass),
                 workspace_id: "ws_1",
                 accounts: ["acc_1"],
                 content: "Hello",
                 files: [%{filename: "chart.png", data: "PNGBYTES"}]
               )
    end

    test "a file over the multipart ceiling goes direct and lands on the first block",
         %{bypass: bypass} do
      path = Path.join(System.tmp_dir!(), "fopost-#{System.unique_integer([:positive])}.mp4")
      File.write!(path, "MP4BYTES")
      on_exit(fn -> File.rm(path) end)

      Bypass.expect_once(bypass, "GET", "/v1/media/limits", fn conn -> limits(conn, 4) end)

      Bypass.expect_once(bypass, "POST", "/v1/media/presign", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(raw)
        assert body["workspaceId"] == "ws_1"
        assert body["filename"] == Path.basename(path)
        assert body["mimeType"] == "video/mp4"
        assert body["size"] == 8

        TestSupport.json(conn, 201, %{"data" => presigned_slot(bypass)})
      end)

      Bypass.expect_once(bypass, "PUT", "/bucket/up_1", fn conn ->
        assert Plug.Conn.get_req_header(conn, "content-length") == ["8"]
        {:ok, "MP4BYTES", conn} = Plug.Conn.read_body(conn)
        Plug.Conn.resp(conn, 200, "")
      end)

      Bypass.expect_once(bypass, "POST", "/v1/media/presign/up_1/complete", fn conn ->
        data = %{
          "id" => "media_1",
          "type" => "video",
          "name" => "clip.mp4",
          "url" => "u",
          "size" => 8
        }

        TestSupport.json(conn, 201, %{"data" => data})
      end)

      Bypass.expect_once(bypass, "POST", "/v1/posts", fn conn ->
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]
        {:ok, raw, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(raw)["content"] == [
                 %{
                   "text" => "Hello",
                   "media" => [
                     %{"type" => "video", "name" => "clip.mp4", "url" => "u", "size" => 8}
                   ]
                 },
                 %{"text" => "Second"}
               ]

        TestSupport.json(conn, 201, %{"data" => %{"id" => "post_1"}})
      end)

      assert {:ok, %FoPost.Post{id: "post_1"}} =
               FoPost.Posts.create(TestSupport.client(bypass),
                 workspace_id: "ws_1",
                 accounts: ["acc_1"],
                 content: ["Hello", "Second"],
                 files: [path]
               )
    end

    test "update without content on the direct route appends to the post's first block",
         %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/v1/media/limits", fn conn -> limits(conn, 4) end)

      Bypass.expect_once(bypass, "GET", "/v1/posts/post_1", fn conn ->
        data = %{
          "id" => "post_1",
          "workspace_id" => "ws_9",
          "content" => [
            %{"text" => "Existing", "media" => [%{"type" => "image", "url" => "old"}]}
          ]
        }

        TestSupport.json(conn, 200, %{"data" => data})
      end)

      Bypass.expect_once(bypass, "POST", "/v1/media/presign", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(raw)["workspaceId"] == "ws_9"
        TestSupport.json(conn, 201, %{"data" => presigned_slot(bypass)})
      end)

      Bypass.expect_once(bypass, "PUT", "/bucket/up_1", fn conn ->
        Plug.Conn.resp(conn, 200, "")
      end)

      Bypass.expect_once(bypass, "POST", "/v1/media/presign/up_1/complete", fn conn ->
        TestSupport.json(conn, 201, %{"data" => %{"id" => "media_1", "url" => "new"}})
      end)

      Bypass.expect_once(bypass, "PUT", "/v1/posts/post_1", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(raw)

        assert [block] = body["content"]
        assert block["text"] == "Existing"

        assert [
                 %{"url" => "old"},
                 %{"type" => "gif", "name" => "a.gif", "url" => "new", "size" => 8}
               ] =
                 block["media"]

        refute Map.has_key?(body, "workspace_id")
        TestSupport.json(conn, 200, %{"data" => %{"id" => "post_1"}})
      end)

      assert {:ok, %FoPost.Post{id: "post_1"}} =
               FoPost.Posts.update(TestSupport.client(bypass), "post_1",
                 files: [%{filename: "a.gif", data: "GIFBYTES"}]
               )
    end

    test "a 413 from the post endpoint surfaces as file_too_large", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/v1/media/limits", fn conn ->
        TestSupport.json(conn, 500, %{"error" => "internal"})
      end)

      Bypass.expect_once(bypass, "POST", "/v1/posts", fn conn ->
        TestSupport.json(conn, 413, %{
          "error" => "file_too_large",
          "message" => "Too big",
          "max_file_bytes" => 104_857_600,
          "file_bytes" => 8
        })
      end)

      assert {:error, %FoPost.Error{status: 413, code: "file_too_large"} = error} =
               FoPost.Posts.create(TestSupport.client(bypass, max_retries: 0),
                 workspace_id: "ws_1",
                 accounts: ["acc_1"],
                 content: "Hello",
                 files: [%{filename: "chart.png", data: "PNGBYTES"}]
               )

      assert error.body["max_file_bytes"] == 104_857_600
    end
  end
end

defmodule FoPost.PostsUnpublishTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "unpublish posts and decodes one row per network", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/posts/post_1/unpublish", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => %{
          "post_status" => "unpublished",
          "deliveries" => [
            %{"account_id" => "acc_1", "platform" => "twitter", "removed" => true},
            %{"account_id" => "acc_2", "platform" => "linkedin", "removed" => false}
          ]
        }
      })
    end)

    assert {:ok, result} = FoPost.Posts.unpublish(TestSupport.client(bypass), "post_1")
    assert %FoPost.UnpublishResult{post_status: "unpublished"} = result

    assert [%FoPost.UnpublishDelivery{removed: true}, %{platform: "linkedin", removed: false}] =
             result.deliveries
  end
end
