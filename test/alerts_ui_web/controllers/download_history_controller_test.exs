defmodule AlertsUIWeb.DownloadHistoryControllerTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase, async: false
  import AlertsUI.Support.Factory

  alias AlertsUI.Alerts
  alias Plug.Conn

  describe "GET /download_history/download with alert id parameter" do
    @tag :logged_in_user
    test "when authorized, returns 200 with file", %{conn: conn} do
      user =
        insert(:user, %{
          first_name: "Herbert",
          last_name: "Pocket"
        })

      Alerts.create_or_update_alert(
        build(
          :alert_map,
          %{alert_id: "1234567", duration_certainty: :KNOWN}
        ),
        user
      )

      conn =
        conn
        |> Conn.put_req_header("authorization", "Bearer FAKE_TOKEN")
        |> get("/download_history/download?alert_id=1234567")

      assert conn.status == 200
      assert is_binary(conn.resp_body)
    end

    test "when unauthenticated, redirects", %{
      conn: conn
    } do
      conn = get(conn, "/download_history/download?alert_id=1")
      assert response(conn, 302) =~ ~s(You are being <a href=\"/auth/keycloak\">redirected</a>.)
    end
  end

  describe "POST /download_history/download with month and year parameters" do
    @tag :logged_in_user
    test "when authorized, returns 200 with file", %{conn: conn} do
      conn =
        conn
        |> Conn.put_req_header("authorization", "Bearer FAKE_TOKEN")
        |> post("/download_history/download_bulk?month=6&year=2026")

      assert conn.status == 200
      assert is_binary(conn.resp_body)
    end

    test "when unauthenticated, redirects", %{
      conn: conn
    } do
      conn = get(conn, "/download_history/download")
      assert response(conn, 302) =~ ~s(You are being <a href=\"/auth/keycloak\">redirected</a>.)
    end
  end
end
