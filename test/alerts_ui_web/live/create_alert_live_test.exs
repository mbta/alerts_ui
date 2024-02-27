defmodule AlertsUIWeb.CreateAlertLiveTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import AlertsUI.Support.Factory
  import Ecto.Changeset
  import Mock
  import Test.Support.Helpers
  alias AlertsUIWeb.FormComponents.{AffectedService, AlertDetails, RouteTypeAndEffect}

  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

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
      assert first_rendered_view =~ ~s(class="min-w-full flex flex-col" id="route_view")
      refute first_rendered_view =~ ~s(class="min-w-full flex flex-col" id="details_view")

      {:ok, changeset} =
        Ecto.Changeset.change(%RouteTypeAndEffect{route_type: 3, effect_name: "Detour"})
        |> apply_action(:insert)

      send(view.pid, {:step_completed, changeset})

      second_rendered_view = render(view)
      refute second_rendered_view =~ ~s(class="min-w-full flex flex-col" id="route_view")
      assert second_rendered_view =~ ~s(class="min-w-full flex flex-col" id="details_view")

      {:error, changeset} =
        Ecto.Changeset.change(%AlertDetails{})
        |> AlertDetails.changeset(%{header_text: "cool", description_text: nil})
        |> apply_action(:insert)

      send(view.pid, {:create_alert, changeset})
      failure_rendered_view = render(view)
      assert failure_rendered_view =~ "header_text: can&#39;t be blank"
    end

    @tag :logged_in_user
    test "submitting the second part of the form saves the alert", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      first_rendered_view = render(view)
      assert first_rendered_view =~ ~s(id="route_view")

      # Submit the first part
      {:ok, changeset} =
        Ecto.Changeset.change(%RouteTypeAndEffect{route_type: 3, effect_name: "Detour"})
        |> apply_action(:insert)

      send(view.pid, {:step_completed, changeset})
      second_rendered_view = render(view)
      assert second_rendered_view =~ ~s(id="details_view")

      # Submit service section
      {:ok, service_changeset} =
        Ecto.Changeset.change(%AffectedService{
          route_ids: ["1", "2"]
        })
        |> apply_action(:insert)

      send(view.pid, {:section_completed, service_changeset})

      # Submit the second part
      {:ok, details_changeset} =
        Ecto.Changeset.change(%AlertDetails{
          header_text: "Test header",
          description_text: "Test description"
        })
        |> apply_action(:insert)

      send(view.pid, {:create_alert, details_changeset})

      success_rendered_view = render(view)
      assert success_rendered_view =~ ~s(id="success_view")
    end

    @tag :logged_in_user
    test "clicking on timeline moves view back", %{conn: conn} do
      insert(:alert, alert_id: "1")
      {:ok, view, _html} = live(conn, "/alerts/new")

      {:ok, changeset} =
        Ecto.Changeset.change(%RouteTypeAndEffect{route_type: 3, effect_name: "Detour"})
        |> apply_action(:insert)

      send(view.pid, {:step_completed, changeset})

      clicked_view =
        view
        |> element("#route_type_and_effect")
        |> render_click()

      assert clicked_view =~ ~s(class="min-w-full flex flex-col" id="route_view")
      refute clicked_view =~ ~s(class="min-w-full flex flex-col" id="details_view")
    end

    @tag :logged_in_user
    test "displays stop names when route selected", %{conn: conn} do
      stops = [%Stop{id: "1", name: "cool stop name"}]

      with_mock(StopsRepo, by_route: fn _route, _direction -> stops end) do
        conn = log_in_user(conn)
        {:ok, view, _html} = live(conn, "/alerts/new")

        {:ok, changeset} =
          Ecto.Changeset.change(%RouteTypeAndEffect{route_type: 3, effect_name: "Detour"})
          |> apply_action(:insert)

        send(view.pid, {:step_completed, changeset})
        send(view.pid, {:fetch_available_routes, ["3"]})
        send(view.pid, {:fetch_available_stops, 0, ["12"]})

        view
        |> element("#service_form")
        |> render_change(%{
          "affected_service" => %{"route_ids" => ["1"], "directions" => "0"}
        }) =~ "cool stop name"
      end
    end

    @tag :logged_in_user
    test "save as draft redirects on success", %{conn: conn} do
      conn = log_in_user(conn)
      {:ok, view, _html} = live(conn, "/alerts/new")

      {:ok, changeset} =
        Ecto.Changeset.change(%RouteTypeAndEffect{
          route_type: 3,
          draft: true
        })
        |> apply_action(:insert)

      send(view.pid, {:save_as_draft, changeset})
      assert_redirect(view, "/alerts/new", 500)
    end

    @tag :logged_in_user
    test "save as draft shows error on error", %{conn: conn} do
      insert(:alert, alert_id: "1")
      conn = log_in_user(conn)
      {:ok, view, _html} = live(conn, "/alerts/new")

      {:ok, changeset} =
        Ecto.Changeset.change(%RouteTypeAndEffect{
          route_type: 3,
          draft: false
        })
        |> apply_action(:insert)

      send(view.pid, {:save_as_draft, changeset})
      rendered_view = render(view)

      rendered_view =~ "draft: draft status must be true"
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
