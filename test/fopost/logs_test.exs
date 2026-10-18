defmodule FoPost.LogsTest do
  use ExUnit.Case, async: true

  alias FoPost.Logs
  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "list filters, keeps meta and summary, and decodes each row", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/logs", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      assert conn.query_params == %{
               "workspace_id" => "ws_1",
               "status" => "error",
               "limit" => "50",
               "before" => "900"
             }

      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "id" => 899,
            "workspace_id" => "ws_1",
            "time" => "2026-10-18T10:00:00Z",
            "auth_method" => "api_key",
            "method" => "POST",
            "route" => "/v1/posts/{id}/publish",
            "path" => "/v1/posts/post_1/publish",
            "status_code" => 402,
            "duration_ms" => 31,
            "platform" => nil,
            "message" => "Balance ran out"
          }
        ],
        "meta" => %{"next_cursor" => "898", "has_more" => true},
        "summary" => %{
          "since" => "2026-10-11T10:00:00Z",
          "total" => 120,
          "errors" => 3,
          "buckets" => [%{"at" => "2026-10-18T00:00:00Z", "total" => 20, "errors" => 1}]
        }
      })
    end)

    assert {:ok, page} =
             Logs.list(TestSupport.client(bypass),
               workspace_id: "ws_1",
               status: "error",
               limit: 50,
               before: 900
             )

    assert [%FoPost.LogEntry{id: 899, status_code: 402} = entry] = page.data
    assert entry.route == "/v1/posts/{id}/publish"
    assert entry.time == ~U[2026-10-18 10:00:00Z]
    assert page.next_cursor == "898"
    assert page.has_more == true
    assert page.summary.total == 120
    assert [%FoPost.LogBucket{errors: 1}] = page.summary.buckets
  end
end
