defmodule FoPost.GoogleAdsTest do
  use ExUnit.Case, async: true

  alias FoPost.Ads
  alias FoPost.GoogleAds
  alias FoPost.TestSupport

  @scope [workspace_id: "ws_1", connection_id: "conn_1", customer_id: "1234567890"]

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "keywords name the connection and the customer", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/ads/google/keywords", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      assert conn.query_params["connection_id"] == "conn_1"
      assert conn.query_params["customer_id"] == "1234567890"
      assert conn.query_params["ad_group_id"] == "1234567890~adGroup~77"

      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "id" => "1234567890~keyword~77~99",
            "adGroupId" => "1234567890~adGroup~77",
            "text" => "running shoes",
            "matchType" => "EXACT",
            "status" => "ENABLED",
            "cpcBidMinor" => 180,
            "negative" => false
          }
        ]
      })
    end)

    assert {:ok, [keyword]} =
             GoogleAds.keywords(
               TestSupport.client(bypass),
               @scope ++ [ad_group_id: "1234567890~adGroup~77"]
             )

    assert keyword.text == "running shoes"
    assert keyword.cpc_bid_minor == 180
  end

  test "create_keyword sends a camelCase body", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads/google/keywords", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(raw)

      assert body["customerId"] == "1234567890"
      assert body["adGroupId"] == "1234567890~adGroup~77"
      assert body["matchType"] == "EXACT"
      refute Map.has_key?(body, "ad_group_id")

      TestSupport.json(conn, 201, %{"data" => %{"id" => "1234567890~keyword~77~99"}})
    end)

    assert {:ok, "1234567890~keyword~77~99"} =
             GoogleAds.create_keyword(
               TestSupport.client(bypass),
               @scope ++
                 [
                   ad_group_id: "1234567890~adGroup~77",
                   text: "running shoes",
                   match_type: "EXACT"
                 ]
             )
  end

  test "delete carries the scope in the body", %{bypass: bypass} do
    Bypass.expect_once(bypass, "DELETE", "/v1/ads/google/assets/1234567890~asset~4321", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "workspaceId" => "ws_1",
               "connectionId" => "conn_1",
               "customerId" => "1234567890"
             }

      TestSupport.json(conn, 200, %{"data" => nil})
    end)

    assert :ok =
             GoogleAds.delete_asset(
               TestSupport.client(bypass),
               "1234567890~asset~4321",
               @scope
             )
  end

  test "set_ad_schedule replaces the schedule with PUT", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PUT", "/v1/ads/google/ad-schedule", fn conn ->
      TestSupport.json(conn, 200, %{"data" => %{"slots" => 2}})
    end)

    assert {:ok, 2} =
             GoogleAds.set_ad_schedule(
               TestSupport.client(bypass),
               @scope ++
                 [
                   campaign_id: "1234567890~campaign~55",
                   slots: [%{dayOfWeek: "MONDAY", startHour: 9, endHour: 18}]
                 ]
             )
  end

  test "query answers the rows as Google sends them", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads/insights/query", fn conn ->
      TestSupport.json(conn, 200, %{"data" => %{"rows" => [%{"campaign" => %{"id" => "55"}}]}})
    end)

    assert {:ok, [%{"campaign" => %{"id" => "55"}}]} =
             GoogleAds.query(
               TestSupport.client(bypass),
               @scope ++ [query: "SELECT campaign.id FROM campaign"]
             )
  end

  test "authorize_google has its own route", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads/connections/google/authorize", fn conn ->
      TestSupport.json(conn, 200, %{"data" => %{"url" => "https://accounts.google.com/o/x"}})
    end)

    assert {:ok, "https://accounts.google.com/o/x"} =
             Ads.authorize_google(TestSupport.client(bypass), workspace_id: "ws_1")
  end
end
