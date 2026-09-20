defmodule FoPost.AdsNetworksTest do
  @moduledoc """
  A second ad network behind the same endpoints.
  """

  use ExUnit.Case, async: true

  alias FoPost.Ads
  alias FoPost.TestSupport

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  test "authorize reaches whichever network the registry named", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads/connections/linkedin/authorize", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"workspaceId" => "ws_1", "returnTo" => "/ads"}

      TestSupport.json(conn, 200, %{"data" => %{"url" => "https://www.linkedin.com/oauth"}})
    end)

    client = TestSupport.client(bypass)
    opts = [workspace_id: "ws_1", return_to: "/ads"]

    assert {:ok, "https://www.linkedin.com/oauth"} = Ads.authorize(client, "linkedin", opts)
  end

  test "providers carry what each network supports", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/ads/providers", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "id" => "linkedin",
            "name" => "LinkedIn Ads",
            "configured" => false,
            "capabilities" => %{"conversions" => true},
            "targetingFacets" => ["country", "job_title"],
            "trackingMacros" => [
              %{"token" => "{{LINKEDIN_CAMPAIGN_ID}}", "description" => "Campaign"}
            ]
          }
        ]
      })
    end)

    assert {:ok, [provider]} = Ads.providers(TestSupport.client(bypass))
    assert provider.id == "linkedin"
    refute provider.configured
    assert provider.capabilities["conversions"]
    assert provider.targeting_facets == ["country", "job_title"]
    assert hd(provider.tracking_macros).token == "{{LINKEDIN_CAMPAIGN_ID}}"
  end

  test "company rows travel with the request", %{bypass: bypass} do
    path = "/v1/ads/audiences/urn%3Ali%3AadSegment%3A44/companies"

    Bypass.expect_once(bypass, "POST", path, fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "companies" => [
                 %{"domain" => "northwind.example"},
                 %{"name" => "Contoso"}
               ]
             }

      TestSupport.json(conn, 200, %{"data" => %{"added" => 2}})
    end)

    opts = [
      workspace_id: "ws_1",
      connection_id: "conn_1",
      companies: [%{domain: "northwind.example"}, %{name: "Contoso"}]
    ]

    assert {:ok, 2} =
             Ads.add_audience_companies(TestSupport.client(bypass), "urn:li:adSegment:44", opts)
  end

  test "conversion events send the identity the API hashes", %{bypass: bypass} do
    path = "/v1/ads/linkedin/conversion-rules/urn%3Ali%3Aconversion%3A9/events"

    Bypass.expect_once(bypass, "POST", path, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["connection_id"] == "conn_1"

      TestSupport.json(conn, 200, %{"data" => %{"accepted" => 1}})
    end)

    opts = [
      workspace_id: "ws_1",
      connection_id: "conn_1",
      events: [%{happenedAt: 1_758_326_400_000, email: "buyer@example.test"}]
    ]

    assert {:ok, 1} =
             Ads.send_conversion_events(TestSupport.client(bypass), "urn:li:conversion:9", opts)
  end
end
