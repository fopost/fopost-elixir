defmodule FoPost.WhatsappTest do
  use ExUnit.Case, async: true

  alias FoPost.TestSupport

  test "a template create returns the review status the platform gave it" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/v1/accounts/a1/whatsapp/templates", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "name" => "order_shipped",
               "language" => "en_US",
               "category" => "UTILITY",
               "components" => [%{"type" => "BODY", "text" => "On its way."}]
             }

      TestSupport.json(conn, 200, %{
        "data" => %{
          "id" => "tpl-1",
          "name" => "order_shipped",
          "language" => "en_US",
          "category" => "UTILITY",
          "status" => "PENDING",
          "rejectedReason" => nil,
          "components" => [],
          "qualityScore" => nil
        }
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, template} =
             FoPost.Whatsapp.create_template(client, "a1",
               name: "order_shipped",
               language: "en_US",
               category: "UTILITY",
               components: [%{"type" => "BODY", "text" => "On its way."}]
             )

    # Nothing marks a template approved but the platform.
    assert template.status == "PENDING"
    assert template.name == "order_shipped"
  end

  test "deleting a template names it in the query" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "DELETE", "/v1/accounts/a1/whatsapp/templates/tpl-1", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["name"] == "order_shipped"
      TestSupport.json(conn, 200, %{"data" => %{"deleted" => true}})
    end)

    client = TestSupport.client(bypass)

    assert {:ok, %{"deleted" => true}} =
             FoPost.Whatsapp.delete_template(client, "a1", "tpl-1", name: "order_shipped")
  end

  test "a sandbox session carries only the last four digits" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/v1/whatsapp/sandbox/sessions", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(raw) == %{
               "workspaceId" => "ws",
               "phoneNumber" => "+15551234567"
             }

      TestSupport.json(conn, 200, %{
        "data" => %{
          "id" => "ses-1",
          "status" => "invited",
          "phoneNumberLast4" => "4567",
          "invitedAt" => "2026-09-20T10:00:00Z",
          "activatedAt" => nil,
          "expiresAt" => "2026-09-21T10:00:00Z"
        }
      })
    end)

    client = TestSupport.client(bypass)

    assert {:ok, session} =
             FoPost.Whatsapp.create_sandbox_session(client,
               workspace_id: "ws",
               phone_number: "+15551234567"
             )

    assert session.phone_number_last4 == "4567"
    assert session.status == "invited"
  end
end
