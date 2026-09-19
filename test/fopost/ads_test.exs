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

    assert {:ok, "https://login.example/oauth"} = Ads.authorize_meta(client, opts)
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
end
