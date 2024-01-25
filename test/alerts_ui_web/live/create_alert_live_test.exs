defmodule AlertsUIWeb.CreateAlertLiveTest do
  use ExUnit.Case
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  alias AlertsUIWeb.FormComponents.RouteTypeAndEffect

  describe "create alerts page" do
    test "connected mount displays a list of alerts when logged in", %{conn: conn} do
      conn = log_in_user(conn)

      {:ok, _view, html} = live(conn, "/alerts/new")
      assert html =~ ~r/Create an Alert/
    end

    test "redirects the user when not logged in", %{conn: conn} do
      assert live(conn, "/alerts/new") ==
               {:error, {:redirect, %{to: "/auth/keycloak", flash: %{}}}}
    end

    test "submitting first part of form unhides second part", %{conn: conn} do
      conn = log_in_user(conn)
      {:ok, view, _html} = live(conn, "/alerts/new")

      first_rendered_view = render(view)
      assert first_rendered_view =~ ~s(class="min-w-full" id="route_view")
      refute first_rendered_view =~ ~s(class="min-w-full" id="details_view")

      changeset =
        Ecto.Changeset.change(%RouteTypeAndEffect{route_type: "3", effect_name: "Detour"})

      send(view.pid, {:step_completed, changeset})

      second_rendered_view = render(view)
      refute second_rendered_view =~ ~s(class="min-w-full" id="route_view")
      assert second_rendered_view =~ ~s(class="min-w-full" id="details_view")
    end
  end
end
