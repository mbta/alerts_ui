defmodule AlertsUIWeb.FormComponents.AffectedServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  use AlertsUIWeb, :live_view

  import AlertsUI.Support.Factory
  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUI.Alerts
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.FormComponents.{AffectedService, RouteTypeAndEffect}
  alias AlertsUIWeb.Step
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop
  alias Phoenix.LiveView.AsyncResult

  @schedule %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: nil,
    departure_time:
      DateTime.utc_now() |> DateTime.shift_zone!("America/New_York") |> DateTime.add(-1, :hour)
  }

  @schedule_2 %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: DateTime.utc_now() |> DateTime.shift_zone!("America/New_York"),
    departure_time: nil
  }

  @schedule_3 %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-596", name: "596", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: DateTime.utc_now() |> DateTime.shift_zone!("America/New_York"),
    departure_time:
      DateTime.utc_now() |> DateTime.shift_zone!("America/New_York") |> DateTime.add(-1, :hour)
  }

  @schedule_4 %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-596", name: "596", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: DateTime.utc_now() |> DateTime.shift_zone!("America/New_York"),
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
  @stop_2 %Stop{id: "place-crtst", name: "Courthouse"}

  @facility %Facility{
    id: "349",
    type: "ESCALATOR",
    short_name: "Platform to Russell Field",
    long_name: "Alewife Escalator 349 (Platform to Russell Field)",
    stop: %Stop{
      id: "place-alfcl",
      name: "Aquarium",
      type: "stop"
    },
    latitude: 42.395428,
    longitude: -71.142483,
    properties: [
      %{name: "direction", value: "up"},
      %{name: "excludes-stop", value: 141},
      %{name: "excludes-stop", value: 9_070_061},
      %{name: "excludes-stop", value: "door-alfcl-alewife"},
      %{name: "excludes-stop", value: "door-alfcl-busway"},
      %{name: "excludes-stop", value: "door-alfcl-cambridgepark"},
      %{name: "excludes-stop", value: "door-alfcl-pathbusway"},
      %{name: "excludes-stop", value: "door-alfcl-steel"}
    ]
  }

  @assigns %{
    id: "affected_service",
    progress: %Step{
      name: "affected_service",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    route_type: 2,
    alert_data: %{route_ids: ["CR-Worcester"]},
    combination: :RDTS,
    form_type: :creating,
    effect_name: "Delay",
    show_stop_ids: false
  }

  @todays_date DateTime.utc_now()
               |> DateTime.shift_zone!("America/New_York")
               |> DateTime.to_date()

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
                 ~s(<option value="Stop 1|stop_1">Stop 1</option><option value="Stop 2|stop_2">Stop 2</option>)
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

    test "Filter title updates if 'all trips' selected" do
      today = @todays_date |> Date.to_string()
      tomorrow = Date.add(@todays_date, 1)

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> [@route] end,
           get: fn _id -> @route end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn
             # ISO date used when date is selected
             ["CR-Worcester"], [stop_sequences: [:first, :last], date: ^today] ->
               [@schedule, @schedule_2]

             # Date struct used in all trips- consider refactoring for consistency
             ["CR-Worcester"], [stop_sequences: [:first, :last], date: @todays_date] ->
               [@schedule, @schedule_2]

             ["CR-Worcester"], [stop_sequences: [:first, :last], date: ^tomorrow] ->
               [@schedule_3, @schedule_4]
           end,
           end_of_rating: fn -> Date.add(@todays_date, 1) end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end
         ]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(AffectedService, %{
            @assigns
            | alert_data: %{route_type: 2, effect_name: "Delay"}
          })

        view
        |> element("form")
        |> render_change(%{"affected_service" => %{"route_ids" => ["CR-Worcester"]}})

        assert view
               |> render() =~ "All Trips"

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{
            "modal_date" => nil,
            "route_ids" => ["CR-Worcester"]
          }
        })

        view
        |> with_target("#service_view")
        |> render_hook(:accepted_dates_modal, %{})

        assert view |> render() =~ "Filter: All future trips"
      end
    end

    test "Schedule updates if a different weekday is selected" do
      today = @todays_date |> Date.to_string()
      tomorrow = @todays_date |> Date.add(1) |> Date.to_string()

      with_mock(SchedulesRepo,
        by_route_ids: fn
          # ISO date used when date is selected
          ["CR-Worcester"], [stop_sequences: [:first, :last], date: ^today] ->
            [@schedule, @schedule_2]

          # Date struct used in all trips- consider refactoring for consistency
          ["CR-Worcester"], [stop_sequences: [:first, :last], date: @todays_date] ->
            [@schedule, @schedule_2]

          ["CR-Worcester"], [stop_sequences: [:first, :last], date: ^tomorrow] ->
            [@schedule_3, @schedule_4]
        end,
        end_of_rating: fn -> Date.add(@todays_date, 1) end
      ) do
        {:ok, view, _html} =
          live_isolated_component(AffectedService, %{
            @assigns
            | alert_data: %{route_type: 2, effect_name: "Delay"}
          })

        view
        |> element("form")
        |> render_change(%{"affected_service" => %{"route_ids" => ["CR-Worcester"]}})

        assert view
               |> render() =~ @schedule.trip.name

        refute view
               |> render() =~ @schedule_3.trip.name

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{
            "modal_date" => tomorrow,
            "route_ids" => ["CR-Worcester"]
          }
        })

        view
        |> with_target("#service_view")
        |> render_hook(:accepted_dates_modal, %{})

        assert view
               |> render() =~ @schedule_3.trip.name

        refute view
               |> render() =~ @schedule.trip.name
      end
    end

    test "Filter title updates if a different weekday is selected" do
      today = @todays_date |> Date.to_string()
      today_day_name = Calendar.strftime(@todays_date, "%a %b %0d")
      tomorrow = @todays_date |> Date.add(1) |> Date.to_string()
      tomorrow_day_name = Calendar.strftime(Date.add(@todays_date, 1), "%a %b %0d")

      with_mock(SchedulesRepo,
        by_route_ids: fn
          # ISO date used when date is selected
          ["CR-Worcester"], [stop_sequences: [:first, :last], date: ^today] ->
            [@schedule, @schedule_2]

          # Date struct used in all trips- consider refactoring for consistency
          ["CR-Worcester"], [stop_sequences: [:first, :last], date: @todays_date] ->
            [@schedule, @schedule_2]

          ["CR-Worcester"], [stop_sequences: [:first, :last], date: ^tomorrow] ->
            [@schedule_3, @schedule_4]
        end,
        end_of_rating: fn -> Date.add(@todays_date, 1) end
      ) do
        {:ok, view, _html} =
          live_isolated_component(AffectedService, %{
            @assigns
            | alert_data: %{route_type: 2, effect_name: "Delay"}
          })

        view
        |> element("form")
        |> render_change(%{"affected_service" => %{"route_ids" => ["CR-Worcester"]}})

        assert view
               |> render() =~ ~s(Filter: #{today_day_name})

        refute view
               |> render() =~ ~s(Filter: #{tomorrow_day_name})

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{
            "modal_date" => tomorrow,
            "route_ids" => ["CR-Worcester"]
          }
        })

        view
        |> with_target("#service_view")
        |> render_hook(:accepted_dates_modal, %{})

        refute view
               |> render() =~ ~s(Filter: #{today_day_name})

        assert view
               |> render() =~ ~s(Filter: #{tomorrow_day_name})

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{
            "modal_date" => today,
            "route_ids" => ["CR-Worcester"]
          }
        })

        view
        |> with_target("#service_view")
        |> render_hook(:accepted_dates_modal, %{})

        assert view
               |> render() =~ ~s(Filter: #{today_day_name})

        refute view
               |> render() =~ ~s(Filter: #{tomorrow_day_name})
      end
    end

    test "clear date filter for trips works" do
      today = Date.to_string(@todays_date)
      today_day_name = Timex.format!(@todays_date, "{WDshort} {Mshort} {0D}")
      tomorrow = @todays_date |> Date.add(1) |> Date.to_string()

      with_mocks([
        {SchedulesRepo, [],
         [
           by_route_ids: fn
             # ISO date used when date is selected
             ["CR-Worcester"], [stop_sequences: [:first, :last], date: ^today] ->
               [@schedule, @schedule_2]

             # Date struct used in all trips- consider refactoring for consistency
             ["CR-Worcester"], [stop_sequences: [:first, :last], date: @todays_date] ->
               [@schedule, @schedule_2]

             ["CR-Worcester"], [stop_sequences: [:first, :last], date: ^tomorrow] ->
               [@schedule_3, @schedule_4]
           end,
           end_of_rating: fn -> Date.add(@todays_date, 1) end
         ]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(AffectedService, %{
            @assigns
            | alert_data: %{route_type: 2, effect_name: "Delay"}
          })

        # Add route selection and date filter
        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{
            "modal_date" => tomorrow,
            "route_ids" => ["CR-Worcester"]
          }
        })

        # Submit filter
        view
        |> with_target("#service_view")
        |> render_hook(:accepted_dates_modal, %{})

        # Clear filter
        view
        |> with_target("#service_view")
        |> render_click(:clear_filter, %{"filter-id" => "dates-filter-modal"})

        # Verify unfiltered
        assert render(view) =~ @schedule.trip.name
        refute render(view) =~ @schedule_3.trip.name
        # Verify text changed
        assert render(view) =~ ~s(Filter: #{today_day_name})
        # Verify modal is cleared
        assert view
               |> element("select#affected_service_trip_ids")
               |> render() =~ ~s(<option value="default" selected="selected">)
      end
    end

    test "modal search works" do
      today = @todays_date |> Date.to_string()
      tomorrow_day_name = Date.add(@todays_date, 1) |> Timex.format!("{WDshort}")

      with_mock(SchedulesRepo,
        by_route_ids: fn
          ["CR-Worcester"], [stop_sequences: [:first, :last], date: ^today] ->
            [@schedule, @schedule_2]
        end,
        end_of_rating: fn -> Date.add(@todays_date, 1) end
      ) do
        {:ok, view, _html} =
          live_isolated_component(AffectedService, %{
            @assigns
            | alert_data: %{route_type: 2, effect_name: "Delay"}
          })

        view
        |> element("form")
        |> render_change(%{"affected_service" => %{"route_ids" => ["CR-Worcester"]}})

        assert view
               |> element("select#affected_service_modal_date")
               |> render() =~ "#{tomorrow_day_name}"

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{"modal_date_filter" => "q", "route_ids" => ["CR-Worcester"]}
        })

        refute view
               |> element("select#affected_service_modal_date")
               |> render() =~ "#{tomorrow_day_name}"
      end
    end

    test "date selection disabled until one or more routes selected" do
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

        assert view |> render_async() =~ ~s(id="dates-filter-modal_button" disabled="disabled")

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{
            "route_ids" => ["1", "2"],
            "directions" => [0]
          }
        })

        refute view |> render_async() =~ ~s(id="dates-filter-modal_button" disabled="disabled")
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
      with_mocks([
        {RoutesRepo, [], [by_type: fn _route_types -> [@route] end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            AffectedService,
            @assigns
            |> Map.merge(%{
              route_type: 3,
              effect_name: "Delay",
              combination: :RDS,
              alert_data: %{}
            })
          )

        assert view
               |> render() =~ ~s(id="affected_service_stop_names_and_ids" disabled="disabled")

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{
            "route_ids" => ["CR-Worcester"]
          }
        })

        refute view
               |> render() =~ ~s(id="affected_service_stop_names_and_ids" disabled="disabled")
      end
    end

    test "stop element not spuriously disabled if second is selected" do
      route_2 = %Route{
        direction_names: %{0 => "Westbound", 1 => "Eastbound"},
        sort_order: 3,
        id: "CR-Fairmount",
        type: 2,
        name: "Fairmount Line"
      }

      with_mocks([
        {RoutesRepo, [], [by_type: fn _route_types -> [@route, route_2] end]},
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(AffectedService, %{
            @assigns
            | alert_data: %{route_type: 4, effect_name: "Shuttle"}
          })

        assert render_async(view) =~
                 ~s(id="affected_service_stop_names_and_ids" disabled="disabled")

        refute render_async(view) =~ "All Stops"

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{
            "route_ids" => [@route.id]
          }
        })

        refute render_async(view) =~
                 ~s(id="affected_service_stop_names_and_ids" disabled="disabled")

        assert view |> render_async() =~ "All Stops"

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{
            "route_ids" => [route_2.id]
          }
        })

        refute render_async(view) =~
                 ~s(id="affected_service_stop_names_and_ids" disabled="disabled")
      end
    end

    test "bus stop names have direction appended and are ordered by first outbound to last inbound" do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _route_types -> [@route] end]},
        {StopsRepo, [],
         [
           by_route: fn
             _route, 0 -> [@stop, @stop_2]
             _route, 1 -> [@stop_2, @stop]
           end
         ]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            AffectedService,
            @assigns
            |> Map.merge(%{
              route_type: 3,
              effect_name: "Delay",
              combination: :RDS,
              alert_data: %{}
            })
          )

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{
            "route_ids" => ["CR-Worcester"]
          }
        })

        assert view
               |> element("select##affected_service_stop_names_and_ids")
               |> render =~
                 "<option value=\"South Station (outbound)|place-sstat\">South Station (outbound)</option><option value=\"Courthouse (outbound)|place-crtst\">Courthouse (outbound)</option><option value=\"Courthouse (inbound)|place-crtst\">Courthouse (inbound)</option><option value=\"South Station (inbound)|place-sstat\">South Station (inbound)</option>"
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

        assert view |> render_async() =~ ~s(<option value="South Station|place-sstat">)

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{"trip_search_term" => "x", "stop_search_term" => "x"}
        })

        refute view |> render_async() =~
                 ~s(<option value="CR-683322-595">595)

        refute view |> render_async() =~ ~s(<option value="South Station|place-sstat">)
      end
    end

    test "works correctly if editing" do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _route_types -> [@route] end]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end,
           end_of_rating: fn ->
             DateTime.utc_now()
             |> DateTime.shift_zone!("America/New_York")
             |> DateTime.to_date()
             |> Date.add(10)
           end
         ]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            AffectedService,
            @assigns
            |> Map.merge(%{
              form_type: :editing,
              alert_data: %{
                direction: "0",
                route_type: 2,
                stop_names_and_ids: ["South Station|place-sstat"],
                route_ids: ["CR-Worcester"],
                trip_ids: ["CR-683322-595"]
              }
            })
          )

        assert view |> render_async() =~ ~s(value=\"CR-Worcester\" checked=\"checked\")

        assert view |> render_async() =~
                 ~s(<option selected="selected" value="0">Westbound</option>)

        assert view |> render_async() =~
                 ~s(<option selected="selected" value="South Station|place-sstat">)

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

      get_to_submission_page(view, "Bus", "Delay")

      view
      |> element("#service_form")
      |> render_change(%{
        affected_service: %{route_ids: []}
      })

      open_review_modal(view)

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

        get_to_submission_page(view, "Commuter Rail", "Delay")

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
          affected_service: %{route_ids: []}
        })

        refute view |> render() =~ ~s(value="CR-Worcester" checked="checked")
      end
    end

    @tag :logged_in_user
    test "trip select makes 'All Trips' and individual trip selection mutually exclusive", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _stop_id, _ -> [@route] end,
           by_type: fn _types -> [@route] end,
           get: fn _, _ -> @route end,
           get: fn _ -> @route end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _route_ids, _opts ->
             [@schedule, @schedule_2, @schedule_3, @schedule_4]
           end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type -> [@stop] end,
           by_route: fn _, _ -> [@stop] end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Commuter Rail", "Delay")

        render_async(view)

        # Mock selecting Framingham line
        view
        |> element("#service_form")
        |> render_change(%{
          affected_service: %{route_ids: ["CR-Worcester"]}
        })

        # Mock user selecting 2 trips in addition to "All Trips"
        view
        |> element("#service_form")
        |> render_change(%{
          "affected_service" => %{"trip_ids" => ["default", "CR-683322-595", "CR-683322-596"]}
        })

        # At this time, we CAN'T test the JS hook unless we set up Playwright.
        # So, we can't check whether the selections look right to the user,
        # but we can verify that the data on the server is correct when the form
        # is submitted

        # Fill out other required fields
        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{header_text: "hello"}
        })

        open_review_modal(view)

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        # query the db
        flash = assert_redirect(view, "/")

        alert_id =
          flash["info"]
          |> String.replace("New alert #", "")
          |> String.replace(" created", "")

        new_alert = AlertsUI.Alerts.get_by_alert_id(alert_id)

        assert [%{trip: %{trip_id: "CR-683322-595"}}, %{trip: %{trip_id: "CR-683322-596"}}] =
                 Map.get(new_alert, :informed_entity) |> Enum.sort_by(& &1.trip.trip_id)
      end
    end

    @tag :logged_in_user
    test "end-to-end editing", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _stop_id, _ -> [@route] end,
           by_type: fn _types -> [@route] end,
           all: fn _opts -> [@route] end,
           get: fn _ -> @route end,
           get: fn _, _ -> @route end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _route_ids, _opts ->
             [@schedule, @schedule_2, @schedule_3, @schedule_4]
           end,
           all: fn _opts -> [@schedule, @schedule_2] end,
           end_of_rating: fn -> Date.add(@todays_date, 1) end,
           trip: fn "CR-683322-595" ->
             %Trip{id: "CR-683322-595", name: "595", direction_id: 0}
           end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type -> [@stop, @stop_2] end,
           by_route: fn _, _ -> [@stop, @stop_2] end,
           get_parent: fn
             "place-sstat" -> @stop
             "place-crtst" -> @stop_2
           end,
           get: fn
             "place-sstat" -> @stop
             "place-crtst" -> @stop_2
           end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [] end,
           included_stops_by_route_id: fn "CR-Worcester", [canonical: true] ->
             [@stop, @stop_2]
           end
         ]},
        {FacilitiesRepo, [],
         [
           get: fn _facility_id -> @facility end,
           get_by_type: fn _facility_types, _opts -> [@facility] end
         ]}
      ]) do
        conn = put_resp_cookie(conn, "show_created_alert", "true")
        trip = build(:trip_descriptor, %{trip_id: @schedule.trip.id})

        ie =
          build(:informed_entity, %{
            route_id: @route.id,
            route_type: @route.type,
            activities: [:BOARD],
            stop_id: @stop.id,
            trip: Map.from_struct(trip),
            direction_id: nil
          })

        alert_params =
          build(
            :alert_map,
            %{
              alert_id: "123",
              header_text: "example header text",
              informed_entity: [Map.from_struct(ie)],
              effect: :OTHER_EFFECT,
              effect_detail: "DELAY",
              original_route_selections: [@route.id],
              original_stop_selections: ["#{@stop.name}|#{@stop.id}"],
              reminder_times: [],
              severity: 7,
              cause_detail: "unknown",
              user: build(:user),
              primary_service_type: Integer.to_string(@route.type)
            }
          )

        {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

        {:ok, view, _html} = live(conn, "/alerts/edit?alert_id=123")

        rendered_view = render_async(view)

        assert rendered_view =~ ~s(value="CR-Worcester" checked="checked")

        assert rendered_view =~
                 ~s(<option selected="selected" value="South Station|place-sstat">South Station)

        assert rendered_view =~ ~s(<option selected="selected" value="CR-683322-595">595)

        view
        |> element("#service_form")
        |> render_change(%{
          "affected_service" => %{
            "stop_names_and_ids" => ["#{@stop_2.name}|#{@stop_2.id}"]
          }
        })

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        # wait a smidge for the alert to get persisted to the database
        :timer.sleep(50)
        alert = AlertsUI.Alerts.get_by_alert_id("123")

        assert [
                 %{
                   stop_id: "place-crtst",
                   route_id: "CR-Worcester",
                   trip: %{trip_id: "CR-683322-595"}
                 }
               ] = Map.get(alert, :informed_entity)
      end
    end

    @tag :logged_in_user
    test "user can select 'All future trips', a trip, and then effect start far from now", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _stop_id, _ -> [@route] end,
           by_type: fn _types -> [@route] end,
           get: fn _, _ -> @route end,
           get: fn _ -> @route end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _route_ids, _opts ->
             [@schedule, @schedule_2, @schedule_3, @schedule_4]
           end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type -> [@stop] end,
           by_route: fn _, _ -> [@stop] end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Commuter Rail", "Cancellation")

        render_async(view)

        # Mock selecting Framingham line
        view
        |> element("#service_form")
        |> render_change(%{
          affected_service: %{route_ids: ["CR-Worcester"]}
        })

        # Mock user selecting "All future trips"
        view
        |> element("#service_form")
        |> render_change(%{
          affected_service: %{modal_date: "default"}
        })

        # Mock user selecting 2 trips
        view
        |> element("#service_form")
        |> render_change(%{
          "affected_service" => %{"trip_ids" => ["CR-683322-595", "CR-683322-596"]}
        })

        # Selecting dates in distant future
        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_start_specifier" => "custom",
            "active_period_end_specifier" => "custom"
          }
        })

        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_start" => ~N[2045-03-28 03:00:00],
            "active_period_end" => ~N[2045-03-31 19:00:00]
          }
        })

        refute render(view) =~ ~s(Effect must start before)
      end
    end
  end
end
