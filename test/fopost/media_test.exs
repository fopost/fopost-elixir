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

  test "presign posts the declared file and decodes the upload slot" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/v1/media/presign", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "workspaceId" => "ws_1",
               "filename" => "chart.png",
               "mimeType" => "image/png",
               "size" => 8
             }

      data = %{
        "uploadId" => "up_1",
        "uploadUrl" => "http://localhost:#{bypass.port}/bucket/up_1",
        "method" => "PUT",
        "headers" => %{"Content-Type" => "image/png"},
        "expiresAt" => "2026-09-19T12:00:00Z"
      }

      TestSupport.json(conn, 201, %{"data" => data})
    end)

    client = TestSupport.client(bypass)
    opts = [workspace_id: "ws_1", filename: "chart.png", mime_type: "image/png", size: 8]

    assert {:ok, presigned} = FoPost.Media.presign(client, opts)
    assert presigned.upload_id == "up_1"
    assert presigned.method == "PUT"
    assert presigned.headers == %{"Content-Type" => "image/png"}
    assert presigned.expires_at == ~U[2026-09-19 12:00:00Z]
  end

  test "upload_direct presigns, puts the bytes without the API key, and completes" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/v1/media/presign", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw)["size"] == 8

      data = %{
        "uploadId" => "up_1",
        "uploadUrl" => "http://localhost:#{bypass.port}/bucket/up_1",
        "method" => "PUT",
        "headers" => %{"Content-Type" => "image/png"},
        "expiresAt" => "2026-09-19T12:00:00Z"
      }

      TestSupport.json(conn, 201, %{"data" => data})
    end)

    Bypass.expect_once(bypass, "PUT", "/bucket/up_1", fn conn ->
      assert Plug.Conn.get_req_header(conn, "x-api-key") == []
      assert Plug.Conn.get_req_header(conn, "content-type") == ["image/png"]
      assert Plug.Conn.get_req_header(conn, "content-length") == ["8"]

      {:ok, "PNGBYTES", conn} = Plug.Conn.read_body(conn)

      Plug.Conn.resp(conn, 200, "")
    end)

    Bypass.expect_once(bypass, "POST", "/v1/media/presign/up_1/complete", fn conn ->
      assert Plug.Conn.get_req_header(conn, "x-api-key") == ["fp_test_key"]

      data = %{"id" => "media_1", "type" => "image", "name" => "chart.png", "size" => 8}

      TestSupport.json(conn, 201, %{"data" => data})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %MediaAsset{} = asset} =
             FoPost.Media.upload_direct(client, "ws_1", "chart.png", "image/png", "PNGBYTES")

    assert asset.id == "media_1"
  end

  test "upload_direct stops with the error when the put is refused" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/v1/media/presign", fn conn ->
      data = %{
        "uploadId" => "up_1",
        "uploadUrl" => "http://localhost:#{bypass.port}/bucket/up_1",
        "method" => "PUT",
        "headers" => %{"Content-Type" => "image/png"}
      }

      TestSupport.json(conn, 201, %{"data" => data})
    end)

    Bypass.expect_once(bypass, "PUT", "/bucket/up_1", fn conn ->
      Plug.Conn.resp(conn, 403, "denied")
    end)

    client = TestSupport.client(bypass)

    assert {:error, %FoPost.Error{status: 403}} =
             FoPost.Media.upload_direct(client, "ws_1", "chart.png", "image/png", "PNGBYTES")
  end
end
