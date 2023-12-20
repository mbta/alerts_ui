defmodule AlertsUIWeb.AlertsLiveTest do
  use ExUnit.Case
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import AlertsUI.Support.Factory

  describe "alerts list page" do
    setup do
      insert(:alert, %{alert_id: "123"})
      :ok
    end

    test "connected mount displays a list of alerts when logged in", %{conn: conn} do
      conn = log_in_user(conn)

      {:ok, _view, html} = live(conn, "/alerts")
      assert html =~ ~r/Alerts/
      assert html =~ ~r/123/
    end

    test "redirects the user when not logged in", %{conn: conn} do
      assert live(conn, "/alerts") == {:error, {:redirect, %{to: "/auth/keycloak", flash: %{}}}}
    end
  end
end
