defmodule FoPost.GoogleBusinessTest do
  @moduledoc """
  Business Profile management: one call per route, pinning the method, the path
  and the body each endpoint actually receives.
  """
  use ExUnit.Case, async: true

  alias FoPost.GoogleBusiness
  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "every method maps onto its route", %{bypass: bypass} do
    client = TestSupport.client(bypass)

    # Bypass answers 404 for a path nobody registered, so a wrong route fails
    # the call rather than passing quietly.
    routes = [
      {"GET", "/location", fn -> GoogleBusiness.get_location(client, "acc_1") end},
      {"PATCH", "/location", fn -> GoogleBusiness.update_location(client, "acc_1", %{}) end},
      {"GET", "/attributes", fn -> GoogleBusiness.get_attributes(client, "acc_1") end},
      {"PATCH", "/attributes", fn -> GoogleBusiness.update_attributes(client, "acc_1", []) end},
      {"GET", "/menus", fn -> GoogleBusiness.get_menus(client, "acc_1") end},
      {"PUT", "/menus", fn -> GoogleBusiness.replace_menus(client, "acc_1", []) end},
      {"GET", "/services", fn -> GoogleBusiness.get_services(client, "acc_1") end},
      {"PUT", "/services", fn -> GoogleBusiness.replace_services(client, "acc_1", []) end},
      {"GET", "/media", fn -> GoogleBusiness.list_media(client, "acc_1") end},
      {"POST", "/media", fn -> GoogleBusiness.add_media(client, "acc_1", media_id: "m_1") end},
      {"DELETE", "/media/CAoSL", fn -> GoogleBusiness.delete_media(client, "acc_1", "CAoSL") end},
      {"GET", "/place-actions", fn -> GoogleBusiness.list_place_actions(client, "acc_1") end},
      {"POST", "/place-actions",
       fn ->
         GoogleBusiness.create_place_action(client, "acc_1",
           uri: "https://example.test/book",
           place_action_type: "APPOINTMENT"
         )
       end},
      {"PATCH", "/place-actions/links-1",
       fn ->
         GoogleBusiness.update_place_action(client, "acc_1", "links-1", is_preferred: true)
       end},
      {"DELETE", "/place-actions/links-1",
       fn -> GoogleBusiness.delete_place_action(client, "acc_1", "links-1") end},
      {"GET", "/verification",
       fn -> GoogleBusiness.get_verification_options(client, "acc_1") end},
      {"POST", "/verification/start",
       fn -> GoogleBusiness.start_verification(client, "acc_1", method: "SMS") end},
      {"POST", "/verification/complete",
       fn -> GoogleBusiness.complete_verification(client, "acc_1", "v1", "123456") end},
      {"GET", "/performance",
       fn ->
         GoogleBusiness.get_performance(client, "acc_1",
           start_date: "2026-09-01",
           end_date: "2026-09-07"
         )
       end}
    ]

    for {method, suffix, _call} <- routes do
      Bypass.expect_once(bypass, method, "/v1/accounts/acc_1/gbp#{suffix}", fn conn ->
        TestSupport.json(conn, 200, %{"data" => %{"ok" => true}})
      end)
    end

    for {method, suffix, call} <- routes do
      assert {:ok, %{"ok" => true}} = call.(), "#{method} #{suffix}"
    end
  end

  test "a patch carries only the fields the caller set", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PATCH", "/v1/accounts/acc_1/gbp/location", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"store_code" => "S-12", "description" => nil}
      TestSupport.json(conn, 200, %{"data" => %{}})
    end)

    client = TestSupport.client(bypass)
    fields = %{"store_code" => "S-12", "description" => nil}

    assert {:ok, %{}} = GoogleBusiness.update_location(client, "acc_1", fields)
  end

  test "a photo is named by its library id", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/accounts/acc_1/gbp/media", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"media_id" => "m_1", "category" => "INTERIOR"}
      TestSupport.json(conn, 200, %{"data" => %{}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %{}} =
             GoogleBusiness.add_media(client, "acc_1", media_id: "m_1", category: "INTERIOR")
  end

  test "performance sends the metrics and the range", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/gbp/performance", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["start_date"] == "2026-09-01"
      assert conn.query_params["daily_metrics"] == "CALL_CLICKS,WEBSITE_CLICKS"
      TestSupport.json(conn, 200, %{"data" => %{}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %{}} =
             GoogleBusiness.get_performance(client, "acc_1",
               start_date: "2026-09-01",
               end_date: "2026-09-07",
               daily_metrics: ["CALL_CLICKS", "WEBSITE_CLICKS"]
             )
  end

  test "search keywords asks the same route for the monthly terms", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/gbp/performance", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["keywords"] == "true"
      TestSupport.json(conn, 200, %{"data" => %{}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %{}} =
             GoogleBusiness.get_search_keywords(client, "acc_1",
               start_date: "2026-08-01",
               end_date: "2026-09-01"
             )
  end

  test "assign hands the location to another workspace", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/accounts/acc_1/gbp/assign", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"workspace_id" => "ws_2"}
      TestSupport.json(conn, 200, %{"data" => %{"id" => "acc_1", "workspace_id" => "ws_2"}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %FoPost.Account{workspace_id: "ws_2"}} =
             GoogleBusiness.assign(client, "acc_1", "ws_2")
  end

  test "a pending api grant surfaces as a 503", %{bypass: bypass} do
    Bypass.expect(bypass, "GET", "/v1/accounts/acc_1/gbp/location", fn conn ->
      TestSupport.json(conn, 503, %{
        "error" => "configuration_error",
        "message" => "Not available yet"
      })
    end)

    client = TestSupport.client(bypass, max_retries: 0)

    assert {:error, %FoPost.Error{status: 503, code: "configuration_error"}} =
             GoogleBusiness.get_location(client, "acc_1")
  end
end
