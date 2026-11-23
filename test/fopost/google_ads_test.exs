defmodule FoPost.GoogleAdsTest do
  use ExUnit.Case, async: true

  alias FoPost.Ads
  alias FoPost.GoogleAds
  alias FoPost.TestSupport

  @scope [workspace_id: "ws_1", connection_id: "conn_1", customer_id: "1234567890"]

  setup do
    {:ok, bypass: Bypass.open()}
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
