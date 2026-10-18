defmodule FoPost.ConnectSessionsTest do
  use ExUnit.Case, async: true

  alias FoPost.ConnectSessions
  alias FoPost.TestSupport

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "create sends the camelCase body and decodes the session", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/connect-sessions", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "workspaceId" => "ws_1",
               "externalUserId" => "user_42",
               "platforms" => ["twitter", "linkedin"],
               "redirectUrl" => "https://app.yourbrand.com/connected",
               "branding" => %{
                 "name" => "Your Brand",
                 "logoUrl" => "https://yourbrand.com/logo.png"
               }
             }

      TestSupport.json(conn, 201, %{
        "data" => %{
          "id" => "cs_1",
          "status" => "pending",
          "external_user_id" => "user_42",
          "platforms" => ["twitter", "linkedin"],
          "redirect_url" => "https://app.yourbrand.com/connected",
          "branding" => %{"name" => "Your Brand", "logo_url" => "https://yourbrand.com/logo.png"},
          "account_id" => nil,
          "url" => "https://connect.fopost.com/s/cs_1",
          "expires_at" => "2026-10-18T11:00:00Z",
          "used_at" => nil,
          "created_at" => "2026-10-18T10:00:00Z"
        }
      })
    end)

    assert {:ok, session} =
             ConnectSessions.create(TestSupport.client(bypass),
               workspace_id: "ws_1",
               external_user_id: "user_42",
               platforms: ["twitter", "linkedin"],
               redirect_url: "https://app.yourbrand.com/connected",
               branding: %{name: "Your Brand", logo_url: "https://yourbrand.com/logo.png"}
             )

    assert %FoPost.ConnectSession{id: "cs_1", status: "pending"} = session
    assert session.url == "https://connect.fopost.com/s/cs_1"
    assert session.platforms == ["twitter", "linkedin"]
    assert session.branding.name == "Your Brand"
    assert session.expires_at == ~U[2026-10-18 11:00:00Z]
  end

  test "get reads one session", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/connect-sessions/cs_1", fn conn ->
      TestSupport.json(conn, 200, %{
        "data" => %{
          "id" => "cs_1",
          "status" => "used",
          "external_user_id" => "user_42",
          "platforms" => ["twitter"],
          "account_id" => "acc_1",
          "expires_at" => "2026-10-18T11:00:00Z",
          "used_at" => "2026-10-18T10:30:00Z",
          "created_at" => "2026-10-18T10:00:00Z"
        }
      })
    end)

    assert {:ok, session} = ConnectSessions.get(TestSupport.client(bypass), "cs_1")
    assert session.status == "used"
    assert session.account_id == "acc_1"
    assert session.url == nil
    assert session.branding == nil
    assert session.used_at == ~U[2026-10-18 10:30:00Z]
  end
end
