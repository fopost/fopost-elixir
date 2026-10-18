defmodule FoPost.XTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "repost, unrepost, bookmark, and unbookmark post to their action path", %{bypass: bypass} do
    for action <- ["repost", "unrepost", "bookmark", "unbookmark"] do
      Bypass.expect_once(bypass, "POST", "/v1/inbox/item_1/" <> action, fn conn ->
        TestSupport.json(conn, 200, %{
          "data" => %{
            "id" => "item_1",
            "reposted" => action == "repost",
            "bookmarked" => action == "bookmark",
            "canRepost" => true,
            "canBookmark" => true
          }
        })
      end)
    end

    client = TestSupport.client(bypass)

    assert {:ok, item} = FoPost.Inbox.repost(client, "item_1")
    assert item.reposted
    assert item.can_repost
    assert item.can_bookmark

    assert {:ok, %{reposted: false}} = FoPost.Inbox.unrepost(client, "item_1")
    assert {:ok, %{bookmarked: true}} = FoPost.Inbox.bookmark(client, "item_1")
    assert {:ok, %{bookmarked: false}} = FoPost.Inbox.unbookmark(client, "item_1")
  end

  test "follow and unfollow send the user id and read the state back", %{bypass: bypass} do
    for action <- ["follow", "unfollow"] do
      Bypass.expect_once(bypass, "POST", "/v1/accounts/acc_1/x/" <> action, fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(raw) == %{"user_id" => "2244994945"}

        TestSupport.json(conn, 200, %{
          "account_id" => "acc_1",
          "user_id" => "2244994945",
          "following" => action == "follow"
        })
      end)
    end

    client = TestSupport.client(bypass)

    assert {:ok, %FoPost.XFollowResult{} = result} =
             FoPost.Accounts.follow_x_user(client, "acc_1", "2244994945")

    assert result.account_id == "acc_1"
    assert result.user_id == "2244994945"
    assert result.following

    assert {:ok, %FoPost.XFollowResult{following: false}} =
             FoPost.Accounts.unfollow_x_user(client, "acc_1", "2244994945")
  end

  test "a spent X balance is a 402 with its code", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/accounts/acc_1/x/follow", fn conn ->
      TestSupport.json(conn, 402, %{"error" => "platform_balance_spent", "message" => "Spent"})
    end)

    client = TestSupport.client(bypass)

    assert {:error, %FoPost.Error{status: 402, code: "platform_balance_spent"}} =
             FoPost.Accounts.follow_x_user(client, "acc_1", "2244994945")
  end

  test "get_post passes the account and decodes the post", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/x/posts/1234567890", fn conn ->
      assert conn.query_string == "account_id=acc_1"

      TestSupport.json(conn, 200, %{
        "data" => %{
          "id" => "1234567890",
          "text" => "Hello",
          "permalink" => "https://x.com/yourbrand/status/1234567890",
          "author_name" => "Your Brand",
          "author_handle" => "yourbrand",
          "author_avatar_url" => nil,
          "author_followers" => 1200,
          "conversation_id" => "1234567890",
          "parent_external_id" => nil,
          "likes" => 3,
          "replies" => 1,
          "reposts" => 0,
          "quotes" => 0,
          "platform_created_at" => "2026-10-01T10:00:00Z"
        }
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %FoPost.XPost{} = post} = FoPost.X.get_post(client, "1234567890", "acc_1")
    assert post.author_handle == "yourbrand"
    assert post.author_followers == 1200
    assert post.likes == 3
    assert post.platform_created_at == ~U[2026-10-01 10:00:00Z]
  end

  test "search_posts sends q, the account and paging, and reads next_token", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/x/search", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      assert conn.query_params == %{
               "q" => "from:yourbrand",
               "account_id" => "acc_1",
               "max_results" => "50",
               "next_token" => "tok_1"
             }

      TestSupport.json(conn, 200, %{
        "data" => [%{"id" => "1", "text" => "One"}, %{"id" => "2", "text" => "Two"}],
        "meta" => %{"next_token" => "tok_2"}
      })
    end)

    client = TestSupport.client(bypass)
    opts = [max_results: 50, next_token: "tok_1"]

    assert {:ok, page} = FoPost.X.search_posts(client, "from:yourbrand", "acc_1", opts)
    assert [%FoPost.XPost{id: "1"}, %FoPost.XPost{id: "2"}] = page.posts
    assert page.next_token == "tok_2"
  end
end
