defmodule FoPost.DesignsTest do
  use ExUnit.Case, async: true

  alias FoPost.Designs
  alias FoPost.TestSupport

  @design %{
    "id" => "des_1",
    "name" => "Launch",
    "kind" => "post",
    "width" => 1080,
    "height" => 1080,
    "document" => %{"pages" => [%{"layers" => [%{"type" => "text", "fontFamily" => "Geist"}]}]},
    "thumbnail_media_id" => nil,
    "thumbnail_url" => nil,
    "created_at" => "2026-11-20T10:00:00Z",
    "updated_at" => "2026-11-20T11:00:00Z"
  }

  @version %{
    "id" => "ver_1",
    "version" => 2,
    "created_at" => "2026-11-20T11:00:00Z"
  }

  setup do
    {:ok, bypass: Bypass.open()}
  end

  defp body(conn) do
    {:ok, raw, conn} = Plug.Conn.read_body(conn)
    {Jason.decode!(raw), conn}
  end

  test "list scopes to the workspace and passes the filters", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/designs", fn conn ->
      assert conn.query_string == "workspace_id=ws_1&kind=story&limit=10&offset=20"
      TestSupport.json(conn, 200, %{"data" => [Map.delete(@design, "document")]})
    end)

    assert {:ok, [design]} =
             Designs.list(TestSupport.client(bypass), "ws_1",
               kind: "story",
               limit: 10,
               offset: 20
             )

    assert %FoPost.Design{id: "des_1", kind: "post", width: 1080, document: nil} = design
    assert design.updated_at == ~U[2026-11-20 11:00:00Z]
  end

  test "create sends the document untouched and decodes the design", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/designs", fn conn ->
      {decoded, conn} = body(conn)

      assert decoded == %{
               "workspace_id" => "ws_1",
               "kind" => "post",
               "name" => "Launch",
               "document" => @design["document"],
               "brand_voice_id" => "bv_1"
             }

      TestSupport.json(conn, 201, %{"data" => @design})
    end)

    assert {:ok, design} =
             Designs.create(TestSupport.client(bypass),
               workspace_id: "ws_1",
               kind: "post",
               name: "Launch",
               document: @design["document"],
               brand_voice_id: "bv_1"
             )

    assert design.document == @design["document"]
  end

  test "get reads one design", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/designs/des_1", fn conn ->
      TestSupport.json(conn, 200, %{"data" => @design})
    end)

    assert {:ok, %FoPost.Design{name: "Launch"}} =
             Designs.get(TestSupport.client(bypass), "des_1")
  end

  test "update patches only the given keys and keeps the saved version", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PATCH", "/v1/designs/des_1", fn conn ->
      {decoded, conn} = body(conn)
      assert decoded == %{"name" => "Renamed", "create_version" => true}
      TestSupport.json(conn, 200, %{"data" => @design, "version" => @version})
    end)

    assert {:ok, change} =
             Designs.update(TestSupport.client(bypass), "des_1",
               name: "Renamed",
               create_version: true
             )

    assert %FoPost.Design{id: "des_1"} = change.design
    assert %FoPost.DesignVersion{id: "ver_1", version: 2} = change.version
  end

  test "delete answers the deletion", %{bypass: bypass} do
    Bypass.expect_once(bypass, "DELETE", "/v1/designs/des_1", fn conn ->
      TestSupport.json(conn, 200, %{"data" => %{"id" => "des_1", "deleted" => true}})
    end)

    assert {:ok, %FoPost.DesignDeletion{id: "des_1", deleted: true}} =
             Designs.delete(TestSupport.client(bypass), "des_1")
  end

  test "versions asks for documents only when told to", %{bypass: bypass} do
    Bypass.expect(bypass, "GET", "/v1/designs/des_1/versions", fn conn ->
      data =
        if conn.query_string == "include=document",
          do: Map.put(@version, "document", %{"pages" => []}),
          else: @version

      TestSupport.json(conn, 200, %{"data" => [data]})
    end)

    client = TestSupport.client(bypass)
    assert {:ok, [%FoPost.DesignVersion{document: nil}]} = Designs.versions(client, "des_1")

    assert {:ok, [%FoPost.DesignVersion{document: %{"pages" => []}}]} =
             Designs.versions(client, "des_1", include_document: true)
  end

  test "restore_version posts to the version and reads a null version", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/designs/des_1/versions/ver_1/restore", fn conn ->
      TestSupport.json(conn, 200, %{"data" => @design, "version" => nil})
    end)

    assert {:ok, change} = Designs.restore_version(TestSupport.client(bypass), "des_1", "ver_1")
    assert change.design.id == "des_1"
    assert change.version == nil
  end

  test "duplicate sends the new name", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/designs/des_1/duplicate", fn conn ->
      {decoded, conn} = body(conn)
      assert decoded == %{"name" => "Copy"}
      TestSupport.json(conn, 201, %{"data" => Map.put(@design, "id", "des_2")})
    end)

    assert {:ok, %FoPost.Design{id: "des_2"}} =
             Designs.duplicate(TestSupport.client(bypass), "des_1", name: "Copy")
  end

  test "export sends the format and pages and decodes the files", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/designs/des_1/export", fn conn ->
      {decoded, conn} = body(conn)
      assert decoded == %{"format" => "png", "page_indexes" => [0, 2]}

      TestSupport.json(conn, 200, %{
        "data" => %{
          "format" => "png",
          "files" => [
            %{
              "media_id" => "med_1",
              "page_index" => 0,
              "mime_type" => "image/png",
              "preview_url" => "https://api.fopost.com/v1/media/med_1/file"
            }
          ]
        }
      })
    end)

    assert {:ok, export} =
             Designs.export(TestSupport.client(bypass), "des_1",
               format: "png",
               page_indexes: [0, 2]
             )

    assert export.format == "png"
    assert [%FoPost.DesignExportFile{media_id: "med_1", page_index: 0}] = export.files
  end

  test "bulk sends the rows and decodes each design", %{bypass: bypass} do
    rows = [%{"title" => "One"}, %{"title" => "Two"}]

    Bypass.expect_once(bypass, "POST", "/v1/designs/des_1/bulk", fn conn ->
      {decoded, conn} = body(conn)
      assert decoded == %{"rows" => rows, "name_column" => "title"}
      TestSupport.json(conn, 201, %{"data" => [@design, Map.put(@design, "id", "des_3")]})
    end)

    assert {:ok, [_, %FoPost.Design{id: "des_3"}]} =
             Designs.bulk(TestSupport.client(bypass), "des_1", rows: rows, name_column: "title")
  end

  test "posts decodes the posts that used a design", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/designs/des_1/posts", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "id" => "post_1",
            "status" => "published",
            "title" => nil,
            "text" => "Hello",
            "schedule_at" => nil,
            "published_at" => "2026-11-19T09:00:00Z",
            "platforms" => ["linkedin"],
            "engagement" => 12,
            "views" => 340
          }
        ]
      })
    end)

    assert {:ok, [post]} = Designs.posts(TestSupport.client(bypass), "des_1")
    assert %FoPost.DesignPost{id: "post_1", platforms: ["linkedin"], views: 340} = post
    assert post.published_at == ~U[2026-11-19 09:00:00Z]
  end

  test "text_to_slides sends the text and decodes the outline", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/designs/text-to-slides", fn conn ->
      {decoded, conn} = body(conn)
      assert decoded == %{"workspace_id" => "ws_1", "text" => "Long thread", "max_slides" => 5}

      TestSupport.json(conn, 200, %{
        "data" => %{
          "cover" => %{"title" => "Title", "subtitle" => "Sub"},
          "slides" => [%{"heading" => "One", "body" => "First"}],
          "cta" => %{"heading" => "Follow", "body" => "More soon"},
          "brand" => %{"colors" => ["#000000"], "fonts" => %{}, "logo_media_id" => nil}
        }
      })
    end)

    assert {:ok, outline} =
             Designs.text_to_slides(TestSupport.client(bypass),
               workspace_id: "ws_1",
               text: "Long thread",
               max_slides: 5
             )

    assert outline.cover["title"] == "Title"
    assert [%{"heading" => "One"}] = outline.slides
    assert outline.brand["colors"] == ["#000000"]
  end

  test "from_post sends the post and style and decodes the design", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/designs/from-post", fn conn ->
      {decoded, conn} = body(conn)

      assert decoded == %{
               "workspace_id" => "ws_1",
               "post_id" => "post_1",
               "style" => "quote",
               "carousel" => false
             }

      TestSupport.json(conn, 201, %{"data" => @design})
    end)

    assert {:ok, %FoPost.Design{id: "des_1"}} =
             Designs.from_post(TestSupport.client(bypass),
               workspace_id: "ws_1",
               post_id: "post_1",
               style: "quote",
               carousel: false
             )
  end

  test "an error comes back as FoPost.Error and the bang raises it", %{bypass: bypass} do
    Bypass.expect(bypass, "GET", "/v1/designs/missing", fn conn ->
      TestSupport.json(conn, 404, %{"error" => "not_found", "message" => "Design not found"})
    end)

    client = TestSupport.client(bypass)

    assert {:error, %FoPost.Error{status: 404, code: "not_found"}} =
             Designs.get(client, "missing")

    assert_raise FoPost.Error, fn -> Designs.get!(client, "missing") end
  end
end
