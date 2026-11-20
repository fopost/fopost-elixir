defmodule FoPost.VideoEditsTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport
  alias FoPost.VideoEdits

  @job %{
    "id" => "job_1",
    "status" => "succeeded",
    "progress" => 1,
    "source_media_id" => "med_1",
    "operations" => [%{"op" => "trim", "params" => %{"startSec" => 0, "endSec" => 30}}],
    "result_media_id" => "med_2",
    "result_media" => %{
      "id" => "med_2",
      "preview_url" => "https://api.fopost.com/v1/media/med_2/file",
      "mime_type" => "video/mp4"
    },
    "extra_outputs" => [
      %{"media_id" => "med_3", "label" => "Clip 1", "mime" => "video/mp4", "preview_url" => nil}
    ],
    "result" => nil,
    "error" => nil,
    "created_at" => "2026-11-20T10:00:00Z",
    "updated_at" => "2026-11-20T10:01:00Z",
    "completed_at" => "2026-11-20T10:01:00Z"
  }

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "ops decodes each operation", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/video-edits/ops", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => [
          %{"name" => "trim", "available" => true, "uses_ai" => false},
          %{"name" => "subtitles", "available" => true, "uses_ai" => true}
        ]
      })
    end)

    assert {:ok, [trim, subtitles]} = VideoEdits.ops(TestSupport.client(bypass))
    assert %FoPost.VideoEditOp{name: "trim", uses_ai: false} = trim
    assert subtitles.uses_ai
  end

  test "list passes the filters and decodes each job", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/video-edits", fn conn ->
      assert conn.query_string == "workspace_id=ws_1&media_id=med_1&limit=5"
      TestSupport.json(conn, 200, %{"data" => [@job]})
    end)

    assert {:ok, [job]} =
             VideoEdits.list(TestSupport.client(bypass),
               workspace_id: "ws_1",
               media_id: "med_1",
               limit: 5
             )

    assert %FoPost.VideoEdit{id: "job_1", status: "succeeded", result_media_id: "med_2"} = job
    assert [%FoPost.VideoEditOutput{media_id: "med_3", label: "Clip 1"}] = job.extra_outputs
    assert job.completed_at == ~U[2026-11-20 10:01:00Z]
  end

  test "create sends the operations and the idempotency key", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/video-edits", fn conn ->
      assert Plug.Conn.get_req_header(conn, "idempotency-key") == ["edit-1"]
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "workspace_id" => "ws_1",
               "media_id" => "med_1",
               "operations" => [
                 %{"op" => "trim", "params" => %{"startSec" => 0, "endSec" => 30}},
                 %{"op" => "reframe", "params" => %{"aspect" => "9:16"}}
               ]
             }

      TestSupport.json(conn, 201, Map.merge(@job, %{"status" => "queued", "progress" => 0}))
    end)

    assert {:ok, %FoPost.VideoEdit{status: "queued", progress: 0}} =
             VideoEdits.create(TestSupport.client(bypass),
               workspace_id: "ws_1",
               media_id: "med_1",
               operations: [
                 %{op: "trim", params: %{startSec: 0, endSec: 30}},
                 %{op: "reframe", params: %{aspect: "9:16"}}
               ],
               idempotency_key: "edit-1"
             )
  end

  test "get reads one job", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/video-edits/job_1", fn conn ->
      assert conn.query_string == "workspace_id=ws_1"
      TestSupport.json(conn, 200, @job)
    end)

    assert {:ok, job} = VideoEdits.get(TestSupport.client(bypass), "job_1", workspace_id: "ws_1")
    assert job.result_media["mime_type"] == "video/mp4"
    assert [%{"op" => "trim"}] = job.operations
  end

  test "a missing ai scope comes back as FoPost.Error", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/video-edits", fn conn ->
      TestSupport.json(conn, 403, %{
        "error" => "forbidden",
        "message" => "Token does not have 'ai' permission"
      })
    end)

    assert_raise FoPost.Error, fn ->
      VideoEdits.create!(TestSupport.client(bypass),
        media_id: "med_1",
        operations: [%{op: "subtitles"}]
      )
    end
  end
end
