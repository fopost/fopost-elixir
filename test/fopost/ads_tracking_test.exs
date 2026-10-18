defmodule FoPost.AdsTrackingTest do
  use ExUnit.Case, async: true

  alias FoPost.Ads
  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  @scope [workspace_id: "ws_1", connection_id: "conn_1", ad_account_id: "act_1"]

  test "sends pixel conversions with the idempotency key as a header", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads/conversions/events", fn conn ->
      assert Plug.Conn.get_req_header(conn, "idempotency-key") == ["order-55"]
      assert Plug.Conn.get_req_header(conn, "x-api-key") == ["fp_test_key"]

      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(raw)
      assert body["pixelId"] == "px_1"
      assert hd(body["events"])["actionSource"] == "website"

      conn
      |> Plug.Conn.put_resp_header("idempotency-replayed", "true")
      |> TestSupport.json(202, %{
        "data" => %{"id" => "cb_1", "accepted" => 1, "eventCount" => 1, "replayed" => true}
      })
    end)

    assert {:ok, result} =
             Ads.send_pixel_conversions(
               TestSupport.client(bypass),
               "order-55",
               @scope ++
                 [
                   pixel_id: "px_1",
                   events: [
                     %{
                       eventName: "Purchase",
                       occurredAt: "2026-10-18T10:04:00Z",
                       eventId: "order-55",
                       actionSource: "website",
                       email: "buyer@yourbrand.com",
                       valueMinor: 4_900,
                       currency: "USD"
                     }
                   ]
                 ]
             )

    assert result.id == "cb_1"
    assert result.accepted == 1
    assert result.replayed == true
  end

  test "upload_conversions sends no idempotency header unless given", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads/conversions", fn conn ->
      assert Plug.Conn.get_req_header(conn, "idempotency-key") == []
      TestSupport.json(conn, 202, %{"data" => %{"id" => "cb_2", "accepted" => 1}})
    end)

    assert {:ok, %{accepted: 1, replayed: false}} =
             Ads.upload_conversions(
               TestSupport.client(bypass),
               @scope ++ [pixel_id: "px_1", events: [%{eventName: "Lead"}]]
             )
  end

  test "lists conversion batches with hashed events", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/ads/conversions/events", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["limit"] == "5"

      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "id" => "cb_1",
            "pixelId" => "px_1",
            "idempotencyKey" => "order-55",
            "eventCount" => 1,
            "accepted" => 1,
            "createdAt" => "2026-10-18T10:05:00.000Z",
            "events" => [
              %{"eventName" => "Purchase", "emailHash" => "ab12", "valueMinor" => 4900}
            ]
          }
        ]
      })
    end)

    assert {:ok, [batch]} =
             Ads.conversion_batches(TestSupport.client(bypass), workspace_id: "ws_1", limit: 5)

    assert batch.idempotency_key == "order-55"
    assert %DateTime{} = batch.created_at
    assert [%{email_hash: "ab12", value_minor: 4900}] = batch.events
  end

  test "reads a pixel with its code, stats and match quality", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/ads/pixels/px_1", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["ad_account_id"] == "act_1"
      assert conn.query_params["connection_id"] == "conn_1"

      TestSupport.json(conn, 200, %{
        "data" => %{
          "id" => "px_1",
          "name" => "Site",
          "code" => "<script>fbq('init', 'px_1');</script>",
          "createdAt" => "2026-09-01T00:00:00.000Z",
          "lastFiredAt" => nil,
          "isUnavailable" => false,
          "dataUseSetting" => "advertising_and_analytics"
        }
      })
    end)

    Bypass.expect_once(bypass, "GET", "/v1/ads/pixels/px_1/stats", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => %{
          "since" => "2026-09-20T00:00:00.000Z",
          "until" => "2026-10-18T00:00:00.000Z",
          "events" => [%{"eventName" => "PageView", "count" => 120}]
        }
      })
    end)

    Bypass.expect_once(bypass, "GET", "/v1/ads/pixels/px_1/match-quality", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "eventName" => "Purchase",
            "score" => 7.5,
            "matchKeys" => [%{"identifier" => "em", "coveragePercent" => 98.2}]
          }
        ]
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, pixel} = Ads.pixel(client, "px_1", @scope)
    assert pixel.name == "Site"
    assert pixel.code =~ "fbq"
    assert pixel.data_use_setting == "advertising_and_analytics"
    assert pixel.last_fired_at == nil

    assert {:ok, stats} = Ads.pixel_stats(client, "px_1", @scope)
    assert [%{event_name: "PageView", count: 120}] = stats.events

    assert {:ok, [quality]} = Ads.event_match_quality(client, "px_1", @scope)
    assert quality.score == 7.5
    assert [%{identifier: "em", coverage_percent: 98.2}] = quality.match_keys
  end

  test "shares a pixel and answers :ok on a 204", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads/pixels/px_1/share", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw)["targetAdAccountId"] == "act_2"
      Plug.Conn.resp(conn, 204, "")
    end)

    assert :ok =
             Ads.share_pixel(
               TestSupport.client(bypass),
               "px_1",
               @scope ++ [target_ad_account_id: "act_2"]
             )
  end

  test "creates and deletes a custom conversion", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads/custom-conversions", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(raw)
      assert body["pixelId"] == "px_1"
      assert body["eventType"] == "PURCHASE"
      assert body["rule"] == %{"eventName" => "PageView", "urlContains" => "/thank-you"}
      assert body["defaultValueMinor"] == 4_900

      TestSupport.json(conn, 201, %{
        "data" => %{
          "id" => "cc_1",
          "name" => "Checkout",
          "pixelId" => "px_1",
          "eventType" => "PURCHASE",
          "rule" => %{"eventName" => "PageView", "urlContains" => "/thank-you"},
          "defaultValueMinor" => 4_900,
          "isArchived" => false,
          "isUnavailable" => false,
          "createdAt" => "2026-10-18T10:00:00.000Z"
        }
      })
    end)

    Bypass.expect_once(bypass, "DELETE", "/v1/ads/custom-conversions/cc_1", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw)["adAccountId"] == "act_1"
      Plug.Conn.resp(conn, 204, "")
    end)

    client = TestSupport.client(bypass)

    assert {:ok, conversion} =
             Ads.create_custom_conversion(
               client,
               @scope ++
                 [
                   pixel_id: "px_1",
                   name: "Checkout",
                   event_type: "PURCHASE",
                   rule: %{eventName: "PageView", urlContains: "/thank-you"},
                   default_value_minor: 4_900
                 ]
             )

    assert conversion.id == "cc_1"
    assert conversion.rule.url_contains == "/thank-you"
    assert conversion.is_archived == false

    assert :ok = Ads.delete_custom_conversion(client, "cc_1", @scope)
  end
end
