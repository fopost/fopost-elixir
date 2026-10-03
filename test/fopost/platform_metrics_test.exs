defmodule FoPost.PlatformMetricsTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  @facebook_set %{
    "platform" => "facebook",
    "account" => %{
      "fetched_at" => "2026-09-20T02:00:00.000Z",
      "metrics" => [
        %{
          "key" => "page_daily_video_ad_break_earnings",
          "label" => "Ad Break Earnings",
          "kind" => "currency_usd",
          "value" => 42.15
        },
        %{
          "key" => "page_impressions_paid",
          "label" => "Paid Impressions",
          "kind" => "count",
          "value" => 1500
        }
      ]
    },
    "post" => %{
      "external_post_id" => "123_456",
      "fetched_at" => "2026-09-20T02:00:00.000Z",
      "metrics" => []
    }
  }

  test "platform_metrics asks for raw and reads the set", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/insights", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"raw" => "true"}
      TestSupport.json(conn, 200, %{"data" => @facebook_set})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, metrics} = FoPost.Accounts.platform_metrics(client, "acc_1")
    assert metrics.platform == "facebook"
    assert metrics.account.fetched_at == "2026-09-20T02:00:00.000Z"

    assert Enum.map(metrics.account.metrics, & &1.key) == [
             "page_daily_video_ad_break_earnings",
             "page_impressions_paid"
           ]

    assert FoPost.PlatformMetricRow.number(hd(metrics.account.metrics)) == 42.15
    assert metrics.post.external_post_id == "123_456"
    assert metrics.post.metrics == []
  end

  test "a series value survives as a list", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/insights", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => %{
          "platform" => "youtube",
          "account" => %{
            "fetched_at" => nil,
            "metrics" => [
              %{
                "key" => "daily_views",
                "label" => "Views by Day",
                "kind" => "series",
                "value" => [%{"day" => "2026-09-19", "views" => 600}]
              }
            ]
          },
          "post" => %{"external_post_id" => nil, "fetched_at" => nil, "metrics" => []}
        }
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, metrics} = FoPost.Accounts.platform_metrics(client, "acc_1")
    row = hd(metrics.account.metrics)

    assert FoPost.PlatformMetricRow.number(row) == nil
    assert row.value == [%{"day" => "2026-09-19", "views" => 600}]
    assert metrics.account.fetched_at == nil
  end

  test "a pending metric grant is an error", %{bypass: bypass} do
    Bypass.expect(bypass, "GET", "/v1/accounts/acc_1/insights", fn conn ->
      TestSupport.json(conn, 503, %{
        "error" => "platform_metrics_unavailable",
        "message" => "google-business metrics are not available on this deployment yet."
      })
    end)

    client = TestSupport.client(bypass, max_retries: 1)

    assert {:error, error} = FoPost.Accounts.platform_metrics(client, "acc_1")
    assert error.status == 503
    assert error.code == "platform_metrics_unavailable"
  end
end
