defmodule AlertsUIWeb.FormComponents.AffectedServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.AffectedService
  alias AlertsUIWeb.Step
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.{Schedule, Trip}
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @schedule %Schedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: nil,
    departure_time: ~U[2024-02-21 14:15:00.00Z]
  }

  @assigns %{
    id: "affected_service",
    progress: %Step{
      name: "affected_service",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    route_type: 1,
    available_routes: [],
    available_schedules: [@schedule],
    available_stops: [%Stop{id: "place-sstat", name: "South Station"}],
    alert_data: %{},
    combination: :RDTS,
    editing: false
  }

  describe "component" do
    test "renders" do
      assert render_component(AffectedService, @assigns) =~ ~s(id="service_form")
    end

    test "direction options are only populated once a route is chosen" do
      with_mock(StopsRepo, by_route: fn _route, _direction -> [] end) do
        {:ok, view, _html} =
          live_isolated_component(
            AffectedService,
            @assigns
            |> Map.merge(%{
              alert_data: %{route_type: 3, effect_name: "Delay"},
              available_routes: [
                %Route{
                  id: "1",
                  direction_names: %{0 => "Westbound", 1 => "Eastbound"},
                  sort_order: 3
                }
              ]
            })
          )

        first_rendered_view =
          view
          |> element("select#affected_service_direction")
          |> render()

        refute first_rendered_view =~ "Eastbound"

        view
        |> element("form")
        |> render_change(%{"affected_service" => %{"route_ids" => ["1"]}})

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
      with_mock(SchedulesRepo, by_route_ids: fn _route_ids, _opts -> [] end) do
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
        |> render_change(%{"affected_service" => %{"route_ids" => ["1"]}})

        assert view
               |> element("select#affected_service_trip_ids")
               |> render() =~ "All Trips"
      end
    end

    test "stop element disabled until route is selected" do
      with_mock(StopsRepo, by_route: fn _route, _direction -> [] end) do
        {:ok, view, _html} =
          live_isolated_component(AffectedService, %{
            @assigns
            | alert_data: %{route_type: 4, effect_name: "Shuttle"}
          })

        refute render(view) =~ "All Stops"

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{
            "route_ids" => ["1"],
            "directions" => [0]
          }
        })

        assert view
               |> render() =~ "All Stops"
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
               |> render() =~ ~s(disabled="disabled")
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

    test "works correctly if editing" do
      {:ok, view, _html} =
        live_isolated_component(
          AffectedService,
          @assigns
          |> Map.merge(%{
            editing: true,
            available_stops: [%Stop{id: "place-sstat"}],
            available_routes: [%Route{id: "CR-Worcester", type: 2}],
            available_trips: [%{id: "CR-628038-501-1"}],
            available_schedules: [
              %MBTAV3API.Schedules.Schedule{
                route: %MBTAV3API.Routes.Route{
                  id: "CR-Fitchburg",
                  type: 2
                },
                trip: %MBTAV3API.Schedules.Trip{
                  id: "CR-627999-541-1"
                },
                stop: %MBTAV3API.Stops.Stop{
                  id: "place-sstat"
                },
                platform_stop_id: "NEC-2287"
              }
            ],
            alert_data: %{
              direction: "0",
              route_type: 2,
              stop_ids: ["place-sstat"],
              combination: :RDTS,
              route_ids: ["CR-Worcester"],
              trip_ids: ["CR-628038-501-1"],
              trip_information_by_id: %{
                "CR-628038-501-1" => %{route_id: "CR-Worcester", direction_id: 0}
              }
            }
          })
        )

      assert view |> render() =~ ~s(value=\"CR-Worcester\" checked=\"checked\")
      assert view |> render() =~ ~s(<option selected="selected" value="0">Outbound</option>)
      assert view |> render() =~ ~s(<option selected="selected" value="place-sstat">)
      assert view |> render() =~ ~s(<option value="CR-627999-541-1">)
    end
  end
end
