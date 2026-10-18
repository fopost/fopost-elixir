defmodule FoPost.InboxAnalyticsTest do
  use ExUnit.Case, async: true

  alias FoPost.Analytics
  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "inbox sends the window and decodes the report", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/analytics/inbox", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"workspace_id" => "ws_1", "days" => "30", "tz" => "UTC"}

      TestSupport.json(conn, 200, %{
        "data" => %{
          "totals" => %{"received" => 40, "sent" => 12, "median_response_minutes" => 18.5},
          "deltas" => %{"received" => 10.0, "sent" => nil},
          "series" => [%{"date" => "2026-10-18", "received" => 4, "sent" => 1, "answered" => 1}],
          "by_platform" => [%{"platform" => "instagram", "received" => 40, "sent" => 12}],
          "by_type" => [%{"type" => "comment", "count" => 30}],
          "by_account" => [],
          "response_time" => [%{"bucket" => "under_1h", "count" => 9}],
          "heatmap" => [%{"weekday" => 1, "hour" => 9, "count" => 3}],
          "time_zone" => "UTC"
        }
      })
    end)

    assert {:ok, report} =
             Analytics.inbox(TestSupport.client(bypass),
               workspace_id: "ws_1",
               days: 30,
               tz: "UTC"
             )

    assert %FoPost.Analytics.InboxAnalytics{time_zone: "UTC"} = report
    assert report.totals["received"] == 40
    assert report.deltas["sent"] == nil
    assert [%{"type" => "comment", "count" => 30}] = report.by_type
    assert [%{"bucket" => "under_1h"}] = report.response_time
  end
end
