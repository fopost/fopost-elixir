defmodule FoPost.MetaMessagingTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "ice breakers round-trip and clear", %{bypass: bypass} do
    breakers = [%{"question" => "Hours?", "payload" => "HOURS"}]

    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/messaging/ice-breakers", fn conn ->
      TestSupport.json(conn, 200, %{"data" => %{"ice_breakers" => breakers}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [%FoPost.MetaIceBreaker{payload: "HOURS"}]} =
             FoPost.Accounts.ice_breakers(client, "acc_1")

    Bypass.expect_once(bypass, "PUT", "/v1/accounts/acc_1/messaging/ice-breakers", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"ice_breakers" => breakers}
      TestSupport.json(conn, 200, %{"data" => %{"ice_breakers" => breakers}})
    end)

    assert {:ok, [%FoPost.MetaIceBreaker{question: "Hours?"}]} =
             FoPost.Accounts.set_ice_breakers(client, "acc_1", [
               %{question: "Hours?", payload: "HOURS"}
             ])

    Bypass.expect_once(bypass, "DELETE", "/v1/accounts/acc_1/messaging/ice-breakers", fn conn ->
      TestSupport.json(conn, 200, %{"data" => %{"ice_breakers" => []}})
    end)

    assert {:ok, []} = FoPost.Accounts.delete_ice_breakers(client, "acc_1")
  end

  test "a link menu item omits the payload key", %{bypass: bypass} do
    menu = [
      %{
        "locale" => "default",
        "call_to_actions" => [
          %{"type" => "web_url", "title" => "Shop", "url" => "https://example.com/shop"}
        ]
      }
    ]

    Bypass.expect_once(bypass, "PUT", "/v1/accounts/acc_1/messaging/persistent-menu", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"persistent_menu" => menu}
      TestSupport.json(conn, 200, %{"data" => %{"persistent_menu" => menu}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [entry]} =
             FoPost.Accounts.set_persistent_menu(client, "acc_1", [
               %{
                 locale: "default",
                 call_to_actions: [
                   %{type: "web_url", title: "Shop", url: "https://example.com/shop"}
                 ]
               }
             ])

    assert [%FoPost.MetaMenuItem{url: "https://example.com/shop", payload: nil}] =
             entry.call_to_actions
  end

  test "the greeting defaults its locale", %{bypass: bypass} do
    greeting = [%{"locale" => "default", "text" => "Hi!"}]

    Bypass.expect_once(bypass, "PUT", "/v1/accounts/acc_1/messaging/greeting", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"greeting" => greeting}
      TestSupport.json(conn, 200, %{"data" => %{"greeting" => greeting}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [%FoPost.MetaGreetingText{locale: "default"}]} =
             FoPost.Accounts.set_greeting(client, "acc_1", [%{text: "Hi!"}])
  end

  test "a lapsed subscription is reported and resubscribed", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/webhook-subscription", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => %{
          "subscribed" => false,
          "fields" => ["feed"],
          "missing_fields" => ["messages"]
        }
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %FoPost.WebhookSubscription{subscribed: false, missing_fields: ["messages"]}} =
             FoPost.Accounts.webhook_subscription(client, "acc_1")

    Bypass.expect_once(bypass, "POST", "/v1/accounts/acc_1/webhook-subscription", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => %{
          "subscribed" => true,
          "fields" => ["feed", "messages"],
          "missing_fields" => []
        }
      })
    end)

    assert {:ok, %FoPost.WebhookSubscription{subscribed: true}} =
             FoPost.Accounts.resubscribe_webhook(client, "acc_1")
  end

  test "handover passes to an app and takes control back", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/inbox/conversations/t_1/handover", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"account_id" => "acc_1", "app_id" => "263902037430900"}

      TestSupport.json(conn, 200, %{
        "data" => %{"app_id" => "263902037430900", "control" => "passed"}
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %FoPost.InboxHandover{control: "passed"}} =
             FoPost.Inbox.handover(client, "t_1", "acc_1", app_id: "263902037430900")

    Bypass.expect_once(bypass, "POST", "/v1/inbox/conversations/t_2/handover", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"account_id" => "acc_1"}
      TestSupport.json(conn, 200, %{"data" => %{"app_id" => nil, "control" => "taken"}})
    end)

    assert {:ok, %FoPost.InboxHandover{app_id: nil, control: "taken"}} =
             FoPost.Inbox.handover(client, "t_2", "acc_1")
  end
end
