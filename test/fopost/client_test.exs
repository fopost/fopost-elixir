defmodule FoPost.ClientTest do
  use ExUnit.Case, async: true

  alias FoPost.Client
  alias FoPost.Error
  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "authenticates with X-API-Key and identifies itself", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/workspaces", fn conn ->
      assert Plug.Conn.get_req_header(conn, "x-api-key") == ["fp_test_key"]
      assert Plug.Conn.get_req_header(conn, "accept") == ["application/json"]
      assert [user_agent] = Plug.Conn.get_req_header(conn, "user-agent")
      assert user_agent == "fopost-elixir/" <> FoPost.version()

      # The API is never authenticated with a bearer token.
      assert Plug.Conn.get_req_header(conn, "authorization") == []

      TestSupport.json(conn, 200, %{"data" => []})
    end)

    assert {:ok, []} = FoPost.Workspaces.list(TestSupport.client(bypass))
  end

  test "unwraps the data envelope", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/posts/post_1", fn conn ->
      TestSupport.json(conn, 200, %{"data" => %{"id" => "post_1", "status" => "draft"}})
    end)

    assert {:ok, post} = FoPost.Posts.get(TestSupport.client(bypass), "post_1")
    assert post.id == "post_1"
    assert post.status == "draft"
  end

  test "the escape hatch returns the body exactly as it arrived", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/platforms", fn conn ->
      assert conn.query_string == "per_page=5"

      TestSupport.json(conn, 200, %{"data" => ["twitter"]})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, body} = FoPost.request(client, :get, "/platforms", params: [per_page: 5])
    assert body == %{"data" => ["twitter"]}
  end

  test "decodes the error envelope", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/posts/missing", fn conn ->
      TestSupport.json(conn, 404, %{"error" => "not_found", "message" => "No such post"})
    end)

    assert {:error, error} = FoPost.Posts.get(TestSupport.client(bypass), "missing")
    assert error.status == 404
    assert error.code == "not_found"
    assert error.message == "No such post"
    assert Error.not_found?(error)
    refute Error.rate_limited?(error)
    assert Exception.message(error) == "FoPost: 404 not_found: No such post"
  end

  test "keeps the upgrade URL a 402 carries", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/posts", fn conn ->
      TestSupport.json(conn, 402, %{
        "error" => "subscription_required",
        "message" => "No active subscription",
        "upgrade_url" => "https://fopost.com/dashboard/billing"
      })
    end)

    client = TestSupport.client(bypass)

    assert {:error, error} = FoPost.Posts.create(client, workspace_id: "ws_1", content: "x")
    assert Error.payment_required?(error)
    assert error.upgrade_url == "https://fopost.com/dashboard/billing"
  end

  test "retries a 429 and reports the wait it was asked for", %{bypass: bypass} do
    counter = TestSupport.counter()

    Bypass.expect(bypass, "GET", "/v1/workspaces", fn conn ->
      case TestSupport.bump(counter) do
        1 ->
          conn
          |> Plug.Conn.put_resp_header("retry-after", "1")
          |> TestSupport.json(429, %{"error" => "rate_limited", "message" => "Slow down"})

        _later ->
          TestSupport.json(conn, 200, %{"data" => [%{"id" => "ws_1"}]})
      end
    end)

    assert {:ok, [workspace]} = FoPost.Workspaces.list(TestSupport.client(bypass))
    assert workspace.id == "ws_1"
    assert TestSupport.count(counter) == 2
  end

  test "gives up on a 429 after three attempts", %{bypass: bypass} do
    counter = TestSupport.counter()

    Bypass.expect(bypass, "GET", "/v1/workspaces", fn conn ->
      TestSupport.bump(counter)

      conn
      |> Plug.Conn.put_resp_header("retry-after", "1")
      |> TestSupport.json(429, %{"error" => "rate_limited", "message" => "Slow down"})
    end)

    assert {:error, error} = FoPost.Workspaces.list(TestSupport.client(bypass))
    assert Error.rate_limited?(error)
    assert error.retry_after == 1
    assert TestSupport.count(counter) == 3
  end

  test "retries a 500", %{bypass: bypass} do
    counter = TestSupport.counter()

    Bypass.expect(bypass, "GET", "/v1/workspaces", fn conn ->
      case TestSupport.bump(counter) do
        count when count < 3 ->
          TestSupport.json(conn, 500, %{"error" => "server_error", "message" => "Boom"})

        _last ->
          TestSupport.json(conn, 200, %{"data" => []})
      end
    end)

    assert {:ok, []} = FoPost.Workspaces.list(TestSupport.client(bypass))
    assert TestSupport.count(counter) == 3
  end

  test "never retries a 400", %{bypass: bypass} do
    counter = TestSupport.counter()

    Bypass.expect(bypass, "GET", "/v1/workspaces", fn conn ->
      TestSupport.bump(counter)

      TestSupport.json(conn, 400, %{"error" => "validation_failed", "message" => "Nope"})
    end)

    assert {:error, error} = FoPost.Workspaces.list(TestSupport.client(bypass))
    assert Error.validation?(error)
    assert TestSupport.count(counter) == 1
  end

  test "turns a dead connection into the same error struct", %{bypass: bypass} do
    client = TestSupport.client(bypass)
    Bypass.down(bypass)

    assert {:error, error} = FoPost.Workspaces.list(client)
    assert Error.transport_error?(error)
    assert error.status == nil
    assert error.code == "transport_error"
  end

  test "retry?/2 covers exactly 429, 5xx, and transport failures" do
    assert Client.retry?(nil, %Req.Response{status: 429})
    assert Client.retry?(nil, %Req.Response{status: 500})
    assert Client.retry?(nil, %Req.Response{status: 503})
    assert Client.retry?(nil, %RuntimeError{message: "connection closed"})
    refute Client.retry?(nil, %Req.Response{status: 400})
    refute Client.retry?(nil, %Req.Response{status: 404})
    refute Client.retry?(nil, %Req.Response{status: 200})
  end

  test "retry_delay/1 doubles from 500ms and stops at a minute" do
    assert Client.retry_delay(0) == 500
    assert Client.retry_delay(1) == 1000
    assert Client.retry_delay(2) == 2000
    assert Client.retry_delay(20) == 60_000
  end

  test "cap_retry_after/1 clamps an oversized Retry-After to a minute" do
    response = Req.Response.new(status: 429)
    capped = Client.cap_retry_after(Req.Response.put_header(response, "retry-after", "3600"))
    kept = Client.cap_retry_after(Req.Response.put_header(response, "retry-after", "12"))

    assert Req.Response.get_header(capped, "retry-after") == ["60"]
    assert Req.Response.get_header(kept, "retry-after") == ["12"]
  end
end
