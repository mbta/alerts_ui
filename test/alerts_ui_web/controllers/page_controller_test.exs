defmodule AlertsUIWeb.PageControllerTest do
  use AlertsUIWeb.ConnCase

  describe "GET /" do
    test "when logged in, displays the home page", %{conn: conn} do
      conn =
        conn
        |> log_in_user()
        |> get(~p"/")

      assert html_response(conn, 200) =~ "Peace of mind from prototype to production"
    end

    test "when logged out, redirects to the login", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert redirected_to(conn) == ~p"/auth/keycloak"
    end
  end
end
