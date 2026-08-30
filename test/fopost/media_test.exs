defmodule FoPost.MediaTest do
  use ExUnit.Case, async: true

  alias FoPost.MediaAsset
  alias FoPost.TestSupport

  test "upload sends a multipart body carrying the file and the workspace" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/v1/media/upload", fn conn ->
      assert [content_type] = Plug.Conn.get_req_header(conn, "content-type")
      assert content_type =~ "multipart/form-data"

      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert raw =~ "workspaceId"
      assert raw =~ "ws_1"
      assert raw =~ "chart.png"
      assert raw =~ "image/png"
      assert raw =~ "PNGBYTES"

      data = [%{"id" => "media_1", "type" => "image", "name" => "chart.png", "url" => "u"}]

      TestSupport.json(conn, 201, %{"data" => data})
    end)

    client = TestSupport.client(bypass)
    opts = [workspace_id: "ws_1", files: [{"chart.png", "PNGBYTES"}]]

    assert {:ok, [asset]} = FoPost.Media.upload(client, opts)
    assert asset.id == "media_1"
    assert MediaAsset.to_media_item(asset).url == "u"
  end

  test "list requires a workspace and decodes the library" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "GET", "/v1/media", fn conn ->
      assert conn.query_string == "workspaceId=ws_1"

      TestSupport.json(conn, 200, %{"data" => [%{"id" => "media_1", "size" => 12}]})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, [asset]} = FoPost.Media.list(client, workspace_id: "ws_1")
    assert asset.size == 12
  end
end
