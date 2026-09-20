defmodule FoPost.BlogsTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport

  @article %{
    "id" => "99",
    "blog_id" => "11",
    "title" => "Spring drop",
    "body_html" => "<p>Hello</p>",
    "excerpt" => "A short summary",
    "status" => "published",
    "author_name" => "Store Owner",
    "tags" => ["news"],
    "image_url" => "https://cdn.example/img.png",
    "url" => "https://demo.myshopify.com/blogs/article/spring-drop",
    "published_at" => "2026-09-01T10:00:00Z",
    "updated_at" => "2026-09-02T10:00:00Z"
  }

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "list_blogs reads every blog on the site", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/blogs", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => [%{"id" => "11", "title" => "News", "handle" => "news", "url" => nil}]
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [blog]} = FoPost.Blogs.list_blogs(client, "acc_1")
    assert blog.id == "11"
    assert blog.title == "News"
    assert blog.url == nil
  end

  test "list_articles passes the filters through", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/blogs/11/articles", fn conn ->
      assert conn.query_string =~ "limit=5"
      assert conn.query_string =~ "status=draft"
      assert conn.query_string =~ "q=spring"
      TestSupport.json(conn, 200, %{"data" => [@article]})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [article]} =
             FoPost.Blogs.list_articles(client, "acc_1", "11",
               limit: 5,
               status: "draft",
               q: "spring"
             )

    assert article.id == "99"
    assert article.tags == ["news"]
    assert %DateTime{} = article.updated_at
  end

  test "get_article reads one article in full", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/blogs/11/articles/99", fn conn ->
      TestSupport.json(conn, 200, %{"data" => @article})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, article} = FoPost.Blogs.get_article(client, "acc_1", "11", "99")
    assert article.blog_id == "11"
    assert article.status == "published"
    assert article.body_html == "<p>Hello</p>"
  end

  test "create_article sends only what was set", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/accounts/acc_1/blogs/11/articles", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "title" => "Spring drop",
               "body" => "Hello",
               "status" => "draft"
             }

      TestSupport.json(conn, 201, %{"data" => @article})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, article} =
             FoPost.Blogs.create_article(client, "acc_1", "11",
               title: "Spring drop",
               body: "Hello",
               status: "draft"
             )

    assert article.id == "99"
  end

  # The article is addressed by its own id, so an update never forks a duplicate.
  test "update_article patches the live article in place", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PATCH", "/v1/accounts/acc_1/blogs/11/articles/99", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"title" => "Spring drop, restocked"}
      TestSupport.json(conn, 200, %{"data" => @article})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, _article} =
             FoPost.Blogs.update_article(client, "acc_1", "11", "99",
               title: "Spring drop, restocked"
             )
  end

  test "delete_article removes it from the site", %{bypass: bypass} do
    Bypass.expect_once(bypass, "DELETE", "/v1/accounts/acc_1/blogs/11/articles/99", fn conn ->
      TestSupport.json(conn, 200, %{"data" => nil})
    end)

    client = TestSupport.client(bypass)

    assert :ok = FoPost.Blogs.delete_article(client, "acc_1", "11", "99")
  end

  test "products list and update", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/accounts/acc_1/products", fn conn ->
      assert conn.query_string =~ "status=active"

      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "id" => "7",
            "title" => "Mug",
            "status" => "active",
            "tags" => [],
            "price" => "12.00",
            "currency" => "USD"
          }
        ]
      })
    end)

    Bypass.expect_once(bypass, "PATCH", "/v1/accounts/acc_1/products/7", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"title" => "Mug XL", "status" => "draft"}

      TestSupport.json(conn, 200, %{
        "data" => %{"id" => "7", "title" => "Mug XL", "status" => "draft", "tags" => []}
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [product]} = FoPost.Blogs.list_products(client, "acc_1", status: "active")
    assert product.price == "12.00"
    assert product.currency == "USD"

    assert {:ok, updated} =
             FoPost.Blogs.update_product(client, "acc_1", "7", title: "Mug XL", status: "draft")

    assert updated.status == "draft"
  end
end
