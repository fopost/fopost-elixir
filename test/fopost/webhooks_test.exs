defmodule FoPost.WebhooksTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport
  alias FoPost.Webhooks

  @secret "whsec_test"
  @raw_body ~s({"event":"post.published","data":{"id":"post_1"}})

  test "signature is a lowercase hex HMAC-SHA256, prefixed" do
    assert "sha256=" <> hex = Webhooks.signature(@raw_body, @secret)
    assert String.length(hex) == 64
    assert hex == String.downcase(hex)
  end

  test "verify_signature accepts the signature FoPost would send" do
    signature = Webhooks.signature(@raw_body, @secret)

    assert Webhooks.verify_signature(@raw_body, signature, @secret)
  end

  test "verify_signature rejects anything else" do
    signature = Webhooks.signature(@raw_body, @secret)
    other_body = Webhooks.signature(@raw_body <> " ", @secret)

    refute Webhooks.verify_signature(@raw_body, other_body, @secret)
    refute Webhooks.verify_signature(@raw_body, signature, "another_secret")
    refute Webhooks.verify_signature(@raw_body, "sha256=deadbeef", @secret)
    refute Webhooks.verify_signature(@raw_body, nil, @secret)
    refute Webhooks.verify_signature(@raw_body, "", @secret)
  end

  test "verify_and_parse decodes a verified delivery" do
    signature = Webhooks.signature(@raw_body, @secret)

    assert {:ok, event} = Webhooks.verify_and_parse(@raw_body, signature, @secret)
    assert event.event == "post.published"
    assert event.data == %{"id" => "post_1"}
  end

  test "verify_and_parse refuses a body that was not signed with the secret" do
    result = Webhooks.verify_and_parse(@raw_body, "sha256=00", @secret)

    assert result == {:error, :invalid_signature}
  end

  test "parse_event refuses a body that is not JSON" do
    assert Webhooks.parse_event("not json") == {:error, :invalid_payload}
  end

  test "events/0 lists every event a subscription can ask for" do
    assert "post.published" in Webhooks.events()
    assert "delivery.delayed" in Webhooks.events()
    assert "account.health_changed" in Webhooks.events()
    assert length(Webhooks.events()) == 7
  end

  describe "verify/4" do
    @now 1_760_000_000
    @body ~s({"event":"post.published","data":{"id":"post_1","status":"published"},"timestamp":"2026-10-10T09:00:01Z"})

    defp signed_headers(body, timestamp) do
      [
        {"x-fopost-signature", Webhooks.signature(body, @secret)},
        {"x-fopost-timestamp", to_string(timestamp)},
        {"x-fopost-signature-256", Webhooks.timestamped_signature(body, timestamp, @secret)},
        {"x-fopost-event", "post.published"}
      ]
    end

    test "a valid timestamped signature passes and decodes the body" do
      headers = signed_headers(@body, @now - 10)

      assert {:ok, event} = Webhooks.verify(@body, headers, @secret, now: @now)
      assert event.event == "post.published"

      assert event.data["id"] == "post_1"
      assert event.data["status"] == "published"
    end

    test "header names match case-insensitively and a map works too" do
      headers =
        @body
        |> signed_headers(@now)
        |> Map.new(fn {name, value} -> {String.upcase(name), value} end)

      assert {:ok, _event} = Webhooks.verify(@body, headers, @secret, now: @now)
    end

    test "a tampered body fails" do
      headers = signed_headers(@body, @now)
      tampered = String.replace(@body, "post_1", "post_2")

      assert Webhooks.verify(tampered, headers, @secret, now: @now) ==
               {:error, :invalid_signature}
    end

    test "a stale timestamp fails even when its signature is right" do
      headers = signed_headers(@body, @now - 301)

      assert Webhooks.verify(@body, headers, @secret, now: @now) ==
               {:error, :stale_timestamp}

      assert {:ok, _event} =
               Webhooks.verify(@body, signed_headers(@body, @now - 300), @secret, now: @now)
    end

    test "a timestamp header without the timestamped signature never falls back" do
      headers = [
        {"x-fopost-signature", Webhooks.signature(@body, @secret)},
        {"x-fopost-timestamp", to_string(@now)}
      ]

      assert Webhooks.verify(@body, headers, @secret, now: @now) ==
               {:error, :invalid_signature}
    end

    test "the legacy body-only signature passes when no timestamp header is present" do
      headers = [{"x-fopost-signature", Webhooks.signature(@body, @secret)}]

      assert {:ok, event} = Webhooks.verify(@body, headers, @secret)
      assert event.event == "post.published"

      assert Webhooks.verify(@body, [{"x-fopost-signature", "sha256=00"}], @secret) ==
               {:error, :invalid_signature}

      assert Webhooks.verify(@body, [], @secret) == {:error, :invalid_signature}
    end
  end

  test "create sends the workspace under the name the API expects" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/v1/webhooks", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(raw)

      assert body["workspaceId"] == "ws_1"
      assert body["events"] == ["post.published"]

      TestSupport.json(conn, 201, %{
        "data" => %{"id" => "wh_1", "secret" => "whsec_live", "active" => true}
      })
    end)

    client = TestSupport.client(bypass)

    opts = [
      workspace_id: "ws_1",
      url: "https://example.test/hooks",
      events: ["post.published"]
    ]

    assert {:ok, webhook} = Webhooks.create(client, opts)
    assert webhook.id == "wh_1"
    assert webhook.secret == "whsec_live"
    assert webhook.active
  end
end
