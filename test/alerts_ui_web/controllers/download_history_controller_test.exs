defmodule AlertsUIWeb.DownloadHistoryControllerTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase, async: false

  import Test.Support.Helpers

  alias Oidcc.{ClientContext, Token}
  alias Plug.Conn

  describe "GET /download_history" do
    setup do
      reassign_env(:ueberauth_oidcc, :providers, %{
        keycloak: %{
          client_id: "FAKE_KEYCLOAK_CLIENT_ID",
          client_secret: "FAKE_KEYCLOAK_CLIENT_SECRET"
        }
      })
    end

    test "when unauthenticated, redirects", %{
      conn: conn
    } do
      conn = get(conn, "/download_history?1")
      assert response(conn, 302) =~ ~s(You are being <a href=\"/auth/keycloak\">redirected</a>.)
    end
  end
end
