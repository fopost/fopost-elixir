defmodule FoPost.AdsTest do
  use ExUnit.Case, async: true

  alias FoPost.Ads
  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "boost sends a camelCase body and decodes the ad", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads/boost", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(raw)

      assert body["workspaceId"] == "ws_1"
      assert body["connectionId"] == "conn_1"
      assert body["adAccountId"] == "act_123"
      assert body["postId"] == "post_1"
      assert body["accountId"] == "acc_1"
      assert body["budget"] == %{"minor" => 5000, "type" => "daily"}
      assert body["targeting"]["countries"] == ["US"]
      assert body["paused"] == false
      refute Map.has_key?(body, "workspace_id")

      TestSupport.json(conn, 201, %{
        "data" => %{
          "id" => "ad_1",
          "workspaceId" => "ws_1",
          "kind" => "boost",
          "name" => "Launch week",
          "goal" => "engagement",
          "status" => "active",
          "adAccountId" => "act_123",
          "budgetMinor" => 5000,
          "budgetType" => "daily",
          "targeting" => %{"countries" => ["US"], "ageMin" => 18, "ageMax" => 65},
          "insights" => %{"impressions" => 10, "spendMinor" => 120},
          "createdAt" => "2026-09-01T10:00:00Z"
        }
      })
    end)

    opts = [
      workspace_id: "ws_1",
      connection_id: "conn_1",
      ad_account_id: "act_123",
      post_id: "post_1",
      account_id: "acc_1",
      name: "Launch week",
      goal: "engagement",
      budget: %{minor: 5000, type: "daily"},
      targeting: %{countries: ["US"], ageMin: 18, ageMax: 65, gender: "all"},
      paused: false
    ]

    assert {:ok, ad} = Ads.boost(TestSupport.client(bypass), opts)
    assert ad.id == "ad_1"
    assert ad.kind == "boost"
    assert ad.budget_minor == 5000
    assert ad.targeting.countries == ["US"]
    assert ad.targeting.age_min == 18
    assert ad.insights.spend_minor == 120
    assert ad.created_at == ~U[2026-09-01 10:00:00Z]
  end

  test "set_status patches with workspace_id in the query", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PATCH", "/v1/ads/ad_1", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"workspace_id" => "ws_1"}

      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"status" => "paused"}

      TestSupport.json(conn, 200, %{"data" => %{"id" => "ad_1", "status" => "paused"}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, ad} = Ads.set_status(client, "ad_1", workspace_id: "ws_1", status: "paused")
    assert ad.status == "paused"
  end

  test "delete sends workspace_id in the query and reads the message", %{bypass: bypass} do
    Bypass.expect_once(bypass, "DELETE", "/v1/ads/ad_1", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"workspace_id" => "ws_1"}

      TestSupport.json(conn, 200, %{"message" => "Ad deleted"})
    end)

    assert {:ok, message} = Ads.delete(TestSupport.client(bypass), "ad_1", workspace_id: "ws_1")
    assert message.message == "Ad deleted"
  end

  test "authorize names its ad network in the path", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads/connections/pinterest/authorize", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"workspaceId" => "ws_1"}

      TestSupport.json(conn, 200, %{"data" => %{"url" => "https://www.pinterest.com/oauth/"}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, "https://www.pinterest.com/oauth/"} =
             Ads.authorize(client, workspace_id: "ws_1", provider: "pinterest")
  end

  test "authorize_meta answers the login URL", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads/connections/meta/authorize", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "workspaceId" => "ws_1",
               "returnTo" => "https://yourbrand.com"
             }

      TestSupport.json(conn, 200, %{"data" => %{"url" => "https://login.example/oauth"}})
    end)

    client = TestSupport.client(bypass)
    opts = [workspace_id: "ws_1", return_to: "https://yourbrand.com"]

    assert {:ok, "https://login.example/oauth"} = Ads.authorize(client, opts)
  end

  test "audiences requires the connection and ad account in the query", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/ads/audiences", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"connection_id" => "conn_1", "ad_account_id" => "act_123"}

      TestSupport.json(conn, 200, %{
        "data" => %{
          "audiences" => [%{"id" => "aud_1", "name" => "Buyers", "subtype" => "CUSTOM"}],
          "pixels" => [%{"id" => "px_1", "name" => "Site"}],
          "workspaceId" => "ws_1"
        }
      })
    end)

    client = TestSupport.client(bypass)
    opts = [connection_id: "conn_1", ad_account_id: "act_123"]

    assert {:ok, result} = Ads.audiences(client, opts)
    assert [audience] = result.audiences
    assert audience.subtype == "CUSTOM"
    assert result.pixels == [%{"id" => "px_1", "name" => "Site"}]
    assert result.workspace_id == "ws_1"
  end

  test "leads pages by cursor", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/ads/lead-forms/form_1/leads", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      assert conn.query_params == %{
               "connection_id" => "conn_1",
               "page_id" => "page_1",
               "after" => "cur_1"
             }

      TestSupport.json(conn, 200, %{
        "data" => %{
          "leads" => [
            %{
              "id" => "lead_1",
              "createdAt" => "2026-09-01T10:00:00Z",
              "fields" => [%{"name" => "full_name", "values" => ["Jordan Reyes"]}],
              "isOrganic" => false
            }
          ],
          "nextCursor" => nil
        }
      })
    end)

    client = TestSupport.client(bypass)
    opts = [connection_id: "conn_1", page_id: "page_1", after: "cur_1"]

    assert {:ok, page} = Ads.leads(client, "form_1", opts)
    assert [lead] = page.leads
    assert lead.created_at == ~U[2026-09-01 10:00:00Z]
    assert [%{"name" => "full_name"}] = lead.fields
    assert is_nil(page.next_cursor)
  end

  test "account_tree nests campaigns, ad sets, and ads", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/ads/accounts/act_123/tree", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"workspace_id" => "ws_1", "connection_id" => "conn_1"}

      ad = %{"id" => "a_1", "creativeId" => "cr_1", "status" => "PAUSED"}
      ad_set = %{"id" => "s_1", "name" => "US", "budgetMinor" => 500, "ads" => [ad]}

      TestSupport.json(conn, 200, %{
        "data" => %{
          "adAccountId" => "act_123",
          "currency" => "USD",
          "campaigns" => [%{"id" => "c_1", "name" => "Spring", "adSets" => [ad_set]}]
        }
      })
    end)

    client = TestSupport.client(bypass)
    opts = [workspace_id: "ws_1", connection_id: "conn_1"]

    assert {:ok, tree} = Ads.account_tree(client, "act_123", opts)
    assert tree.currency == "USD"
    assert [campaign] = tree.campaigns
    assert [ad_set] = campaign.ad_sets
    assert ad_set.budget_minor == 500
    assert [%{creative_id: "cr_1"}] = ad_set.ads
  end

  test "duplicate_campaign posts paused and answers the copy's id", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads/campaigns/c_1/duplicate", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"workspace_id" => "ws_1", "connection_id" => "conn_1"}

      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"paused" => true}

      TestSupport.json(conn, 201, %{"data" => %{"id" => "c_2"}})
    end)

    client = TestSupport.client(bypass)
    opts = [workspace_id: "ws_1", connection_id: "conn_1", paused: true]

    assert {:ok, "c_2"} = Ads.duplicate_campaign(client, "c_1", opts)
  end

  test "bulk_set_status sends the objects and decodes each result", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads/status", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(raw)

      assert body["status"] == "paused"
      assert body["objects"] == [%{"id" => "c_1", "level" => "campaign"}]

      TestSupport.json(conn, 200, %{
        "data" => [%{"id" => "c_1", "level" => "campaign", "ok" => false, "error" => "Denied"}]
      })
    end)

    opts = [
      workspace_id: "ws_1",
      connection_id: "conn_1",
      status: "paused",
      objects: [%{id: "c_1", level: "campaign"}]
    ]

    assert {:ok, [result]} = Ads.bulk_set_status(TestSupport.client(bypass), opts)
    assert result.ok == false
    assert result.error == "Denied"
  end

  test "leads_feed passes the cursor and answers the next one", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/ads/leads", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      assert conn.query_params == %{
               "workspace_id" => "ws_1",
               "form_id" => "form_1",
               "cursor" => "cur_1",
               "limit" => "50"
             }

      TestSupport.json(conn, 200, %{
        "data" => %{
          "leads" => [
            %{
              "id" => "l_1",
              "leadId" => "meta_1",
              "submittedAt" => "2026-09-01T10:00:00Z",
              "fields" => [%{"name" => "email", "values" => ["a@yourbrand.com"]}]
            }
          ],
          "nextCursor" => "cur_2"
        }
      })
    end)

    client = TestSupport.client(bypass)
    opts = [workspace_id: "ws_1", form_id: "form_1", cursor: "cur_1", limit: 50]

    assert {:ok, page} = Ads.leads_feed(client, opts)
    assert [lead] = page.leads
    assert lead.lead_id == "meta_1"
    assert lead.submitted_at == ~U[2026-09-01 10:00:00Z]
    assert page.next_cursor == "cur_2"
  end

  test "insights sends the range, breakdown, and daily flag", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/ads/insights", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      assert conn.query_params == %{
               "connection_id" => "conn_1",
               "object_id" => "c_1",
               "since" => "2026-09-01",
               "until" => "2026-09-07",
               "breakdown" => "age",
               "daily" => "true"
             }

      TestSupport.json(conn, 200, %{
        "data" => %{
          "objectId" => "c_1",
          "since" => "2026-09-01",
          "until" => "2026-09-07",
          "breakdownBy" => "age",
          "totals" => %{"impressions" => 10, "spendMinor" => 99, "ctr" => 1.5},
          "breakdown" => [%{"key" => "18-24", "metrics" => %{"clicks" => 2}}],
          "timeline" => [%{"date" => "2026-09-01", "metrics" => %{"reach" => 7}}]
        }
      })
    end)

    opts = [
      connection_id: "conn_1",
      object_id: "c_1",
      since: "2026-09-01",
      until: "2026-09-07",
      breakdown: "age",
      daily: true
    ]

    assert {:ok, report} = Ads.insights(TestSupport.client(bypass), opts)
    assert report.object_id == "c_1"
    assert report.breakdown_by == "age"
    assert report.totals.spend_minor == 99
    assert [%{key: "18-24", metrics: %{clicks: 2}}] = report.breakdown
    assert [%{date: "2026-09-01", metrics: %{reach: 7}}] = report.timeline
  end

  test "create sends url_tags", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw)["urlTags"] == "utm_source=meta"

      TestSupport.json(conn, 201, %{
        "data" => %{"id" => "ad_1", "creative" => %{"urlTags" => "utm_source=meta"}}
      })
    end)

    opts = [
      workspace_id: "ws_1",
      connection_id: "conn_1",
      ad_account_id: "act_123",
      page_id: "42",
      name: "Tagged",
      goal: "traffic",
      budget: %{minor: 5000, type: "daily"},
      targeting: %{countries: ["US"]},
      text: "Hi",
      url_tags: "utm_source=meta"
    ]

    assert {:ok, ad} = Ads.create(TestSupport.client(bypass), opts)
    assert ad.creative["url_tags"] == "utm_source=meta"
  end
end
