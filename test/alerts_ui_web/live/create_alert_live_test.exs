defmodule AlertsUIWeb.CreateAlertLiveTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import AlertsUI.Support.Factory
  import Test.Support.Helpers
  alias AlertsUIWeb.FormComponents.{AlertDetails, RouteTypeAndEffect}

  describe "create alerts page" do
    @tag :logged_in_user
    test "connected mount displays a list of alerts when logged in", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/alerts/new")
      assert html =~ ~r/Create an Alert/
    end

    test "redirects the user when not logged in", %{conn: conn} do
      assert live(conn, "/alerts/new") ==
               {:error, {:redirect, %{to: "/auth/keycloak", flash: %{}}}}
    end

    @tag :logged_in_user
    test "submitting first part of form unhides second part", %{conn: conn} do
      insert(:alert, alert_id: "1")
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

      changeset =
        Ecto.Changeset.change(%AlertDetails{header_text: "cool", description_text: "bean"})

      send(view.pid, {:create_alert, changeset})

      failure_rendered_view = render(view)
      assert failure_rendered_view =~ "at least one field must be present"
    end

    @tag :logged_in_user
    test "displays warning if compare_feed is true", %{conn: conn} do
      reassign_env(:alerts_ui, :compare_feed, "true")
      {:ok, _view, html} = live(conn, "/alerts/new")

      assert html =~ ~s(! Please do not create Alerts on this server !)
      assert html =~ ~s(<div class=\"hidden\" id=\"article-view\">)
    end
  end
end
