defmodule FoPost.AdsTikTokTest do
  use ExUnit.Case, async: true

  alias FoPost.Ads
  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "reads business centers, identities and spark posts", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/ads/tiktok/business-centers", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => [%{"id" => "bc1", "name" => "Brand HQ", "role" => "ADMIN"}]
      })
    end)

    Bypass.expect_once(bypass, "GET", "/v1/ads/tiktok/identities", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["ad_account_id"] == "7011"

      TestSupport.json(conn, 200, %{
        "data" => [%{"id" => "idt_1", "type" => "CUSTOMIZED_USER", "name" => "Your Brand"}]
      })
    end)

    Bypass.expect_once(bypass, "GET", "/v1/ads/spark-posts", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["identity_id"] == "idt_1"

      TestSupport.json(conn, 200, %{
        "data" => [%{"id" => "item_99", "identityId" => "idt_1", "views" => 48_213}]
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [center]} =
             Ads.tiktok_business_centers(client, workspace_id: "ws_1", connection_id: "conn_1")

    assert center.name == "Brand HQ"

    assert {:ok, [identity]} =
             Ads.tiktok_identities(client,
               workspace_id: "ws_1",
               connection_id: "conn_1",
               ad_account_id: "7011"
             )

    assert identity.type == "CUSTOMIZED_USER"

    assert {:ok, [post]} =
             Ads.spark_posts(client,
               workspace_id: "ws_1",
               connection_id: "conn_1",
               ad_account_id: "7011",
               identity_id: "idt_1"
             )

    assert post.views == 48_213
  end

  test "sends sparkPostId on an ad and smartPlus on a campaign", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw)["sparkPostId"] == "item_99"

      TestSupport.json(conn, 201, %{
        "data" => %{"id" => "ad_1", "workspaceId" => "ws_1", "kind" => "ad", "name" => "Spark"}
      })
    end)

    Bypass.expect_once(bypass, "POST", "/v1/ads/campaigns", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw)["smartPlus"] == true

      TestSupport.json(conn, 201, %{"data" => %{"id" => "c1", "name" => "Smart"}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, _} =
             Ads.create(client,
               workspace_id: "ws_1",
               connection_id: "conn_1",
               ad_account_id: "7011",
               page_id: "idt_1",
               name: "Spark",
               goal: "traffic",
               budget: %{minor: 2000, type: "daily"},
               targeting: %{countries: ["US"], ageMin: 18, ageMax: 44},
               text: "",
               spark_post_id: "item_99"
             )

    assert {:ok, _} =
             Ads.create_campaign(client,
               workspace_id: "ws_1",
               connection_id: "conn_1",
               ad_account_id: "7011",
               name: "Smart",
               goal: "traffic",
               smart_plus: true
             )
  end

  test "uploads conversions and answers what the network accepted", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/ads/conversions", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw)["pixelId"] == "px_1"

      TestSupport.json(conn, 202, %{"data" => %{"accepted" => 2}})
    end)

    assert {:ok, 2} =
             Ads.upload_conversions(TestSupport.client(bypass),
               workspace_id: "ws_1",
               connection_id: "conn_1",
               ad_account_id: "7011",
               pixel_id: "px_1",
               events: [%{eventName: "CompletePayment", occurredAt: "2026-09-18T10:04:00Z"}]
             )
  end

  test "reads a page of comments and answers, hides and deletes one", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/ads/comments", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => %{
          "comments" => [%{"id" => "cm_1", "text" => "nice", "likes" => 3, "hidden" => true}],
          "nextCursor" => "2"
        }
      })
    end)

    Bypass.expect_once(bypass, "POST", "/v1/ads/comments/cm_1/reply", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw)["adId"] == "ad_1"

      TestSupport.json(conn, 201, %{"data" => %{"replyId" => "cm_2"}})
    end)

    Bypass.expect_once(bypass, "POST", "/v1/ads/comments/cm_1/hide", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw)["hidden"] == true

      TestSupport.json(conn, 200, %{"message" => "Comment hidden"})
    end)

    # The ad travels in the body, because the path already carries the comment.
    Bypass.expect_once(bypass, "DELETE", "/v1/ads/comments/cm_1", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw)["adId"] == "ad_1"

      TestSupport.json(conn, 200, %{"message" => "Comment deleted"})
    end)

    client = TestSupport.client(bypass)
    scope = [workspace_id: "ws_1", connection_id: "conn_1", ad_id: "ad_1"]

    assert {:ok, page} = Ads.comments(client, scope)
    assert page.next_cursor == "2"
    assert [%{hidden: true, likes: 3}] = page.comments

    assert {:ok, "cm_2"} = Ads.reply_to_comment(client, "cm_1", scope ++ [text: "Friday!"])
    assert :ok = Ads.set_comment_hidden(client, "cm_1", scope ++ [hidden: true])
    assert :ok = Ads.delete_comment(client, "cm_1", scope)
  end
end
