defmodule AlertsUIWeb.ComponentsLiveTest do
  use ExUnit.Case
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "components style guide page" do
    @tag :logged_in_user
    test "connected mount displays a list of components when logged in", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/components")
      assert html =~ ~r/Components Style Guide/
    end

    test "redirects the user when not logged in", %{conn: conn} do
      assert live(conn, "/components") ==
               {:error, {:redirect, %{to: "/auth/keycloak", flash: %{}}}}
    end
  end
end
