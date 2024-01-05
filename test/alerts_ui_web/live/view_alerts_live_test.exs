defmodule AlertsUIWeb.AlertsLiveTest do
  use ExUnit.Case
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import AlertsUI.Support.Factory

  describe "alerts list page" do
    setup do
      insert(:alert, %{
        alert_id: "123",
        active_period: [
          build(:active_period, %{start: ~U[2023-10-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-10-13 00:01:00Z]})
        ],
        header_text: "this is the first alert"
      })

      insert(:alert, %{
        alert_id: "234",
        active_period: [
          build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
        ],
        header_text: "this is the second alert"
      })

      :ok
    end

    test "connected mount displays a list of alerts when logged in", %{conn: conn} do
      conn = log_in_user(conn)

      {:ok, _view, html} = live(conn, "/alerts")
      assert html =~ ~r/Alerts/
    end

    test "redirects the user when not logged in", %{conn: conn} do
      assert live(conn, "/alerts") == {:error, {:redirect, %{to: "/auth/keycloak", flash: %{}}}}
    end

    test "sorting click event", %{conn: conn} do
      conn = log_in_user(conn)

      {:ok, view, _html} = live(conn, "/alerts")
      assert view |> render_click("sort-alerts", %{"order" => "active_period_start"}) =~ "123"
    end
  end
end
