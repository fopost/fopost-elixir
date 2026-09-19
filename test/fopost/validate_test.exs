defmodule FoPost.ValidateTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport

  test "post sends the content, media, and platforms and decodes each platform" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/v1/validate/post", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "content" => "Hello",
               "media" => [%{"url" => "https://cdn.example/a.png", "mime_type" => "image/png"}],
               "platforms" => ["twitter", "linkedin"]
             }

      data = %{
        "ready" => false,
        "platforms" => [
          %{
            "platform" => "twitter",
            "ready" => true,
            "issues" => [],
            "score" => 88,
            "signals" => [%{"level" => "info", "code" => "no_hashtags", "message" => "m"}]
          },
          %{"platform" => "linkedin", "ready" => false, "issues" => ["too_long"]}
        ]
      }

      TestSupport.json(conn, 200, %{"data" => data})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, result} =
             FoPost.Validate.post(client,
               content: "Hello",
               media: [%{url: "https://cdn.example/a.png", mime_type: "image/png"}],
               platforms: ["twitter", "linkedin"]
             )

    assert result.ready == false
    assert [twitter, linkedin] = result.platforms
    assert twitter.score == 88
    assert [%{"code" => "no_hashtags"}] = twitter.signals
    assert linkedin.issues == ["too_long"]
    assert linkedin.signals == []
  end

  test "length sends the text and platforms and keeps a nil limit" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/v1/validate/length", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{"text" => "Hello", "platforms" => ["twitter", "bluesky"]}

      data = %{
        "ok" => true,
        "platforms" => [
          %{
            "platform" => "twitter",
            "length" => 5,
            "limit" => 280,
            "unit" => "chars",
            "ok" => true
          },
          %{
            "platform" => "bluesky",
            "length" => 5,
            "limit" => nil,
            "unit" => "bytes",
            "ok" => true
          }
        ]
      }

      TestSupport.json(conn, 200, %{"data" => data})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, result} =
             FoPost.Validate.length(client, text: "Hello", platforms: ["twitter", "bluesky"])

    assert result.ok
    assert [twitter, bluesky] = result.platforms
    assert twitter.limit == 280
    assert bluesky.limit == nil
    assert bluesky.unit == "bytes"
  end

  test "media sends the url and answers ok with a failed check" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/v1/validate/media", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{"url" => "https://cdn.example/big.mov"}

      data = %{"ok" => false, "issues" => ["too_large"], "name" => "big.mov", "size" => 99}

      TestSupport.json(conn, 200, %{"data" => data})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, result} = FoPost.Validate.media(client, url: "https://cdn.example/big.mov")
    assert result.ok == false
    assert result.issues == ["too_large"]
    assert result.size == 99
    assert result.mime_type == nil
  end
end
