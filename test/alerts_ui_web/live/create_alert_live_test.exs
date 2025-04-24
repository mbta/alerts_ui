defmodule AlertsUIWeb.CreateAlertLiveTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import AlertsUI.Support.Factory
  import Ecto.Changeset
  import Mock
  alias AlertsUIWeb.CreateAlertLive
  alias AlertsUIWeb.FormComponents.{AffectedService, AlertDetails, RouteTypeAndEffect, TimeRange}
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.RoutePatterns.RoutePattern
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @route %Route{
    direction_names: %{0 => "Westbound", 1 => "Eastbound"},
    sort_order: 3,
    id: "CR-Worcester",
    type: 2,
    name: "Framingham/Worcester Line"
  }

  @stop %Stop{id: "place-sstat", name: "South Station"}

  @route_pattern %RoutePattern{direction_id: 0, stops: [@stop], route_id: "CR-Worcester"}

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
      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [@route_pattern] end,
           included_stops_by_route_id: fn _route_id, _ -> [@stop] end
         ]},
        {StopsRepo, [], by_route: fn _, _ -> [@stop] end},
        {RoutesRepo, [], [by_type: fn _type -> [@route] end, get: fn _id, _opts -> @route end]}
      ]) do
        insert(:alert, alert_id: "1")
        {:ok, view, _html} = live(conn, "/alerts/new")

        first_rendered_view = render_async(view)
        assert first_rendered_view =~ ~s(class="min-w-full flex flex-col mb-8" id="route_view")
        refute first_rendered_view =~ ~s(class="min-w-full flex flex-col mt-4" id="details_view")

        {:ok, changeset} =
          Ecto.Changeset.change(%RouteTypeAndEffect{route_type: 2, effect_name: "Suspension"})
          |> apply_action(:insert)

        send(view.pid, {:step_completed, changeset})

        second_rendered_view = render_async(view)

        refute second_rendered_view =~ ~s(class="min-w-full flex flex-col mb-8" id="route_view")
        assert second_rendered_view =~ ~s(class="min-w-full flex flex-col mt-4" id="details_view")

        # Submit service section
        {:ok, service_changeset} =
          Ecto.Changeset.change(%AffectedService{
            route_ids: [@route.id],
            direction: "default",
            stop_ids: [@stop.id]
          })
          |> apply_action(:insert)

        send(view.pid, {:section_completed, service_changeset})

        {:error, changeset} =
          Ecto.Changeset.change(%AlertDetails{})
          |> AlertDetails.changeset(%{header_text: nil})
          |> validate_required([:header_text])
          |> apply_action(:validate)

        send(view.pid, {:add_errors, [], AffectedService})
        send(view.pid, {:section_completed, changeset})
        send(view.pid, :create_alert)
        failure_rendered_view = render(view)
        assert failure_rendered_view =~ "Enter message text"

        {:ok, changeset} =
          Ecto.Changeset.change(%AlertDetails{})
          |> AlertDetails.changeset(%{header_text: "cool"})
          |> apply_action(:validate)

        send(view.pid, {:add_errors, [], AlertDetails})
        send(view.pid, {:section_completed, changeset})
        send(view.pid, :create_alert)

        rendered_view = render_async(view)

        assert rendered_view =~ "created successfully"
      end
    end

    @tag :logged_in_user
    test "shows correct affected service for access combination", %{conn: conn} do
      with_mocks([
        {RoutePatternsRepo, [], [included_stops_by_route_id: fn _route_id, _direction -> [] end]},
        {FacilitiesRepo, [], get_by_type: fn _types, _opts -> [] end}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        {:ok, changeset} =
          Ecto.Changeset.change(%RouteTypeAndEffect{
            route_type: nil,
            effect_name: "Parking Issue"
          })
          |> apply_action(:insert)

        send(view.pid, {:step_completed, changeset})
        rendered_view = render(view)
        assert rendered_view =~ ~s(id="access_service_view")
      end
    end

    @tag :logged_in_user
    test "shows correct affected service for systemwide combination", %{conn: conn} do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
        insert(:alert, alert_id: "1")
        {:ok, view, _html} = live(conn, "/alerts/new")

        {:ok, changeset} =
          Ecto.Changeset.change(%RouteTypeAndEffect{route_type: nil, effect_name: "Summary"})
          |> apply_action(:insert)

        send(view.pid, {:step_completed, changeset})
        rendered_view = render(view)
        assert rendered_view =~ ~s(id="systemwide_service_view")
      end
    end

    @tag :logged_in_user
    test "shows correct affected service for stop route combination", %{conn: conn} do
      with_mocks([
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]},
        {StopsRepo, [], by_route_type: fn _route_type, _opts -> [] end}
      ]) do
        insert(:alert, alert_id: "1")
        {:ok, view, _html} = live(conn, "/alerts/new")

        {:ok, changeset} =
          Ecto.Changeset.change(%RouteTypeAndEffect{route_type: 3, effect_name: "Stop Move"})
          |> apply_action(:insert)

        send(view.pid, {:step_completed, changeset})
        rendered_view = render(view)
        assert rendered_view =~ ~s(id="stop_route_service_view")
      end
    end

    @tag :logged_in_user
    test "shows correct affected service for other combination", %{conn: conn} do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
        insert(:alert, alert_id: "1")
        {:ok, view, _html} = live(conn, "/alerts/new")

        {:ok, changeset} =
          Ecto.Changeset.change(%RouteTypeAndEffect{route_type: 3, effect_name: "Detour"})
          |> apply_action(:insert)

        send(view.pid, {:step_completed, changeset})
        rendered_view = render(view)
        assert rendered_view =~ ~s(id="service_view")
      end
    end

    @tag :logged_in_user
    test "submitting the second part of the form saves the alert", %{conn: conn} do
      with_mocks([
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [@route_pattern] end]},
        {StopsRepo, [], by_route: fn _, _ -> [@stop] end},
        {RoutesRepo, [], [by_type: fn _type -> [@route] end, get: fn _id, _opts -> @route end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        first_rendered_view = render(view)
        assert first_rendered_view =~ ~s(id="route_view")

        # Submit the first part
        {:ok, changeset} =
          Ecto.Changeset.change(%RouteTypeAndEffect{route_type: 2, effect_name: "Suspension"})
          |> apply_action(:insert)

        send(view.pid, {:step_completed, changeset})
        second_rendered_view = render(view)
        assert second_rendered_view =~ ~s(id="details_view")

        # Submit service section
        {:ok, service_changeset} =
          Ecto.Changeset.change(%AffectedService{
            route_ids: ["1", "2"],
            direction: "default",
            stop_ids: []
          })
          |> apply_action(:insert)

        send(view.pid, {:section_completed, service_changeset})

        # Submit time range
        {:ok, time_range_changeset} =
          Ecto.Changeset.change(%TimeRange{
            active_period_end_specifier: :later_today,
            active_period_start: ~N[2024-04-30 11:54:00]
          })
          |> apply_action(:insert)

        send(view.pid, {:section_completed, time_range_changeset})

        # Submit details
        {:ok, details_changeset} =
          Ecto.Changeset.change(%AlertDetails{
            header_text: "Test header",
            description_text: "Test description"
          })
          |> apply_action(:insert)

        send(view.pid, {:add_errors, [], AffectedService})
        send(view.pid, {:add_errors, [], AlertDetails})
        send(view.pid, {:section_completed, details_changeset})
        send(view.pid, :create_alert)

        success_rendered_view = render(view)
        assert success_rendered_view =~ ~s(id="success_view")
      end
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

      assert clicked_view =~ ~s(class="min-w-full flex flex-col mb-8" id="route_view")
      refute clicked_view =~ ~s(class="min-w-full flex flex-col mt-4" id="details_view")
    end

    @tag :logged_in_user
    test "displays stop names when route selected", %{conn: conn} do
      stops = [%Stop{id: "1", name: "cool stop name"}]

      with_mocks([
        {StopsRepo, [], by_route: fn _route, _direction -> stops end},
        {SchedulesRepo, [], by_route_ids: fn _route_ids, _opts -> [] end}
      ]) do
        conn = log_in_user(conn)
        {:ok, view, _html} = live(conn, "/alerts/new")

        {:ok, changeset} =
          Ecto.Changeset.change(%RouteTypeAndEffect{route_type: 3, effect_name: "Detour"})
          |> apply_action(:insert)

        send(view.pid, {:step_completed, changeset})

        view
        |> element("#service_form")
        |> render_change(%{
          "affected_service" => %{"single_route_id" => "1", "directions" => "0", "stop_ids" => []}
        })

        assert render(view) =~ "cool stop name"
      end
    end

    @tag :logged_in_user
    test "displays a list of facilities", %{conn: conn} do
      :ELEVATOR_CLOSURE

      facilities = [
        %Facility{id: "1", long_name: "real big elevator", stop: %Stop{id: 2, name: "stop"}}
      ]

      with_mocks([
        {RoutePatternsRepo, [], [included_stops_by_route_id: fn _route_id, _direction -> [] end]},
        {FacilitiesRepo, [], get_by_type: fn _types, _opts -> facilities end}
      ]) do
        conn = log_in_user(conn)
        {:ok, view, _html} = live(conn, "/alerts/new")

        {:ok, changeset} =
          Ecto.Changeset.change(%RouteTypeAndEffect{
            route_type: nil,
            effect_name: "Elevator Closure"
          })
          |> apply_action(:insert)

        send(view.pid, {:step_completed, changeset})

        view |> render_async

        assert view
               |> element("#service_form")
               |> render_async() =~ "real big elevator"
      end
    end
  end

  describe "filter_out_old_trips/2" do
    test "properly filters out trips whose arrival time for the last trip is in the past" do
      current_time = ~U[2024-11-15 14:06:43Z]

      schedules = [
        %MBTAV3API.Schedules.Schedule{
          trip: %MBTAV3API.Schedules.Trip{
            id: "FRMLThuFri-709657-400",
            name: "400"
          },
          stop: %MBTAV3API.Stops.Stop{
            id: "place-sstat",
            name: "South Station"
          },
          arrival_time: nil,
          departure_time: ~U[2024-11-15 10:01:43Z]
        },
        %MBTAV3API.Schedules.Schedule{
          trip: %MBTAV3API.Schedules.Trip{
            id: "FRMLThuFri-709657-400",
            name: "400"
          },
          stop: %Stop{id: "place-WML-0214", name: "Framingham"},
          arrival_time: ~U[2024-11-15 12:01:00Z],
          departure_time: nil
        },
        %MBTAV3API.Schedules.Schedule{
          trip: %MBTAV3API.Schedules.Trip{
            id: "FRMLThuFri-709637-485",
            name: "485"
          },
          stop: %MBTAV3API.Stops.Stop{
            id: "place-sstat",
            name: "South Station"
          },
          arrival_time: nil,
          departure_time: ~U[2024-11-15 14:30:00Z]
        },
        %MBTAV3API.Schedules.Schedule{
          trip: %MBTAV3API.Schedules.Trip{
            id: "FRMLThuFri-709637-485",
            name: "485"
          },
          stop: %Stop{id: "place-WML-0214", name: "Framingham"},
          arrival_time: ~U[2024-11-15 15:25:00Z],
          departure_time: nil
        },
        %MBTAV3API.Schedules.Schedule{
          trip: %MBTAV3API.Schedules.Trip{
            id: "FRMLThuFri-709631-494",
            name: "494"
          },
          stop: %MBTAV3API.Stops.Stop{
            id: "place-sstat",
            name: "South Station"
          },
          arrival_time: nil,
          departure_time: ~U[2024-11-15 20:25:00Z]
        },
        %MBTAV3API.Schedules.Schedule{
          trip: %MBTAV3API.Schedules.Trip{
            id: "FRMLThuFri-709631-494",
            name: "494"
          },
          stop: %Stop{id: "place-WML-0214", name: "Framingham"},
          arrival_time: ~U[2024-11-15 23:30:00Z],
          departure_time: nil
        }
      ]

      [trip1, trip2] = CreateAlertLive.filter_out_old_trips(schedules, current_time)
      assert trip1.departure_time == ~U[2024-11-15 14:30:00Z]
      assert trip2.departure_time == ~U[2024-11-15 20:25:00Z]
    end
  end
end
