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

  test "limits asks for the workspace and decodes every ceiling" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "GET", "/v1/media/limits", fn conn ->
      assert conn.query_string == "workspaceId=ws_1"

      data = %{
        "maxFileBytes" => 419_430_400,
        "source" => "accounts",
        "connectedAccounts" => 5,
        "largeUploadsEnabled" => false,
        "nextTier" => %{"upToAccounts" => 15, "maxFileBytes" => 2_147_483_648},
        "multipartMaxFileBytes" => 104_857_600,
        "maxFilesPerUpload" => 5,
        "directUploadAvailable" => true,
        "allowedTypes" => ["image/png", "video/mp4"]
      }

      TestSupport.json(conn, 200, %{"data" => data})
    end)

    assert {:ok, %FoPost.UploadLimits{} = limits} =
             FoPost.Media.limits(TestSupport.client(bypass), "ws_1")

    assert limits.max_file_bytes == 419_430_400
    assert limits.source == "accounts"
    assert limits.connected_accounts == 5
    assert limits.large_uploads_enabled == false
    assert limits.next_tier == %{up_to_accounts: 15, max_file_bytes: 2_147_483_648}
    assert limits.multipart_max_file_bytes == 104_857_600
    assert limits.max_files_per_upload == 5
    assert limits.direct_upload_available == true
    assert limits.allowed_types == ["image/png", "video/mp4"]
  end

  test "limits without a workspace sends no query" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "GET", "/v1/media/limits", fn conn ->
      assert conn.query_string == ""

      TestSupport.json(conn, 200, %{"data" => %{"maxFileBytes" => 104_857_600}})
    end)

    assert {:ok, %FoPost.UploadLimits{max_file_bytes: 104_857_600}} =
             FoPost.Media.limits(TestSupport.client(bypass))
  end

  test "presign carries the optional fields and lifts max_file_bytes" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/v1/media/presign", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "workspaceId" => "ws_1",
               "filename" => "ceo.png",
               "mimeType" => "image/png",
               "size" => 5_368_709_120,
               "folderId" => "fld_1",
               "origin" => "chat",
               "brandRole" => "person",
               "brandVoiceId" => "bv_1",
               "personConsent" => %{"subject" => "A. Person", "statement" => "agreed"}
             }

      data = %{"uploadId" => "up_1", "uploadUrl" => "u", "maxFileBytes" => 5_368_709_120}

      TestSupport.json(conn, 201, %{"data" => data})
    end)

    opts = [
      workspace_id: "ws_1",
      filename: "ceo.png",
      mime_type: "image/png",
      size: 5_368_709_120,
      folder_id: "fld_1",
      origin: "chat",
      brand_role: "person",
      brand_voice_id: "bv_1",
      person_consent: %{subject: "A. Person", statement: "agreed"}
    ]

    assert {:ok, presigned} = FoPost.Media.presign(TestSupport.client(bypass), opts)
    assert presigned.max_file_bytes == 5_368_709_120
  end

  test "an oversize presign is a 413 whose body says how large a file may be" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/v1/media/presign", fn conn ->
      TestSupport.json(conn, 413, %{
        "error" => "file_too_large",
        "message" => "That file is larger than this account allows.",
        "max_file_bytes" => 104_857_600,
        "file_bytes" => 209_715_200,
        "upgrade_url" => "https://app.fopost.com/settings/billing"
      })
    end)

    opts = [workspace_id: "ws_1", filename: "a.mp4", mime_type: "video/mp4", size: 209_715_200]

    assert {:error, %FoPost.Error{} = error} =
             FoPost.Media.presign(TestSupport.client(bypass), opts)

    assert error.status == 413
    assert error.code == "file_too_large"
    assert error.body["max_file_bytes"] == 104_857_600
    assert error.body["file_bytes"] == 209_715_200
    assert error.upgrade_url == "https://app.fopost.com/settings/billing"
  end

  test "upload_direct streams a file from disk with its size declared" do
    bypass = Bypass.open()
    path = Path.join(System.tmp_dir!(), "fopost-#{System.unique_integer([:positive])}.png")
    File.write!(path, "PNGBYTES")
    on_exit(fn -> File.rm(path) end)

    Bypass.expect_once(bypass, "POST", "/v1/media/presign", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw)["size"] == 8
      assert Jason.decode!(raw)["folderId"] == "fld_1"

      data = %{
        "uploadId" => "up_1",
        "uploadUrl" => "http://localhost:#{bypass.port}/bucket/up_1",
        "method" => "PUT",
        "headers" => %{"Content-Type" => "image/png"}
      }

      TestSupport.json(conn, 201, %{"data" => data})
    end)

    Bypass.expect_once(bypass, "PUT", "/bucket/up_1", fn conn ->
      assert Plug.Conn.get_req_header(conn, "x-api-key") == []
      assert Plug.Conn.get_req_header(conn, "content-length") == ["8"]
      {:ok, "PNGBYTES", conn} = Plug.Conn.read_body(conn)

      Plug.Conn.resp(conn, 200, "")
    end)

    Bypass.expect_once(bypass, "POST", "/v1/media/presign/up_1/complete", fn conn ->
      TestSupport.json(conn, 201, %{"data" => %{"id" => "media_1"}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %MediaAsset{id: "media_1"}} =
             FoPost.Media.upload_direct(client, "ws_1", "chart.png", "image/png", {:file, path},
               folder_id: "fld_1"
             )
  end
end
