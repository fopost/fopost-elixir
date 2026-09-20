defmodule FoPost.KnowledgeTest do
  use ExUnit.Case, async: true

  alias FoPost.Knowledge
  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  defp source do
    %{
      "id" => "know_1",
      "kind" => "url",
      "title" => "Refund policy",
      "status" => "ready",
      "statusMessage" => nil,
      "url" => "https://yourbrand.com/help/refunds",
      "mediaId" => nil,
      "brandVoiceId" => nil,
      "chunkCount" => 3,
      "content" => nil,
      "lastSyncedAt" => "2026-09-20T00:00:00Z",
      "createdAt" => "2026-09-19T00:00:00Z",
      "updatedAt" => "2026-09-20T00:00:00Z"
    }
  end

  test "list sends the workspace filter and reads the camelCase fields", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/knowledge/sources", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"workspace_id" => "ws_1"}
      TestSupport.json(conn, 200, %{"data" => [source()]})
    end)

    assert {:ok, [item]} = Knowledge.list(TestSupport.client(bypass), workspace_id: "ws_1")
    assert item.id == "know_1"
    assert item.status == "ready"
    assert item.chunk_count == 3
    assert item.status_message == nil
    assert item.last_synced_at == ~U[2026-09-20 00:00:00Z]
  end

  test "create sends a snake_case body, omitting what the kind does not use", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/knowledge/sources", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "kind" => "file",
               "title" => "Price list",
               "media_id" => "media_1",
               "workspace_id" => "ws_1"
             }

      TestSupport.json(conn, 200, %{"data" => source()})
    end)

    assert {:ok, %FoPost.KnowledgeSource{}} =
             Knowledge.create(TestSupport.client(bypass),
               kind: "file",
               title: "Price list",
               media_id: "media_1",
               workspace_id: "ws_1"
             )
  end

  test "update patches only the keys that were given", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PATCH", "/v1/knowledge/sources/know_1", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"title" => "Refunds"}
      TestSupport.json(conn, 200, %{"data" => source()})
    end)

    assert {:ok, %FoPost.KnowledgeSource{}} =
             Knowledge.update(TestSupport.client(bypass), "know_1", title: "Refunds")
  end

  test "search sends top_k with the question and reads the matches", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/knowledge/search", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"q" => "refunds", "top_k" => "3"}

      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "sourceId" => "know_1",
            "sourceTitle" => "Refund policy",
            "sourceKind" => "url",
            "sourceUrl" => "https://yourbrand.com/help/refunds",
            "text" => "We refund within 30 days.",
            "score" => 0.82
          }
        ]
      })
    end)

    assert {:ok, [match]} = Knowledge.search(TestSupport.client(bypass), "refunds", top_k: 3)
    assert match.source_title == "Refund policy"
    assert match.score == 0.82
  end

  test "sync posts to the source's own sync path", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/knowledge/sources/know_1/sync", fn conn ->
      TestSupport.json(conn, 200, %{"data" => %{"id" => "know_1", "status" => "pending"}})
    end)

    assert {:ok, queued} = Knowledge.sync(TestSupport.client(bypass), "know_1")
    assert queued.status == "pending"
  end
end
