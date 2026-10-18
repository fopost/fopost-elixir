defmodule FoPost.RedditTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "subreddits come back busiest first, with the default marked", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/reddit/subreddits", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "name" => "webdev",
            "title" => "Web Development",
            "subscribers" => 2_000_000,
            "over18" => false,
            "canPost" => true,
            "flairEnabled" => true,
            "iconUrl" => nil,
            "isDefault" => true
          }
        ]
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [subreddit]} = FoPost.Accounts.reddit_subreddits(client, "acc_1")
    assert subreddit.name == "webdev"
    assert subreddit.can_post
    assert subreddit.is_default
  end

  test "rules and flairs unwrap the subreddit envelope", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/reddit/subreddits/webdev/rules", fn c ->
      TestSupport.json(c, 200, %{
        "data" => %{
          "subreddit" => "webdev",
          "rules" => [
            %{
              "name" => "No self promotion",
              "description" => "Keep it useful",
              "appliesTo" => "link"
            }
          ]
        }
      })
    end)

    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/reddit/flairs", fn conn ->
      assert conn.query_string == "subreddit=webdev"

      TestSupport.json(conn, 200, %{
        "data" => %{
          "subreddit" => "webdev",
          "flairs" => [%{"id" => "flair_1", "text" => "Showoff Saturday", "editable" => false}]
        }
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [rule]} = FoPost.Accounts.reddit_subreddit_rules(client, "acc_1", "webdev")
    assert rule.applies_to == "link"

    assert {:ok, [flair]} = FoPost.Accounts.reddit_flairs(client, "acc_1", "webdev")
    assert flair.id == "flair_1"
    refute flair.editable
  end

  test "a null default subreddit is sent explicitly", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PUT", "/v1/accounts/acc_1/reddit/default-subreddit", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"subreddit" => nil}
      TestSupport.json(conn, 200, %{"data" => %{"subreddit" => "u_someone"}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, "u_someone"} =
             FoPost.Accounts.set_reddit_default_subreddit(client, "acc_1", nil)
  end

  test "a vote sends its direction and reads the vote back", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/inbox/item_1/vote", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"direction" => "down"}

      TestSupport.json(conn, 200, %{
        "data" => %{"id" => "item_1", "vote" => "down", "canVote" => true, "liked" => false}
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, item} = FoPost.Inbox.vote(client, "item_1", "down")
    assert item.vote == "down"
    assert item.can_vote
    refute item.liked
  end

  test "the subreddit check passes the account and name as query params", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/validate/subreddit", fn conn ->
      assert conn.query_string =~ "account_id=acc_1"
      assert conn.query_string =~ "name=webdev"

      TestSupport.json(conn, 200, %{
        "data" => %{
          "subreddit" => "webdev",
          "exists" => true,
          "can_post" => false,
          "over_18" => false,
          "flair_enabled" => true,
          "ok" => false
        }
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, result} =
             FoPost.Validate.subreddit(client, account_id: "acc_1", name: "webdev")

    assert result.exists
    refute result.can_post
    refute result.ok
  end
end
