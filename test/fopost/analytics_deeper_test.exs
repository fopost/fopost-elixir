defmodule FoPost.AnalyticsDeeperTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport

  test "decay reads the bands and the half life" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "GET", "/v1/analytics/decay", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"days" => "30", "accountId" => "acc_1"}

      data = %{
        "days" => 30,
        "postsMeasured" => 2,
        "halfLifeBucket" => "1h_3h",
        "bands" => [
          %{
            "bucket" => "under_1h",
            "label" => "First hour",
            "posts" => 2,
            "avgEngagements" => 25,
            "avgImpressions" => 300,
            "shareOfFinal" => 0.3
          },
          %{
            "bucket" => "6h_12h",
            "label" => "6-12 hours",
            "posts" => 0,
            "avgEngagements" => 0,
            "avgImpressions" => 0,
            "shareOfFinal" => nil
          }
        ]
      }

      TestSupport.json(conn, 200, %{"data" => data})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, decay} = FoPost.Analytics.decay(client, days: 30, account_id: "acc_1")
    assert decay.half_life_bucket == "1h_3h"
    assert decay.posts_measured == 2
    assert hd(decay.bands).share_of_final == 0.3
    # A band nothing was measured in reports no share rather than zero
    assert List.last(decay.bands).share_of_final == nil
  end

  test "frequency reads the weeks and the best cadence" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "GET", "/v1/analytics/frequency", fn conn ->
      data = %{
        "days" => 90,
        "weeks" => [
          %{
            "weekStart" => "2026-03-02",
            "posts" => 2,
            "engagements" => 240,
            "avgEngagementsPerPost" => 120
          }
        ],
        "bands" => [
          %{
            "band" => "under_3",
            "label" => "1-2 a week",
            "weeks" => 1,
            "posts" => 2,
            "avgPostsPerWeek" => 2,
            "avgEngagementsPerPost" => 120,
            "engagementRate" => 0.12
          }
        ],
        "best" => %{
          "band" => "under_3",
          "label" => "1-2 a week",
          "avgEngagementsPerPost" => 120
        }
      }

      TestSupport.json(conn, 200, %{"data" => data})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, cadence} = FoPost.Analytics.frequency(client, days: 90)
    assert hd(cadence.weeks).week_start == "2026-03-02"
    assert hd(cadence.bands).engagement_rate == 0.12
    assert cadence.best.label == "1-2 a week"
  end

  test "a timeline can be addressed by permalink" do
    bypass = Bypass.open()

    path = "/v1/analytics/posts/https%3A%2F%2Fx.com%2Facme%2Fstatus%2F1/timeline"

    Bypass.expect_once(bypass, "GET", path, fn conn ->
      data = %{
        "postId" => nil,
        "deliveries" => [
          %{
            "accountId" => "acc_1",
            "platform" => "twitter",
            "username" => "acme",
            "externalPostId" => "1",
            "postedAt" => "2026-03-02T00:00:00.000Z",
            "points" => [
              %{
                "at" => "2026-03-02T00:30:00.000Z",
                "ageMinutes" => 30,
                "engagements" => 40,
                "impressions" => 400,
                "reach" => nil,
                "likes" => 30,
                "comments" => nil,
                "shares" => nil,
                "videoViews" => nil,
                "delta" => %{
                  "impressions" => 400,
                  "reach" => 0,
                  "engagements" => 40,
                  "likes" => 30,
                  "comments" => 0,
                  "shares" => 0
                }
              }
            ]
          }
        ]
      }

      TestSupport.json(conn, 200, %{"data" => data})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, timeline} = FoPost.Analytics.timeline(client, "https://x.com/acme/status/1")
    # A post made on the network has no FoPost id
    assert timeline.post_id == nil
    point = hd(hd(timeline.deliveries).points)
    assert point.age_minutes == 30
    assert point.delta.engagements == 40
  end

  test "changes carries the cursor" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "GET", "/v1/analytics/changes", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["since"] == "2026-03-02T00:00:00Z"
      assert conn.query_params["limit"] == "100"

      data = %{
        "since" => "2026-03-02T00:00:00.000Z",
        "cursor" => "2026-03-02T06:00:00.000Z",
        "hasMore" => true,
        "changes" => [
          %{
            "accountId" => "acc_1",
            "platform" => "twitter",
            "externalPostId" => "1",
            "postId" => "post_1",
            "postedAt" => "2026-03-02T00:00:00.000Z",
            "fetchedAt" => "2026-03-02T06:00:00.000Z",
            "impressions" => 900,
            "reach" => nil,
            "engagements" => 90,
            "likes" => 70,
            "comments" => 10,
            "shares" => 10
          }
        ]
      }

      TestSupport.json(conn, 200, %{"data" => data})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, page} =
             FoPost.Analytics.changes(client, since: "2026-03-02T00:00:00Z", limit: 100)

    assert page.has_more
    assert hd(page.changes).post_id == "post_1"
  end

  test "collect_post reports each delivery" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/v1/posts/post_1/analytics/collect", fn conn ->
      data = %{
        "collected" => 1,
        "deliveries" => [
          %{
            "accountId" => "acc_1",
            "platform" => "twitter",
            "externalPostId" => "1",
            "collected" => true,
            "fetchedAt" => "2026-03-02T00:30:00.000Z",
            "message" => nil
          }
        ]
      }

      TestSupport.json(conn, 200, %{"data" => data})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, result} = FoPost.Analytics.collect_post(client, "post_1")
    assert result.collected == 1
    assert hd(result.deliveries).collected
  end

  test "native_posts keeps the meta envelope" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/native-posts", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"page" => "1", "per_page" => "20"}

      body = %{
        "data" => [
          %{
            "externalPostId" => "1",
            "text" => "Posted by hand",
            "permalink" => "https://x.com/acme/status/1",
            "thumbnailUrl" => nil,
            "mediaType" => nil,
            "postedAt" => "2026-03-02T00:00:00.000Z",
            "fetchedAt" => "2026-03-02T06:00:00.000Z",
            "metrics" => %{
              "impressions" => 900,
              "reach" => nil,
              "engagements" => 90,
              "likes" => 70,
              "comments" => 10,
              "shares" => 10,
              "videoViews" => nil
            }
          }
        ],
        "meta" => %{"page" => 1, "perPage" => 20, "total" => 1}
      }

      TestSupport.json(conn, 200, body)
    end)

    client = TestSupport.client(bypass)

    assert {:ok, page} = FoPost.Analytics.native_posts(client, "acc_1", page: 1, per_page: 20)
    assert length(page.data) == 1
    assert hd(page.data).permalink == "https://x.com/acme/status/1"
    assert hd(page.data).metrics["engagements"] == 90
    assert page.meta.total == 1
  end
end
