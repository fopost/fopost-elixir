defmodule FoPost.FontsTest do
  use ExUnit.Case, async: true

  alias FoPost.Fonts
  alias FoPost.TestSupport

  @font %{
    "id" => "font_1",
    "family" => "Brand",
    "style" => "normal",
    "weight" => 700,
    "format" => "woff2",
    "file_url" => "https://api.fopost.com/v1/fonts/font_1/file",
    "created_at" => "2026-11-20T10:00:00Z"
  }

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "list reads the library and the workspace's uploads", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/fonts", fn conn ->
      assert conn.query_string == "workspace_id=ws_1"

      TestSupport.json(conn, 200, %{
        "library" => [
          %{
            "slug" => "geist",
            "family" => "Geist",
            "category" => "sans-serif",
            "scripts" => ["latin"],
            "weights" => [400, 700],
            "files" => [%{"path" => "geist.woff2", "subset" => "latin"}]
          }
        ],
        "uploaded" => [@font]
      })
    end)

    assert {:ok, fonts} = Fonts.list(TestSupport.client(bypass), "ws_1")
    assert [%FoPost.LibraryFont{slug: "geist", weights: [400, 700]}] = fonts.library
    assert [%FoPost.Font{id: "font_1", weight: 700}] = fonts.uploaded
  end

  test "list without a workspace sends no query", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/fonts", fn conn ->
      assert conn.query_string == ""
      TestSupport.json(conn, 200, %{"library" => [], "uploaded" => []})
    end)

    assert {:ok, %FoPost.FontList{library: [], uploaded: []}} =
             Fonts.list(TestSupport.client(bypass))
  end

  test "upload sends a multipart form with the file and fields", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/fonts", fn conn ->
      [content_type] = Plug.Conn.get_req_header(conn, "content-type")
      assert content_type =~ "multipart/form-data"

      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert raw =~ ~s(name="workspace_id")
      assert raw =~ "ws_1"
      assert raw =~ ~s(name="weight")
      assert raw =~ "700"
      assert raw =~ ~s(filename="Brand-Bold.woff2")
      assert raw =~ "content-type: font/woff2"
      assert raw =~ "wOF2bytes"

      TestSupport.json(conn, 201, @font)
    end)

    assert {:ok, %FoPost.Font{id: "font_1", family: "Brand", format: "woff2"} = font} =
             Fonts.upload(TestSupport.client(bypass),
               workspace_id: "ws_1",
               file: {"Brand-Bold.woff2", "wOF2bytes"},
               family: "Brand",
               weight: 700
             )

    assert font.created_at == ~U[2026-11-20 10:00:00Z]
  end

  test "upload reads a file from a path", %{bypass: bypass} do
    path = Path.join(System.tmp_dir!(), "fopost-font-#{System.unique_integer([:positive])}.ttf")
    File.write!(path, "ttfbytes")
    on_exit(fn -> File.rm(path) end)

    Bypass.expect_once(bypass, "POST", "/v1/fonts", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert raw =~ ~s(filename="#{Path.basename(path)}")
      assert raw =~ "content-type: font/ttf"
      assert raw =~ "ttfbytes"
      TestSupport.json(conn, 201, @font)
    end)

    assert {:ok, %FoPost.Font{}} =
             Fonts.upload(TestSupport.client(bypass), workspace_id: "ws_1", file: path)
  end

  test "delete answers :ok on a 204", %{bypass: bypass} do
    Bypass.expect_once(bypass, "DELETE", "/v1/fonts/font_1", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    assert :ok = Fonts.delete(TestSupport.client(bypass), "font_1")
  end

  test "an oversized upload comes back as FoPost.Error", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/fonts", fn conn ->
      TestSupport.json(conn, 413, %{
        "error" => "file_too_large",
        "message" => "Font files can be up to 5 MB"
      })
    end)

    assert_raise FoPost.Error, fn ->
      Fonts.upload!(TestSupport.client(bypass), workspace_id: "ws_1", file: {"big.otf", "x"})
    end
  end
end
