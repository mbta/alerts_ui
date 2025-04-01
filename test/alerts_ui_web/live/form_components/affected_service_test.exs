defmodule AlertsUIWeb.FormComponents.AffectedServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  use AlertsUIWeb, :live_view

  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.{AffectedService, RouteTypeAndEffect}
  alias AlertsUIWeb.Step
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.{Schedule, Trip}
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop
  alias Phoenix.LiveView.AsyncResult

  @schedule %Schedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: nil,
    departure_time: DateTime.utc_now() |> DateTime.add(-1, :hour)
  }

  @schedule_2 %Schedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: DateTime.utc_now(),
    departure_time: nil
  }

  @route %Route{
    direction_names: %{0 => "Westbound", 1 => "Eastbound"},
    sort_order: 3,
    id: "CR-Worcester",
    type: 2,
    name: "Framingham/Worcester Line"
  }

  @stop %Stop{id: "place-sstat", name: "South Station"}

  @assigns %{
    id: "affected_service",
    progress: %Step{
      name: "affected_service",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    route_type: 1,
    alert_data: %{route_ids: ["CR-Worcester"]},
    combination: :RDTS,
    editing: false,
    effect_name: "Delay"
  }

  describe "component" do
    test "renders" do
      assert render_component(AffectedService, @assigns) =~ ~s(id="service_form")
    end

    test "correct renders when green line chosen" do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _route_types ->
             [
               %Route{
                 direction_names: %{0 => "Westbound", 1 => "Eastbound"},
                 sort_order: 3,
                 id: "Green-B",
                 type: 1,
                 name: "Green Line"
               }
             ]
           end,
           green_line: fn ->
             %Route{
               id: "Green",
               name: "Green Line",
               direction_names: %{0 => "Westbound", 1 => "Eastbound"},
               type: 0,
               sort_order: 10_030
             }
           end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction ->
             [%Stop{id: "stop_1", name: "Stop 1"}, %Stop{id: "stop_2", name: "Stop 2"}]
           end
         ]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            AffectedService,
            @assigns
            |> Map.merge(%{route_type: 1, combination: :RDS})
          )

        view
        |> element("form")
        |> render_change(%{"affected_service" => %{"route_ids" => ["Green"]}})

        assert view |> render_async() =~
                 ~s(<option value=\"stop_1\">Stop 1</option><option value=\"stop_2\">Stop 2</option>)
      end
    end

    test "direction options are only populated once a route is chosen" do
      with_mock(StopsRepo, by_route: fn _route, _direction -> [] end) do
        {:ok, view, _html} =
          live_isolated_component(
            AffectedService,
            @assigns
            |> Map.merge(%{
              alert_data: %{route_type: 3, effect_name: "Delay"}
            })
          )

        first_rendered_view =
          view
          |> live_assign(:available_routes, %AsyncResult{
            ok?: true,
            loading: false,
            failed: false,
            result: [@route]
          })
          |> element("select#affected_service_direction")
          |> render()

        refute first_rendered_view =~ "Eastbound"

        view
        |> element("form")
        |> render_change(%{"affected_service" => %{"route_ids" => ["CR-Worcester"]}})

        second_rendered_view =
          view
          |> element("select#affected_service_direction")
          |> render()

        assert second_rendered_view =~ "Eastbound"
      end
    end

    test "trip select is only shown for commuter rail and ferry" do
      {:ok, cr_view, _html} =
        live_isolated_component(AffectedService, %{
          @assigns
          | alert_data: %{route_type: 2, effect_name: "Delay"}
        })

      assert cr_view
             |> element("select#affected_service_trip_ids")
             |> has_element?()

      {:ok, ferry_view, _html} =
        live_isolated_component(AffectedService, %{
          @assigns
          | alert_data: %{route_type: 4, effect_name: "Delay"}
        })

      assert ferry_view
             |> element("select#affected_service_trip_ids")
             |> has_element?()

      {:ok, subway_view, _html} =
        live_isolated_component(
          AffectedService,
          @assigns |> Map.merge(%{alert_data: %{route_type: 1}, combination: :RDS})
        )

      refute subway_view
             |> element("select#affected_service_trip_ids")
             |> has_element?()

      {:ok, bus_view, _html} =
        live_isolated_component(
          AffectedService,
          @assigns |> Map.merge(%{alert_data: %{route_type: 3}, combination: :RDS})
        )

      refute bus_view
             |> element("select#affected_service_trip_ids")
             |> has_element?()
    end

    test "trip options are only populated once a route is chosen" do
      with_mock(SchedulesRepo, by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end) do
        {:ok, view, _html} =
          live_isolated_component(AffectedService, %{
            @assigns
            | alert_data: %{route_type: 2, effect_name: "Delay"}
          })

        refute view
               |> element("select#affected_service_trip_ids")
               |> render() =~ "All Trips"

        view
        |> element("form")
        |> render_change(%{"affected_service" => %{"route_ids" => ["CR-Worcester"]}})

        assert view
               |> live_assign(:available_schedules, %AsyncResult{
                 ok?: true,
                 loading: false,
                 failed: false,
                 result: [@schedule]
               })
               |> render() =~ "All Trips"
      end
    end

    test "stop element disabled until route is selected" do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _route_types -> [@route] end]},
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(AffectedService, %{
            @assigns
            | alert_data: %{route_type: 4, effect_name: "Shuttle"}
          })

        refute render_async(view) =~ "All Stops"

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{
            "route_ids" => ["1"],
            "directions" => [0]
          }
        })

        assert view |> render_async() =~ "All Stops"
      end
    end

    test "enables stop selection if one route selected" do
      stops = [%Stop{id: "1", name: "cool stop name"}]

      with_mock(StopsRepo, by_route: fn _route, _direction -> stops end) do
        {:ok, view, _html} =
          live_isolated_component(AffectedService, %{
            @assigns
            | alert_data: %{route_type: 4, effect_name: "Shuttle"}
          })

        assert view
               |> render() =~ ~s(disabled="disabled")

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{
            "route_ids" => ["1"],
            "directions" => [0]
          }
        })

        refute view
               |> render() =~ ~s(multiple=\"multiple\" disabled=\"disabled\")
      end
    end

    test "disables stop selection if multiple routes selected" do
      stops = [%Stop{id: "1", name: "cool stop name"}]

      with_mock(StopsRepo, by_route: fn _route, _direction -> stops end) do
        {:ok, view, _html} =
          live_isolated_component(AffectedService, %{
            @assigns
            | alert_data: %{route_type: 4, effect_name: "Shuttle"}
          })

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{
            "route_ids" => ["1", "2"],
            "directions" => [0]
          }
        })

        assert view
               |> render() =~ ~s(disabled="disabled")
      end
    end

    test "search works" do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _route_types -> [@route] end]},
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(AffectedService, @assigns)

        view
        |> element("form")
        |> render_change(%{"affected_service" => %{"route_ids" => ["CR-Worcester"]}})

        assert view |> render_async() =~
                 ~s(<option value="CR-683322-595">595)

        assert view |> render_async() =~ ~s(<option value="place-sstat">)

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{"trip_ids_filter" => "x", "stop_ids_filter" => "x"}
        })

        refute view |> render_async() =~
                 ~s(<option value="CR-683322-595">595)

        refute view |> render_async() =~ ~s(<option value="place-sstat">)
      end
    end

    test "works correctly if editing" do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _route_types -> [@route] end]},
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            AffectedService,
            @assigns
            |> Map.merge(%{
              editing: true,
              alert_data: %{
                direction: "0",
                route_type: 2,
                stop_ids: ["place-sstat"],
                route_ids: ["CR-Worcester"],
                trip_ids: ["CR-683322-595"]
              }
            })
          )

        assert view |> render_async() =~ ~s(value=\"CR-Worcester\" checked=\"checked\")

        assert view |> render_async() =~
                 ~s(<option selected="selected" value="0">Westbound</option>)

        assert view |> render_async() =~ ~s(<option selected="selected" value="place-sstat">)

        assert view |> render_async() =~
                 ~s(<option selected="selected" value="CR-683322-595">595)
      end
    end

    @tag :logged_in_user
    test "shows missing field error upon submission", %{conn: conn} do
      with_mocks([
        {RoutePatternsRepo, [], [included_stops_by_route_id: fn _route_id, _direction -> [] end]},
        {RoutesRepo, [], [by_type: fn _route_types -> [@route] end]},
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        send(
          view.pid,
          {:step_completed, %RouteTypeAndEffect{route_type: 3, effect_name: "Detour"}}
        )

        refute view
               |> render_async() =~
                 ~s(text-text-error)

        send_update(view.pid, AffectedService, id: "affected_service", submitted: true)

        assert view
               |> render_async() =~
                 ~s(text-text-error)
      end
    end
  end

  describe "end-to-end" do
    @tag :logged_in_user
    test "publishing a bus delay AFTER selecting and deselecting will put up a flash error for the missing route",
         %{
           conn: conn
         } do
      {:ok, view, _html} = live(conn, "/alerts/new")

      view
      |> element("#route_types_form button", "Bus")
      |> render_click()

      view
      |> element("#route_types_form button", "Delay")
      |> render_click()

      view
      |> element("#route_types_form")
      |> render_submit()

      view
      |> element("#service_form")
      |> render_change(%{
        affected_service: %{route_ids: []}
      })

      view
      |> element("button#save", "Publish")
      |> render_click()

      # Inline
      assert has_element?(view, "p.text-text-error", "Select route(s)")

      # Flash
      assert view
             |> element("#error-flash li", "Select route(s)")
             |> render() =~ "Select route(s)"
    end

    @tag :logged_in_user
    test "allows a CR Line to be selected then deselected without erroring", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [@route] end]},
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view
        |> element("#route_types_form button", "Commuter Rail")
        |> render_click()

        view
        |> element("#route_types_form button", "Delay")
        |> render_click()

        view
        |> element("#route_types_form")
        |> render_submit()

        render_async(view)

        # Mock selecting Framingham line
        view
        |> element("#service_form")
        |> render_change(%{
          affected_service: %{route_ids: ["CR-Worcester"]}
        })

        assert view |> render() =~ ~s(value="CR-Worcester" checked="checked")

        # Mock deselecting Framingham
        view
        |> element("#service_form")
        |> render_change(%{
          affected_service: %{route_ids: ["CR-Worcester"]}
        })

        refute view |> render() =~ ~s(value="CR-Worcester" checked="checked")
      end
    end
  end
end
