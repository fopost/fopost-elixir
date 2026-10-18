defmodule FoPost.WebhookDeliveriesTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport
  alias FoPost.Webhooks

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "deliveries filters and decodes the log", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/webhooks/wh_1/deliveries", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"status" => "failed", "limit" => "10"}

      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "id" => "del_1",
            "webhook_id" => "wh_1",
            "event" => "post.published",
            "delivery_key" => "key_1",
            "attempt" => 2,
            "status" => "failed",
            "response_status" => 500,
            "response_snippet" => "boom",
            "duration_ms" => 120,
            "payload_hash" => "abc",
            "next_retry_at" => "2026-10-18T10:05:00Z",
            "created_at" => "2026-10-18T10:00:00Z"
          }
        ]
      })
    end)

    assert {:ok, [delivery]} =
             Webhooks.deliveries(TestSupport.client(bypass), "wh_1", status: "failed", limit: 10)

    assert %FoPost.WebhookDelivery{id: "del_1", attempt: 2, status: "failed"} = delivery
    assert delivery.response_status == 500
    assert delivery.next_retry_at == ~U[2026-10-18 10:05:00Z]
    assert delivery.payload == nil
  end

  test "delivery reads one attempt with its payload", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/webhooks/wh_1/deliveries/del_1", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => %{
          "id" => "del_1",
          "webhook_id" => "wh_1",
          "event" => "post.published",
          "delivery_key" => "key_1",
          "attempt" => 1,
          "status" => "success",
          "response_status" => 200,
          "duration_ms" => 40,
          "payload_hash" => "abc",
          "created_at" => "2026-10-18T10:00:00Z",
          "payload" => %{"event" => "post.published", "data" => %{"id" => "post_1"}}
        }
      })
    end)

    assert {:ok, delivery} = Webhooks.delivery(TestSupport.client(bypass), "wh_1", "del_1")
    assert delivery.status == "success"
    assert delivery.payload == %{"event" => "post.published", "data" => %{"id" => "post_1"}}
  end

  test "redeliver posts and answers :ok on a 204", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/webhooks/wh_1/deliveries/del_1/redeliver", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    assert :ok = Webhooks.redeliver(TestSupport.client(bypass), "wh_1", "del_1")
  end
end
