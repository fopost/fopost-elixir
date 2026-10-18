defmodule FoPost.AutomationVersionsTest do
  use ExUnit.Case, async: true

  alias FoPost.Automations
  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "versions pages the history and decodes what changed", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/automations/auto_1/versions", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"page" => "2", "per_page" => "5"}

      TestSupport.json(conn, 200, %{
        "data" => [
          %{
            "version" => 3,
            "note" => "Added a delay",
            "created_by" => %{"name" => "Ops"},
            "created_at" => "2026-10-18T10:00:00Z",
            "node_count" => 4,
            "nodes_added" => [%{"id" => "n4", "kind" => "delay", "label" => nil}],
            "nodes_removed" => []
          }
        ],
        "meta" => %{"page" => 2, "per_page" => 5, "total" => 6, "total_pages" => 2}
      })
    end)

    assert {:ok, page} =
             Automations.versions(TestSupport.client(bypass), "auto_1", page: 2, per_page: 5)

    assert [%FoPost.AutomationVersion{version: 3, node_count: 4} = version] = page.data
    assert version.created_by == %{"name" => "Ops"}
    assert [%FoPost.AutomationVersionNodeRef{id: "n4", kind: "delay"}] = version.nodes_added
    assert version.graph == nil
    assert page.meta.total == 6
  end

  test "version reads one version with its graph", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/automations/auto_1/versions/3", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => %{
          "version" => 3,
          "note" => nil,
          "created_by" => nil,
          "created_at" => "2026-10-18T10:00:00Z",
          "graph" => %{
            "nodes" => [
              %{
                "id" => "n1",
                "kind" => "trigger",
                "label" => "RSS",
                "config" => %{"url" => "https://yourbrand.com/feed.xml"},
                "position" => 0,
                "layout" => %{"x" => 10, "y" => 20}
              }
            ],
            "edges" => [
              %{"id" => "e1", "source" => "n1", "source_handle" => nil, "target" => "n2"}
            ]
          }
        }
      })
    end)

    assert {:ok, version} = Automations.version(TestSupport.client(bypass), "auto_1", 3)
    assert version.created_by == nil
    assert [%FoPost.WorkflowNode{id: "n1", kind: "trigger"} = node] = version.graph.nodes
    assert node.config == %{"url" => "https://yourbrand.com/feed.xml"}
    assert [%FoPost.WorkflowEdge{source: "n1", target: "n2"}] = version.graph.edges
  end

  test "restore_version posts and answers the new version", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/automations/auto_1/versions/2/restore", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => %{
          "version" => 4,
          "graph" => %{"nodes" => [], "edges" => []},
          "steps" => [
            %{
              "position" => 0,
              "node_id" => "n2",
              "action_type" => "publish",
              "action_config" => %{}
            }
          ]
        }
      })
    end)

    assert {:ok, restored} = Automations.restore_version(TestSupport.client(bypass), "auto_1", 2)
    assert %FoPost.AutomationRestore{version: 4} = restored
    assert restored.graph.nodes == []
    assert [%FoPost.AutomationStep{action_type: "publish", position: 0}] = restored.steps
  end
end
