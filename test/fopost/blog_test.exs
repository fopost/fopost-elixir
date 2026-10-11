defmodule FoPost.BlogTest do
  use ExUnit.Case, async: true

  alias FoPost.Blog
  alias FoPost.TestSupport

  @ws "7d6f2e1a-0000-4000-8000-000000000001"

  @settings %{
    "siteUrl" => "https://yourbrand.com",
    "topic" => "Scheduling",
    "audience" => nil,
    "language" => "en",
    "locationCode" => 2840,
    "cadencePerWeek" => 2,
    "reviewHoldDays" => 3,
    "autoPublish" => false,
    "imageTier" => "standard",
    "inBodyImages" => 1,
    "minWords" => 900,
    "maxWords" => 1500,
    "brandVoiceId" => nil,
    "targetKind" => "website",
    "targetAccountId" => nil,
    "targetPlatform" => nil,
    "websiteUrl" => "https://yourbrand.com/hooks/articles",
    "hasWebsiteSecret" => true,
    "keywordDataAvailable" => true,
    "updatedAt" => "2026-10-10T09:00:00Z"
  }

  @keyword %{
    "id" => "kw_1",
    "keyword" => "social media calendar",
    "searchVolume" => 4400,
    "difficulty" => 38,
    "cpc" => 1.2,
    "intent" => "informational",
    "source" => "provider",
    "status" => "planned",
    "plannedFor" => "2026-10-14",
    "createdAt" => "2026-10-10T09:00:00Z"
  }

  @article %{
    "id" => "art_1",
    "title" => "How to plan a month of content",
    "slug" => "plan-a-month-of-content",
    "keyword" => "social media calendar",
    "excerpt" => nil,
    "metaTitle" => nil,
    "metaDescription" => nil,
    "featuredImage" => %{
      "mediaId" => "med_1",
      "url" => "https://cdn.test/a.jpg",
      "alt" => "Calendar"
    },
    "tags" => ["planning"],
    "wordCount" => 0,
    "status" => "queued",
    "origin" => "user",
    "reviewUntil" => nil,
    "publishAt" => nil,
    "publishedAt" => nil,
    "publishedUrl" => nil,
    "error" => nil,
    "createdAt" => "2026-10-10T09:00:00Z",
    "updatedAt" => "2026-10-10T09:00:00Z"
  }

  setup do
    {:ok, bypass: Bypass.open()}
  end

  describe "settings" do
    test "settings reads with the workspace as camelCase", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/v1/blog/settings", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params == %{"workspaceId" => @ws}

        TestSupport.json(conn, 200, %{"data" => @settings})
      end)

      assert {:ok, settings} = Blog.settings(TestSupport.client(bypass), @ws)
      assert settings.target_kind == "website"
      assert settings.cadence_per_week == 2
      assert settings.has_website_secret
      assert is_nil(settings.website_secret)
      assert %DateTime{} = settings.updated_at
    end

    test "update_settings sends camelCase and lifts the one-time secret", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/v1/blog/settings", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(raw) == %{
                 "workspaceId" => @ws,
                 "websiteUrl" => "https://yourbrand.com/hooks/articles",
                 "cadencePerWeek" => 2,
                 "brandVoiceId" => nil
               }

        TestSupport.json(conn, 200, %{"data" => @settings, "websiteSecret" => "whsec_once"})
      end)

      assert {:ok, settings} =
               Blog.update_settings(TestSupport.client(bypass), @ws,
                 website_url: "https://yourbrand.com/hooks/articles",
                 cadence_per_week: 2,
                 brand_voice_id: nil
               )

      assert settings.website_secret == "whsec_once"
      assert settings.website_url == "https://yourbrand.com/hooks/articles"
    end

    test "rotate_website_secret answers the new secret", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/blog/settings/website-secret", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(raw) == %{"workspaceId" => @ws}

        TestSupport.json(conn, 200, %{"data" => %{"websiteSecret" => "whsec_new"}})
      end)

      assert {:ok, "whsec_new"} = Blog.rotate_website_secret(TestSupport.client(bypass), @ws)
    end

    test "test_website reports how the site answered", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/blog/settings/website-test", fn conn ->
        TestSupport.json(conn, 200, %{"data" => %{"ok" => true, "status" => 200, "error" => nil}})
      end)

      assert {:ok, result} = Blog.test_website(TestSupport.client(bypass), @ws)
      assert result.ok
      assert result.status == 200
    end
  end

  describe "keywords" do
    test "list_keywords filters and decodes the date", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/v1/blog/keywords", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        assert conn.query_params == %{
                 "workspaceId" => @ws,
                 "status" => "planned,suggested",
                 "limit" => "50"
               }

        TestSupport.json(conn, 200, %{"data" => [@keyword]})
      end)

      assert {:ok, [keyword]} =
               Blog.list_keywords(TestSupport.client(bypass), @ws,
                 status: "planned,suggested",
                 limit: 50
               )

      assert keyword.id == "kw_1"
      assert keyword.difficulty == 38
      assert keyword.planned_for == ~D[2026-10-14]
    end

    test "plan_keywords is queued and carries seeds", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/blog/keywords/plan", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(raw) == %{"workspaceId" => @ws, "seeds" => ["scheduling"]}

        TestSupport.json(conn, 202, %{"data" => %{"status" => "queued"}})
      end)

      assert {:ok, "queued"} =
               Blog.plan_keywords(TestSupport.client(bypass), @ws, seeds: ["scheduling"])
    end

    test "plan_keywords on an empty balance is a 402 with the upgrade url", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/blog/keywords/plan", fn conn ->
        TestSupport.json(conn, 402, %{
          "error" => "insufficient_credits",
          "message" => "Balance exhausted",
          "upgrade_url" => "https://app.test/billing"
        })
      end)

      assert {:error, error} = Blog.plan_keywords(TestSupport.client(bypass), @ws)
      assert FoPost.Error.payment_required?(error)
      assert error.code == "insufficient_credits"
      assert error.upgrade_url == "https://app.test/billing"
    end

    test "add_keyword takes a Date", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/blog/keywords", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(raw) == %{
                 "workspaceId" => @ws,
                 "keyword" => "social media calendar",
                 "plannedFor" => "2026-10-14"
               }

        TestSupport.json(conn, 201, %{"data" => @keyword})
      end)

      assert {:ok, keyword} =
               Blog.add_keyword(TestSupport.client(bypass), @ws,
                 keyword: "social media calendar",
                 planned_for: ~D[2026-10-14]
               )

      assert keyword.status == "planned"
    end

    test "update_keyword puts the workspace on the query and the patch in the body",
         %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/v1/blog/keywords/kw_1", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params == %{"workspaceId" => @ws}

        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(raw) == %{"status" => "dismissed", "plannedFor" => nil}

        TestSupport.json(conn, 200, %{"data" => Map.put(@keyword, "status", "dismissed")})
      end)

      assert {:ok, keyword} =
               Blog.update_keyword(TestSupport.client(bypass), @ws, "kw_1",
                 status: "dismissed",
                 planned_for: nil
               )

      assert keyword.status == "dismissed"
    end

    test "delete_keyword is a 204", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/v1/blog/keywords/kw_1", fn conn ->
        assert conn.query_string == "workspaceId=#{@ws}"
        Plug.Conn.resp(conn, 204, "")
      end)

      assert {:ok, _body} = Blog.delete_keyword(TestSupport.client(bypass), @ws, "kw_1")
    end
  end

  describe "articles" do
    test "list_articles filters by status", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/v1/blog/articles", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params == %{"workspaceId" => @ws, "status" => "draft"}

        TestSupport.json(conn, 200, %{"data" => [@article]})
      end)

      assert {:ok, [article]} =
               Blog.list_articles(TestSupport.client(bypass), @ws, status: "draft")

      assert article.slug == "plan-a-month-of-content"
      assert article.featured_image.media_id == "med_1"
      assert article.tags == ["planning"]
    end

    test "request_article is accepted as queued", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/blog/articles", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(raw) == %{
                 "workspaceId" => @ws,
                 "keywordId" => "kw_1",
                 "instructions" => "Lead with the calendar view."
               }

        TestSupport.json(conn, 202, %{"data" => @article})
      end)

      assert {:ok, article} =
               Blog.request_article(TestSupport.client(bypass), @ws,
                 keyword_id: "kw_1",
                 instructions: "Lead with the calendar view."
               )

      assert article.status == "queued"
    end

    test "get_article carries the body and images", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/v1/blog/articles/art_1", fn conn ->
        assert conn.query_string == "workspaceId=#{@ws}"

        full =
          Map.merge(@article, %{
            "status" => "draft",
            "wordCount" => 1200,
            "instructions" => nil,
            "outline" => ["Why plan", "How to plan"],
            "brief" => %{"sources" => []},
            "bodyMarkdown" => "# Plan",
            "bodyHtml" => "<h1>Plan</h1>",
            "images" => [
              %{
                "mediaId" => "med_2",
                "url" => "https://cdn.test/b.jpg",
                "alt" => "Grid",
                "position" => 1
              }
            ]
          })

        TestSupport.json(conn, 200, %{"data" => full})
      end)

      assert {:ok, article} = Blog.get_article(TestSupport.client(bypass), @ws, "art_1")
      assert article.body_markdown == "# Plan"
      assert article.outline == ["Why plan", "How to plan"]
      assert article.brief == %{"sources" => []}
      assert [image] = article.images
      assert image.position == 1
    end

    test "update_article sends the camelCase patch", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/v1/blog/articles/art_1", fn conn ->
        assert conn.query_string == "workspaceId=#{@ws}"
        {:ok, raw, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(raw) == %{
                 "bodyMarkdown" => "# Better",
                 "publishAt" => "2026-10-20T08:00:00Z"
               }

        TestSupport.json(conn, 200, %{"data" => Map.put(@article, "status", "scheduled")})
      end)

      assert {:ok, article} =
               Blog.update_article(TestSupport.client(bypass), @ws, "art_1",
                 body_markdown: "# Better",
                 publish_at: ~U[2026-10-20 08:00:00Z]
               )

      assert article.status == "scheduled"
    end

    test "update_article on a published article is a 409", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/v1/blog/articles/art_1", fn conn ->
        TestSupport.json(conn, 409, %{"error" => "invalid_state", "message" => "Not editable"})
      end)

      assert {:error, error} =
               Blog.update_article(TestSupport.client(bypass), @ws, "art_1", title: "x")

      assert error.status == 409
      assert error.code == "invalid_state"
    end

    test "publish_article without a target is a 409 no_target", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/blog/articles/art_1/publish", fn conn ->
        assert conn.query_string == "workspaceId=#{@ws}"
        TestSupport.json(conn, 409, %{"error" => "no_target", "message" => "No target"})
      end)

      assert {:error, error} = Blog.publish_article(TestSupport.client(bypass), @ws, "art_1")
      assert error.code == "no_target"
    end

    test "regenerate, publish and reject post to the action path", %{bypass: bypass} do
      for action <- ["regenerate", "publish", "reject"] do
        Bypass.expect_once(bypass, "POST", "/v1/blog/articles/art_1/#{action}", fn conn ->
          assert conn.query_string == "workspaceId=#{@ws}"
          TestSupport.json(conn, 202, %{"data" => Map.put(@article, "status", "publishing")})
        end)
      end

      client = TestSupport.client(bypass)

      assert {:ok, %FoPost.BlogArticle{}} = Blog.regenerate_article(client, @ws, "art_1")
      assert {:ok, %FoPost.BlogArticle{}} = Blog.publish_article(client, @ws, "art_1")
      assert {:ok, %FoPost.BlogArticle{}} = Blog.reject_article(client, @ws, "art_1")
    end

    test "delete_article is a 204", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/v1/blog/articles/art_1", fn conn ->
        assert conn.query_string == "workspaceId=#{@ws}"
        Plug.Conn.resp(conn, 204, "")
      end)

      assert {:ok, _body} = Blog.delete_article(TestSupport.client(bypass), @ws, "art_1")
    end
  end
end
