defmodule AlertsUI.AlertBuilderTest do
  @moduledoc false
  use AlertsUI.DataCase
  import AlertsUI.Support.Factory
  import Mock
  alias AlertsUI.AlertBuilder
  alias AlertsUI.Alerts
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Lines.Line
  alias MBTAV3API.Lines.Repo, as: LinesRepo
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.RoutePatterns.RoutePattern, as: APIRoutePattern
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @green_line_virtual_route %Route{
    id: "Green",
    name: "Green Line",
    long_name: "Green Line",
    direction_names: %{0 => "Westbound", 1 => "Eastbound"},
    type: 0,
    description: :rapid_transit
  }

  describe "build_alert/1" do
    test "builds alert from map" do
      with_mocks([
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]},
        {RoutesRepo, [],
         [get: fn route_id, _opts -> %Route{id: route_id, type: 1, name: route_id} end]}
      ]) do
        existing_alert = insert(:alert, alert_id: "0")

        alert_data = %{
          route_type: 1,
          description_text: "ok",
          header_text: "hello",
          banner_text: "important banner text",
          effect_name: "Delay",
          route_ids: ["57"],
          direction: "default",
          active_period_start: ~N[2024-04-30 11:54:00],
          alert_timing: :"one-time",
          active_period_end_specifier: :until_further_notice,
          active_period_start_specifier: :custom,
          cause_detail: "DISABLED_TRAIN",
          url: "http://www.example.com",
          image_url: "http://www.example.com/example.jpg",
          image_alternative_text: "an example image",
          last_push_notification_timestamp: ~N[2024-04-30 11:54:00],
          notification_period_start: ~N[2024-04-30 05:52:00],
          notification_specifier: :now,
          severity: 3,
          reminder_times: [
            ~N[2024-04-30 12:04:00],
            ~N[2024-04-30 12:14:00],
            ~N[2024-04-30 12:24:00]
          ]
        }

        result = AlertBuilder.build_alert(alert_data, :R, ~U[2024-04-30 05:54:00Z])

        assert result == %{
                 effect: :SIGNIFICANT_DELAYS,
                 effect_name: "Delay",
                 description_text: "ok",
                 header_text: "hello",
                 informed_entity: [
                   %{
                     route_type: 1,
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "57",
                     agency_id: "1"
                   }
                 ],
                 effect_detail: "DELAY",
                 active_period: [%{start: ~U[2024-04-30 15:54:00Z], end: nil}],
                 duration_certainty: :UNKNOWN,
                 active_period_start: ~U[2024-04-30 15:54:00Z],
                 active_period_end: nil,
                 cause: :TECHNICAL_PROBLEM,
                 cause_detail: "DISABLED_TRAIN",
                 url: "http://www.example.com",
                 image_url: "http://www.example.com/example.jpg",
                 image_alternative_text: "an example image",
                 banner_text: "important banner text",
                 last_push_notification_timestamp: ~U[2024-04-30 15:54:00Z],
                 notification_period_start: ~U[2024-04-30 05:54:00Z],
                 notification_period_end: nil,
                 severity: 3,
                 severity_level: :WARNING,
                 reminder_times: [
                   %{reminder_time: ~U[2024-04-30 16:04:00Z]},
                   %{reminder_time: ~U[2024-04-30 16:14:00Z]},
                   %{reminder_time: ~U[2024-04-30 16:24:00Z]}
                 ],
                 current_time: ~U[2024-04-30 05:54:00Z],
                 recurrence_days: nil,
                 original_route_selections: ["57|57"],
                 original_stop_selections: [],
                 primary_service_type: "1"
               }

        Alerts.create_or_update_alert(result, build(:user))

        [alert_1, alert_2] = Alerts.list_all() |> Enum.sort_by(& &1.alert_id)
        assert alert_1.alert_id == existing_alert.alert_id
        assert alert_2.alert_id |> String.to_integer() > alert_1.alert_id |> String.to_integer()
      end
    end

    test "notification period end is same as alert end if specifier is custom" do
      with_mocks([
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 1} end]}
      ]) do
        alert_data = %{
          route_type: 1,
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["57"],
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end: ~N[2024-05-01 11:54:00],
          alert_timing: :"one-time",
          active_period_end_specifier: :custom,
          active_period_start_specifier: :custom,
          cause_detail: "DISABLED_TRAIN",
          notification_period_start: ~N[2024-04-30 05:52:00],
          notification_specifier: :now,
          severity: 3
        }

        result = AlertBuilder.build_alert(alert_data, :R, ~U[2024-04-30 05:54:00Z])
        assert result.notification_period_end == ~U[2024-05-01 15:54:00Z]
      end
    end

    test "notification period end is end of service today if end specifier is later today" do
      with_mocks([
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 1} end]}
      ]) do
        alert_data = %{
          route_type: 1,
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["57"],
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end: ~N[2024-04-30 13:54:00],
          alert_timing: :"one-time",
          active_period_end_specifier: :later_today,
          active_period_start_specifier: :custom,
          cause_detail: "DISABLED_TRAIN",
          notification_period_start: ~N[2024-04-30 05:52:00],
          notification_specifier: :now,
          severity: 3
        }

        result = AlertBuilder.build_alert(alert_data, :R, ~U[2024-04-30 11:54:00Z])
        assert result.notification_period_end == ~U[2024-05-01 07:00:00Z]
      end
    end

    test "it correctly adds combo ids" do
      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [] end
         ]},
        {RoutesRepo, [],
         [
           get: fn
             "24", _opts ->
               %Route{
                 id: "24",
                 line_id: "line-24",
                 type: 1,
                 description: :rapid_transit,
                 name: "24"
               }

             "27", _opts ->
               %Route{
                 id: "27",
                 line_id: "line-27",
                 type: 1,
                 description: :rapid_transit,
                 name: "27"
               }

             "57", _opts ->
               %Route{id: "57", line_id: "", type: 1, description: :rapid_transit, name: "57"}

             "2427", _opts ->
               %Route{
                 id: "2427",
                 line_id: nil,
                 type: 0,
                 description: :rapid_transit,
                 name: "2427"
               }

             "Shuttle_JFKPark", _opts ->
               %Route{
                 id: "Shuttle_JFKPark",
                 line_id: nil,
                 type: 3,
                 description: :rail_replacement_bus,
                 name: "cool shuttle"
               }
           end
         ]},
        {LinesRepo, [],
         [
           get: fn
             "line-24", _opts ->
               %Line{
                 id: "line-24",
                 route_ids: ["24", "2427"],
                 routes: [
                   %Route{id: "24", line_id: "line-24", type: 1, description: :rapid_transit},
                   %Route{id: "2427", type: 1, description: :rapid_transit}
                 ]
               }

             "line-27", _opts ->
               %Line{
                 id: "line-27",
                 route_ids: ["27", "2427", "Shuttle_JFKPark"],
                 routes: [
                   %Route{id: "27", line_id: "line-27", type: 1, description: :rapid_transit},
                   %Route{id: "2427", type: 1, description: :rapid_transit},
                   %Route{
                     id: "Shuttle_JFKPark",
                     line_id: nil,
                     type: 3,
                     description: :rail_replacement_bus
                   }
                 ]
               }
           end
         ]}
      ]) do
        existing_alert = insert(:alert, alert_id: "0")

        alert_data = %{
          route_type: 1,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["24", "27", "57"],
          direction: "default",
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end_specifier: :until_further_notice,
          active_period_start_specifier: :custom,
          cause_detail: ""
        }

        result = AlertBuilder.build_alert(alert_data, :R, ~U[2024-04-30 05:54:00Z])

        assert result == %{
                 effect: :SIGNIFICANT_DELAYS,
                 description_text: "ok",
                 header_text: "hello",
                 url: nil,
                 image_url: nil,
                 image_alternative_text: nil,
                 banner_text: nil,
                 informed_entity: [
                   %{
                     agency_id: "1",
                     route_id: "24",
                     route_type: 1,
                     activities: [:BOARD, :EXIT, :RIDE]
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "2427",
                     route_type: 1,
                     agency_id: "1"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "27",
                     route_type: 1,
                     agency_id: "1"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "57",
                     route_type: 1,
                     agency_id: "1"
                   }
                 ],
                 effect_detail: "DELAY",
                 effect_name: "Delay",
                 active_period: [%{start: ~U[2024-04-30 15:54:00Z], end: nil}],
                 active_period_end: nil,
                 active_period_start: ~U[2024-04-30 15:54:00Z],
                 duration_certainty: :UNKNOWN,
                 cause_detail: "",
                 cause: :UNKNOWN_CAUSE,
                 last_push_notification_timestamp: nil,
                 notification_period_start: nil,
                 notification_period_end: nil,
                 severity: nil,
                 severity_level: nil,
                 reminder_times: [],
                 current_time: ~U[2024-04-30 05:54:00Z],
                 recurrence_days: nil,
                 original_route_selections: ["24|24", "27|27", "57|57"],
                 original_stop_selections: [],
                 primary_service_type: "1"
               }

        result
        |> Alerts.create_or_update_alert(build(:user))

        [alert_1, alert_2] = Alerts.list_all() |> Enum.sort_by(& &1.alert_id, :desc)
        assert alert_2.alert_id == existing_alert.alert_id
        assert alert_1.alert_id |> String.to_integer() > alert_2.alert_id |> String.to_integer()
      end
    end

    test "it does not add combo IDs for the green line" do
      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [] end
         ]},
        {RoutesRepo, [],
         [
           get: fn
             "Green-D", _opts ->
               %Route{id: "Green-D", line_id: "line-Green", type: 1, description: :rapid_transit}
           end
         ]},
        {LinesRepo, [],
         [
           get: fn
             "line-Green", _opts ->
               %Line{
                 id: "line-Green",
                 route_ids: ["Green-B", "Green-C", "Green-D"],
                 routes: [
                   %Route{
                     id: "Green-B",
                     line_id: "line-Green",
                     type: 1,
                     description: :rapid_transit
                   },
                   %Route{
                     id: "Green-C",
                     line_id: "line-Green",
                     type: 1,
                     description: :rapid_transit
                   },
                   %Route{
                     id: "Green-D",
                     line_id: "line-Green",
                     type: 1,
                     description: :rapid_transit
                   }
                 ]
               }
           end
         ]}
      ]) do
        alert_data = %{
          route_type: 1,
          header_text: "header",
          effect_name: "Delay",
          route_ids: ["Green-D"],
          direction: "default",
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end_specifier: :until_further_notice,
          active_period_start_specifier: :custom,
          cause_detail: ""
        }

        result = AlertBuilder.build_alert(alert_data, :R, ~U[2024-04-30 05:54:00Z])

        assert result.informed_entity == [
                 %{
                   agency_id: "1",
                   route_id: "Green-D",
                   route_type: 1,
                   activities: [:BOARD, :EXIT, :RIDE]
                 }
               ]
      end
    end

    test "it does not filter out shuttle routes if they were part of the original selection" do
      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [] end
         ]},
        {RoutesRepo, [],
         [
           get: fn
             "24", _opts ->
               %Route{id: "24", line_id: "line-24", type: 1, description: :rapid_transit}

             "Shuttle_JFKPark", _opts ->
               %Route{
                 id: "Shuttle_JFKPark",
                 line_id: nil,
                 type: 3,
                 description: :rail_replacement_bus
               }
           end
         ]},
        {LinesRepo, [],
         [
           get: fn
             "line-24", _opts ->
               %Line{
                 id: "line-24",
                 route_ids: [],
                 routes: []
               }
           end
         ]}
      ]) do
        existing_alert = insert(:alert, alert_id: "0")

        alert_data = %{
          route_type: 1,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["24", "Shuttle_JFKPark"],
          direction: "default",
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end_specifier: :until_further_notice,
          active_period_start_specifier: :custom,
          cause_detail: ""
        }

        result = AlertBuilder.build_alert(alert_data, :R, ~U[2024-04-30 05:54:00Z])

        assert result.informed_entity == [
                 %{
                   agency_id: "1",
                   route_id: "24",
                   route_type: 1,
                   activities: [:BOARD, :EXIT, :RIDE]
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Shuttle_JFKPark",
                   route_type: 1,
                   agency_id: "1"
                 }
               ]

        result
        |> Alerts.create_or_update_alert(build(:user))

        [alert_1, alert_2] = Alerts.list_all() |> Enum.sort_by(& &1.alert_id, :desc)
        assert alert_2.alert_id == existing_alert.alert_id
        assert alert_1.alert_id |> String.to_integer() > alert_2.alert_id |> String.to_integer()
      end
    end

    test "uses the correct agency ID for the CapeFLYER" do
      with_mocks([
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]},
        {RoutesRepo, [],
         [get: fn route_id, _opts -> %Route{id: route_id, type: 2, name: "CapeFLYER"} end]}
      ]) do
        existing_alert = insert(:alert, alert_id: "0")

        alert_data = %{
          route_type: 2,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["CapeFlyer"],
          direction: "default",
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end_specifier: :until_further_notice,
          active_period_start_specifier: :custom,
          cause_detail: "FREIGHT_TRAIN_INTERFERENCE",
          notification_period_start: ~N[2024-04-30 11:54:00]
        }

        result = AlertBuilder.build_alert(alert_data, :R, ~U[2024-04-30 05:54:00Z])

        assert result == %{
                 effect: :SIGNIFICANT_DELAYS,
                 effect_name: "Delay",
                 description_text: "ok",
                 header_text: "hello",
                 informed_entity: [
                   %{
                     route_type: 2,
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "CapeFlyer",
                     agency_id: "3"
                   }
                 ],
                 effect_detail: "DELAY",
                 active_period: [%{start: ~U[2024-04-30 15:54:00Z], end: nil}],
                 active_period_end: nil,
                 active_period_start: ~U[2024-04-30 15:54:00Z],
                 duration_certainty: :UNKNOWN,
                 cause: :OTHER_CAUSE,
                 cause_detail: "FREIGHT_TRAIN_INTERFERENCE",
                 url: nil,
                 image_url: nil,
                 image_alternative_text: nil,
                 banner_text: nil,
                 last_push_notification_timestamp: nil,
                 notification_period_start: ~U[2024-04-30 15:54:00Z],
                 notification_period_end: nil,
                 severity: nil,
                 severity_level: nil,
                 reminder_times: [],
                 current_time: ~U[2024-04-30 05:54:00Z],
                 recurrence_days: nil,
                 original_route_selections: ["CapeFLYER|CapeFlyer"],
                 original_stop_selections: [],
                 primary_service_type: "2"
               }

        result
        |> Alerts.create_or_update_alert(build(:user))

        [alert_1, alert_2] = Alerts.list_all() |> Enum.sort_by(& &1.alert_id, :desc)
        assert alert_1.alert_id |> String.to_integer() > alert_2.alert_id |> String.to_integer()
        assert alert_2.alert_id == existing_alert.alert_id
      end
    end

    test "bus alerts will retain parents stops if they're on the representative trip" do
      stops = [
        %Stop{id: 64, parent_id: "place-nubn"},
        %Stop{id: 1, parent_id: nil},
        %Stop{id: 2, parent_id: nil}
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn route_id, [direction_id: "0", include: "representative_trip.stops"] ->
             [%APIRoutePattern{direction_id: 0, stops: stops, route_id: route_id}]
           end
         ]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 3} end]}
      ]) do
        alert_data = %{
          route_type: 3,
          header_text: "x",
          effect_name: "Delay",
          stop_ids: ["place-nubn", 1, 2],
          route_ids: ["87"],
          trip_ids: nil,
          direction: "0"
        }

        result = AlertBuilder.build_alert(alert_data, :RDS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "87",
                   route_type: 3,
                   agency_id: "1",
                   direction_id: 0,
                   stop_id: 64
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "87",
                   route_type: 3,
                   agency_id: "1",
                   direction_id: 0,
                   stop_id: 1
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "87",
                   route_type: 3,
                   agency_id: "1",
                   direction_id: 0,
                   stop_id: 2
                 }
               ]
      end
    end

    test "properly builds RDS all-stops informed entity with 1 route" do
      with_mocks([
        {RoutePatternsRepo, [], by_route_id: fn _route_id, _opts -> [] end},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 3} end]}
      ]) do
        alert_data = %{
          route_type: 3,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          stop_ids: [],
          route_ids: ["57"],
          trip_ids: nil,
          direction: "default"
        }

        result = AlertBuilder.build_alert(alert_data, :RDS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1"
                 }
               ]
      end
    end

    test "properly builds RDS all-stops informed entity with multiple routes" do
      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [] end
         ]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 3} end]}
      ]) do
        alert_data = %{
          route_type: 3,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          stop_ids: [],
          route_ids: ["57", "58"],
          trip_ids: nil,
          direction: "default"
        }

        result = AlertBuilder.build_alert(alert_data, :RDS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "58",
                   route_type: 3,
                   agency_id: "1"
                 }
               ]
      end
    end

    test "properly builds RDS all-stops informed entity with one route and direction" do
      with_mocks([
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 3} end]}
      ]) do
        alert_data = %{
          route_type: 3,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          stop_ids: [],
          route_ids: ["57"],
          trip_ids: nil,
          direction: "1"
        }

        result = AlertBuilder.build_alert(alert_data, :RDS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   direction_id: 1,
                   agency_id: "1"
                 }
               ]
      end
    end

    test "properly builds RDS informed entity with one route, multiple stops and direction" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Shuttle",
        stop_ids: ["a", "b", "c"],
        route_ids: ["57"],
        trip_ids: nil,
        direction: "1"
      }

      parent_stops = [%Stop{id: "a"}, %Stop{id: "b"}, %Stop{id: "c"}]

      child_stops = [
        %Stop{id: "1", parent_id: "a"},
        %Stop{id: "2", parent_id: "b"},
        %Stop{id: "3", parent_id: "c"}
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn route_id, _opts ->
             [
               %APIRoutePattern{
                 direction_id: 1,
                 stops: child_stops,
                 route_id: route_id,
                 id: "rp_1"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 3} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   direction_id: 1,
                   stop_id: "1"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   direction_id: 1,
                   stop_id: "2"
                 },
                 %{
                   activities: [:EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   direction_id: 1,
                   stop_id: "3"
                 }
               ]
      end
    end

    test "RDS Bus detour with multiple stops" do
      alert_data = %{
        direction: "0",
        stop_ids: ["1", "2"],
        route_type: 3,
        route_ids: ["1"],
        effect_name: "Detour",
        trip_ids: [],
        trip_information_by_id: %{},
        description_text: "test",
        header_text: "test"
      }

      parent_stops = [%Stop{id: "1"}, %Stop{id: "2"}, %Stop{id: "3"}]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn route_id, _opts ->
             [
               %APIRoutePattern{
                 direction_id: 0,
                 stops: parent_stops,
                 route_id: route_id,
                 id: "rp_1"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> parent_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops end]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 3} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDS)

        assert result.informed_entity == [
                 %{
                   direction_id: 0,
                   route_id: "1",
                   route_type: 3,
                   agency_id: "1",
                   activities: [:BOARD, :EXIT],
                   stop_id: "1"
                 },
                 %{
                   direction_id: 0,
                   route_id: "1",
                   route_type: 3,
                   agency_id: "1",
                   activities: [:BOARD, :EXIT],
                   stop_id: "2"
                 }
               ]
      end
    end

    test "RDS CR track change all trips" do
      alert_data = %{
        route_type: 2,
        effect_name: "Track Change",
        route_ids: ["CR-Haverhill"],
        direction: "0",
        trip_ids: [],
        trip_information_by_id: %{},
        stop_ids: ["place-WR-0067", "place-WR-0075"],
        header_text: "CR track change all trips",
        description_text: "CR track change all trips"
      }

      parent_stops = [%Stop{id: "place-WR-0067"}, %Stop{id: "place-WR-0075"}]

      child_stops = [
        %Stop{
          id: "WR-0067-01",
          parent_id: "place-WR-0067"
        },
        %Stop{
          id: "WR-0075-01",
          parent_id: "place-WR-0075"
        },
        # Intentional duplicate
        %Stop{
          id: "WR-0075-01",
          parent_id: "place-WR-0075"
        }
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn route_id, _opts ->
             [
               %APIRoutePattern{
                 direction_id: 0,
                 stops: child_stops,
                 route_id: route_id,
                 id: "rp_1"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 2} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDTS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD],
                   agency_id: "1",
                   direction_id: 0,
                   route_id: "CR-Haverhill",
                   route_type: 2,
                   stop_id: "WR-0067-01"
                 },
                 %{
                   activities: [:BOARD],
                   agency_id: "1",
                   direction_id: 0,
                   route_id: "CR-Haverhill",
                   route_type: 2,
                   stop_id: "WR-0075-01"
                 }
               ]
      end
    end

    test "RDS Subway shuttle at start of line" do
      alert_data = %{
        route_type: 1,
        effect_name: "Shuttle",
        route_ids: ["Red"],
        direction: "default",
        stop_ids: ["place-alfcl", "place-davis", "place-portr"],
        trip_ids: [],
        trip_information_by_id: %{},
        header_text: "Test 6",
        description_text: "Test 6"
      }

      parent_stops = [
        %Stop{id: "place-alfcl"},
        %Stop{id: "place-davis"},
        %Stop{id: "place-portr"},
        %Stop{id: "place-harsq"}
      ]

      child_stops_0 = [
        %Stop{id: "alfcl-child", parent_id: "place-alfcl"},
        %Stop{id: "davis-child-0", parent_id: "place-davis"},
        %Stop{id: "portr-child-0", parent_id: "place-portr"},
        %Stop{id: "harsq-child-0", parent_id: "place-harsq"}
      ]

      child_stops_1 = [
        %Stop{id: "harsq-child-1", parent_id: "place-harsq"},
        %Stop{id: "portr-child-1", parent_id: "place-portr"},
        %Stop{id: "davis-child-1", parent_id: "place-davis"},
        %Stop{id: "alfcl-child", parent_id: "place-alfcl"}
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn "Red", [include: "representative_trip.stops"] ->
             [
               %APIRoutePattern{
                 direction_id: 0,
                 stops: child_stops_0,
                 route_id: "Red",
                 id: "Red-1"
               },
               %APIRoutePattern{
                 direction_id: 1,
                 stops: child_stops_1,
                 route_id: "Red",
                 id: "Red-2"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction ->
             child_stops_0 ++ child_stops_1
           end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route_id, _direction ->
             parent_stops ++ child_stops_0 ++ child_stops_1
           end
         ]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 1} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :RIDE],
                   agency_id: "1",
                   direction_id: 0,
                   route_id: "Red",
                   route_type: 1,
                   stop_id: "alfcl-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   agency_id: "1",
                   direction_id: 0,
                   route_id: "Red",
                   route_type: 1,
                   stop_id: "davis-child-0"
                 },
                 %{
                   activities: [:EXIT, :RIDE],
                   agency_id: "1",
                   direction_id: 0,
                   route_id: "Red",
                   route_type: 1,
                   stop_id: "portr-child-0"
                 },
                 %{
                   activities: [:BOARD, :RIDE],
                   agency_id: "1",
                   direction_id: 1,
                   route_id: "Red",
                   route_type: 1,
                   stop_id: "portr-child-1"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   agency_id: "1",
                   direction_id: 1,
                   route_id: "Red",
                   route_type: 1,
                   stop_id: "davis-child-1"
                 },
                 %{
                   activities: [:EXIT, :RIDE],
                   agency_id: "1",
                   direction_id: 1,
                   route_id: "Red",
                   route_type: 1,
                   stop_id: "alfcl-child"
                 }
               ]
      end
    end

    test "properly builds RDS informed entity with multiple routes, multiple stops and direction" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        stop_ids: ["a", "b"],
        route_ids: ["57", "58"],
        trip_ids: nil,
        direction: "1"
      }

      parent_stops = [%Stop{id: "a"}, %Stop{id: "b"}, %Stop{id: "c"}]

      child_stops = [
        %Stop{id: "1", parent_id: "a"},
        %Stop{id: "2", parent_id: "b"},
        %Stop{id: "3", parent_id: "c"}
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn route_id, _opts ->
             [
               %APIRoutePattern{
                 direction_id: 1,
                 stops: child_stops,
                 route_id: route_id,
                 id: "rp-1"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {RoutesRepo, [],
         [get: fn route_id, _opts -> %{id: route_id, type: 3, description: :local_bus} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   direction_id: 1,
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   stop_id: "1"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   direction_id: 1,
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   stop_id: "2"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   direction_id: 1,
                   route_id: "58",
                   route_type: 3,
                   agency_id: "1",
                   stop_id: "1"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   direction_id: 1,
                   route_id: "58",
                   route_type: 3,
                   agency_id: "1",
                   stop_id: "2"
                 }
               ]
      end
    end

    test "RDS informed entities with Red line stops on 2 branches" do
      jfk = %Stop{id: "place-jfk"}
      ashmont = %Stop{id: "place-asmnl"}
      braintree = %Stop{id: "place-brntn"}

      jfk_child = %Stop{id: "jfk-child", parent_id: jfk.id}
      ashmont_child = %Stop{id: "ashmont-child", parent_id: ashmont.id}
      braintree_child = %Stop{id: "braintree-child", parent_id: braintree.id}

      alert_data = %{
        route_type: 1,
        description_text: "description",
        header_text: "header",
        effect_name: "Shuttle",
        stop_ids: ["place-jfk", "place-asmnl", "place-brntn"],
        route_ids: ["Red"],
        trip_ids: nil,
        direction: "default"
      }

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn
             "Red", _ ->
               [
                 %APIRoutePattern{
                   direction_id: 0,
                   stops: [jfk_child, ashmont_child],
                   route_id: "Red",
                   id: "Red-1"
                 },
                 %APIRoutePattern{
                   direction_id: 1,
                   stops: [ashmont_child, jfk_child],
                   route_id: "Red",
                   id: "Red-2"
                 },
                 %APIRoutePattern{
                   direction_id: 0,
                   stops: [jfk_child, braintree_child],
                   route_id: "Red",
                   id: "Red-3"
                 },
                 %APIRoutePattern{
                   direction_id: 1,
                   stops: [braintree_child, jfk_child],
                   route_id: "Red",
                   id: "Red-4"
                 }
               ]
           end,
           included_stops_by_route_id: fn _route_id, _direction ->
             [jfk_child, ashmont_child, braintree_child]
           end
         ]},
        {StopsRepo, [],
         [
           by_route: fn
             "Red", _ -> [jfk, ashmont, braintree]
           end
         ]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 1} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDS)

        assert result.informed_entity ==
                 [
                   %{
                     activities: [:BOARD, :RIDE],
                     agency_id: "1",
                     direction_id: 0,
                     route_id: "Red",
                     route_type: 1,
                     stop_id: "jfk-child"
                   },
                   %{
                     activities: [:EXIT, :RIDE],
                     agency_id: "1",
                     direction_id: 0,
                     route_id: "Red",
                     route_type: 1,
                     stop_id: "ashmont-child"
                   },
                   %{
                     activities: [:BOARD, :RIDE],
                     agency_id: "1",
                     direction_id: 1,
                     route_id: "Red",
                     route_type: 1,
                     stop_id: "ashmont-child"
                   },
                   %{
                     activities: [:EXIT, :RIDE],
                     agency_id: "1",
                     direction_id: 1,
                     route_id: "Red",
                     route_type: 1,
                     stop_id: "jfk-child"
                   },
                   %{
                     activities: [:EXIT, :RIDE],
                     agency_id: "1",
                     route_id: "Red",
                     route_type: 1,
                     direction_id: 0,
                     stop_id: "braintree-child"
                   },
                   %{
                     activities: [:BOARD, :RIDE],
                     agency_id: "1",
                     route_id: "Red",
                     route_type: 1,
                     direction_id: 1,
                     stop_id: "braintree-child"
                   }
                 ]
      end
    end

    test "RDS informed entities with Red line stops on 1 branch" do
      jfk = %Stop{id: "place-jfk"}
      ashmont = %Stop{id: "place-asmnl"}
      braintree = %Stop{id: "place-brntn"}

      jfk_child = %Stop{id: "jfk-child", parent_id: jfk.id}
      ashmont_child = %Stop{id: "ashmont-child", parent_id: ashmont.id}
      braintree_child = %Stop{id: "braintree-child", parent_id: braintree.id}

      alert_data = %{
        route_type: 1,
        description_text: "description",
        header_text: "header",
        effect_name: "Shuttle",
        stop_ids: ["place-jfk", "place-asmnl"],
        route_ids: ["Red"],
        trip_ids: nil,
        direction: "default"
      }

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn
             "Red", _ ->
               [
                 %APIRoutePattern{
                   direction_id: 0,
                   stops: [jfk_child, ashmont_child],
                   route_id: "Red",
                   id: "Red-1"
                 },
                 %APIRoutePattern{
                   direction_id: 1,
                   stops: [ashmont_child, jfk_child],
                   route_id: "Red",
                   id: "Red-2"
                 },
                 %APIRoutePattern{
                   direction_id: 0,
                   stops: [jfk_child, braintree_child],
                   route_id: "Red",
                   id: "Red-3"
                 },
                 %APIRoutePattern{
                   direction_id: 1,
                   stops: [braintree_child, jfk_child],
                   route_id: "Red",
                   id: "Red-4"
                 }
               ]
           end,
           included_stops_by_route_id: fn _route_id, _direction ->
             [jfk_child, ashmont_child, braintree_child]
           end
         ]},
        {StopsRepo, [],
         [
           by_route: fn
             "Red", _ -> [jfk, ashmont, braintree]
           end
         ]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 1} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :RIDE],
                   agency_id: "1",
                   direction_id: 0,
                   route_id: "Red",
                   route_type: 1,
                   stop_id: "jfk-child"
                 },
                 %{
                   activities: [:EXIT, :RIDE],
                   agency_id: "1",
                   direction_id: 0,
                   route_id: "Red",
                   route_type: 1,
                   stop_id: "ashmont-child"
                 },
                 %{
                   activities: [:BOARD, :RIDE],
                   agency_id: "1",
                   direction_id: 1,
                   route_id: "Red",
                   route_type: 1,
                   stop_id: "ashmont-child"
                 },
                 %{
                   activities: [:EXIT, :RIDE],
                   agency_id: "1",
                   direction_id: 1,
                   route_id: "Red",
                   route_type: 1,
                   stop_id: "jfk-child"
                 }
               ]
      end
    end

    test "RDS informed entities where JFK is in middle of red line shuttle alert (both directions)" do
      andrew = %Stop{id: "place-andrw"}
      jfk = %Stop{id: "place-jfk"}
      savin_hill = %Stop{id: "place-shmnl"}
      north_quincy = %Stop{id: "place-nqncy"}

      andrew_child_s = %Stop{id: "andrew-child-s", parent_id: andrew.id, vehicle_type: 1}
      andrew_child_n = %Stop{id: "andrew-child-n", parent_id: andrew.id, vehicle_type: 1}
      jfk_child_to_savin_s = %Stop{id: "jfk-child-3", parent_id: jfk.id, vehicle_type: 1}
      jfk_child_to_savin_n = %Stop{id: "jfk-child-4", parent_id: jfk.id, vehicle_type: 1}
      savin_child_s = %Stop{id: "savin-child-s", parent_id: savin_hill.id, vehicle_type: 1}
      savin_child_n = %Stop{id: "savin-child-n", parent_id: savin_hill.id, vehicle_type: 1}
      jfk_child_to_quincy_s = %Stop{id: "jfk-child-1", parent_id: jfk.id, vehicle_type: 1}
      jfk_child_to_quincy_n = %Stop{id: "jfk-child-2", parent_id: jfk.id, vehicle_type: 1}

      north_quincy_child_s = %Stop{
        id: "north_quincy-child-s",
        parent_id: north_quincy.id,
        vehicle_type: 1
      }

      north_quincy_child_n = %Stop{
        id: "north_quincy-child-n",
        parent_id: north_quincy.id,
        vehicle_type: 1
      }

      alert_data = %{
        route_type: 1,
        description_text: "description",
        header_text: "header",
        effect_name: "Shuttle",
        stop_ids: ["place-andrw", "place-jfk", "place-nqncy"],
        route_ids: ["Red"],
        trip_ids: nil,
        direction: "default"
      }

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn
             "Red", _ ->
               [
                 %APIRoutePattern{
                   id: "Red-3-0",
                   name: "Alewife - Braintree",
                   direction_id: 0,
                   stops: [andrew_child_s, jfk_child_to_quincy_s, north_quincy_child_s],
                   route_id: "Red",
                   typicality: 1
                 },
                 %APIRoutePattern{
                   id: "Red-3-1",
                   name: "Braintree - Alewife",
                   direction_id: 1,
                   stops: [north_quincy_child_n, jfk_child_to_quincy_n, andrew_child_n],
                   route_id: "Red",
                   typicality: 1
                 },
                 %APIRoutePattern{
                   name: "Alewife - Ashmont",
                   id: "Red-1-0",
                   direction_id: 0,
                   stops: [andrew_child_s, jfk_child_to_savin_s, savin_child_s],
                   route_id: "Red",
                   typicality: 3
                 },
                 %APIRoutePattern{
                   name: "Ashmont - Alewife",
                   id: "Red-1-1",
                   direction_id: 1,
                   stops: [savin_child_n, jfk_child_to_savin_n, andrew_child_n],
                   route_id: "Red",
                   typicality: 3
                 },
                 %APIRoutePattern{
                   id: "Shuttle-AshmontJFK-0-0",
                   direction_id: 0,
                   stops: [%Stop{id: "121"}, %Stop{id: "305"}],
                   route_id: "Red",
                   typicality: 5
                 }
               ]
           end,
           included_stops_by_route_id: fn _route_id, _direction ->
             [
               jfk_child_to_savin_s,
               savin_child_s,
               jfk_child_to_quincy_s,
               north_quincy_child_s,
               andrew_child_s,
               jfk_child_to_savin_n,
               savin_child_n,
               jfk_child_to_quincy_n,
               north_quincy_child_n,
               andrew_child_n,
               savin_child_s,
               savin_child_n
             ]
           end
         ]},
        {StopsRepo, [],
         [
           by_route: fn
             "Red", _ -> [jfk, savin_hill, andrew, north_quincy]
           end
         ]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 1} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDS)

        assert result.informed_entity ==
                 [
                   %{
                     activities: [:BOARD, :RIDE],
                     agency_id: "1",
                     direction_id: 0,
                     route_id: "Red",
                     route_type: 1,
                     stop_id: "andrew-child-s"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     agency_id: "1",
                     direction_id: 0,
                     route_id: "Red",
                     route_type: 1,
                     stop_id: "jfk-child-1"
                   },
                   %{
                     activities: [:EXIT, :RIDE],
                     agency_id: "1",
                     direction_id: 0,
                     route_id: "Red",
                     route_type: 1,
                     stop_id: "north_quincy-child-s"
                   },
                   %{
                     activities: [:BOARD, :RIDE],
                     agency_id: "1",
                     direction_id: 1,
                     route_id: "Red",
                     route_type: 1,
                     stop_id: "north_quincy-child-n"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     agency_id: "1",
                     direction_id: 1,
                     route_id: "Red",
                     route_type: 1,
                     stop_id: "jfk-child-2"
                   },
                   %{
                     activities: [:EXIT, :RIDE],
                     agency_id: "1",
                     direction_id: 1,
                     route_id: "Red",
                     route_type: 1,
                     stop_id: "andrew-child-n"
                   },
                   %{
                     agency_id: "1",
                     route_id: "Red",
                     route_type: 1,
                     direction_id: 0,
                     stop_id: "jfk-child-3",
                     activities: [:EXIT, :RIDE]
                   },
                   %{
                     agency_id: "1",
                     route_id: "Red",
                     route_type: 1,
                     direction_id: 1,
                     stop_id: "jfk-child-4",
                     activities: [:BOARD, :RIDE]
                   }
                 ]
      end
    end

    test "RDS informed entities expanding Green Line routes" do
      hynes = %Stop{id: "place-hymnl"}
      kenmore = %Stop{id: "place-kencl"}
      fenway = %Stop{id: "place-fenwy"}

      hynes_child = %Stop{id: "hynes-child", parent_id: hynes.id}
      kenmore_child = %Stop{id: "kenmore-child", parent_id: kenmore.id}
      fenway_child = %Stop{id: "fenway-child", parent_id: fenway.id}

      alert_data = %{
        route_type: 1,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        stop_ids: ["place-hymnl", "place-kencl", "place-fenwy"],
        route_ids: ["Green"],
        trip_ids: nil,
        direction: "default"
      }

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn
             "Green-B", _ ->
               [
                 %APIRoutePattern{
                   direction_id: 0,
                   stops: [hynes_child, kenmore_child],
                   route_id: "Green-B",
                   id: "green-b-1"
                 },
                 %APIRoutePattern{
                   direction_id: 1,
                   stops: [kenmore_child, hynes_child],
                   route_id: "Green-B",
                   id: "green-b-2"
                 }
               ]

             "Green-C", _ ->
               [
                 %APIRoutePattern{
                   direction_id: 0,
                   stops: [kenmore_child, hynes_child],
                   route_id: "Green-C",
                   id: "green-c-1"
                 },
                 %APIRoutePattern{
                   direction_id: 1,
                   stops: [hynes_child, kenmore_child],
                   route_id: "Green-C",
                   id: "green-c-2"
                 }
               ]

             "Green-D", _ ->
               [
                 %APIRoutePattern{
                   direction_id: 0,
                   stops: [fenway_child, kenmore_child, hynes_child],
                   route_id: "Green-D",
                   id: "green-d-1"
                 },
                 %APIRoutePattern{
                   direction_id: 1,
                   stops: [hynes_child, kenmore_child, fenway_child],
                   route_id: "Green-D",
                   id: "green-d-2"
                 }
               ]

             "Green-E", _ ->
               []
           end,
           included_stops_by_route_id: fn _route_id, _direction ->
             [hynes_child, kenmore_child, fenway_child]
           end
         ]},
        {StopsRepo, [],
         [
           by_route: fn
             "Green-B", _ -> [hynes, kenmore]
             "Green-C", _ -> [hynes, kenmore]
             "Green-D", _ -> [hynes, kenmore, fenway]
             "Green-E", _ -> []
           end
         ]},
        {RoutesRepo, [],
         [
           get: fn route_id, _opts -> %Route{id: route_id, type: 1} end,
           green_line: fn -> @green_line_virtual_route end
         ]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDS)

        assert result.informed_entity == [
                 %{
                   agency_id: "1",
                   route_id: "Green-B",
                   route_type: 1,
                   direction_id: 0,
                   stop_id: "hynes-child",
                   activities: [:BOARD, :EXIT, :RIDE]
                 },
                 %{
                   agency_id: "1",
                   route_id: "Green-B",
                   route_type: 1,
                   direction_id: 0,
                   stop_id: "kenmore-child",
                   activities: [:BOARD, :EXIT, :RIDE]
                 },
                 %{
                   agency_id: "1",
                   route_id: "Green-B",
                   route_type: 1,
                   direction_id: 1,
                   stop_id: "kenmore-child",
                   activities: [:BOARD, :EXIT, :RIDE]
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   agency_id: "1",
                   direction_id: 1,
                   route_id: "Green-B",
                   route_type: 1,
                   stop_id: "hynes-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   agency_id: "1",
                   direction_id: 0,
                   route_id: "Green-C",
                   route_type: 1,
                   stop_id: "kenmore-child"
                 },
                 %{
                   agency_id: "1",
                   route_id: "Green-C",
                   route_type: 1,
                   direction_id: 0,
                   stop_id: "hynes-child",
                   activities: [:BOARD, :EXIT, :RIDE]
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   agency_id: "1",
                   direction_id: 1,
                   route_id: "Green-C",
                   route_type: 1,
                   stop_id: "hynes-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   agency_id: "1",
                   direction_id: 1,
                   route_id: "Green-C",
                   route_type: 1,
                   stop_id: "kenmore-child"
                 },
                 %{
                   agency_id: "1",
                   route_id: "Green-D",
                   route_type: 1,
                   direction_id: 0,
                   stop_id: "fenway-child",
                   activities: [:BOARD, :EXIT, :RIDE]
                 },
                 %{
                   agency_id: "1",
                   route_id: "Green-D",
                   route_type: 1,
                   direction_id: 0,
                   stop_id: "kenmore-child",
                   activities: [:BOARD, :EXIT, :RIDE]
                 },
                 %{
                   agency_id: "1",
                   route_id: "Green-D",
                   route_type: 1,
                   direction_id: 0,
                   stop_id: "hynes-child",
                   activities: [:BOARD, :EXIT, :RIDE]
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   agency_id: "1",
                   direction_id: 1,
                   route_id: "Green-D",
                   route_type: 1,
                   stop_id: "hynes-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   agency_id: "1",
                   direction_id: 1,
                   route_id: "Green-D",
                   route_type: 1,
                   stop_id: "kenmore-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   agency_id: "1",
                   direction_id: 1,
                   route_id: "Green-D",
                   route_type: 1,
                   stop_id: "fenway-child"
                 }
               ]
      end
    end

    test "properly builds R informed entity" do
      with_mocks([
        {RoutePatternsRepo, [], by_route_id: fn _route_id, _opts -> [] end},
        {RoutesRepo, [],
         [
           get: fn route_id, _opts -> %Route{id: route_id, type: 3} end,
           green_line: fn -> @green_line_virtual_route end
         ]}
      ]) do
        alert_data = %{
          route_type: 3,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["57", "58"],
          direction: "default"
        }

        result = AlertBuilder.build_alert(alert_data, :R)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "58",
                   route_type: 3,
                   agency_id: "1"
                 }
               ]
      end
    end

    test "R informed entities expanding Green Line routes" do
      with_mocks([
        {RoutePatternsRepo, [], by_route_id: fn _route_id, _opts -> [] end},
        {RoutesRepo, [],
         [
           get: fn route_id, _opts -> %Route{id: route_id, type: 1} end,
           green_line: fn -> @green_line_virtual_route end
         ]}
      ]) do
        alert_data = %{
          route_type: 1,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["Red", "Green", "Green-D"],
          direction: "default"
        }

        result = AlertBuilder.build_alert(alert_data, :R)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Red",
                   route_type: 1,
                   agency_id: "1"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-B",
                   route_type: 1,
                   agency_id: "1"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-C",
                   route_type: 1,
                   agency_id: "1"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-D",
                   route_type: 1,
                   agency_id: "1"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-E",
                   route_type: 1,
                   agency_id: "1"
                 }
               ]
      end
    end

    test "properly builds R informed entity with direction" do
      with_mocks([
        {RoutePatternsRepo, [], by_route_id: fn _route_id, _opts -> [] end},
        {RoutesRepo, [],
         [
           get: fn route_id, _opts -> %Route{id: route_id, type: 3} end,
           green_line: fn -> @green_line_virtual_route end
         ]}
      ]) do
        alert_data = %{
          route_type: 3,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["57", "58"],
          direction: "1"
        }

        result = AlertBuilder.build_alert(alert_data, :R)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   direction_id: 1
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "58",
                   route_type: 3,
                   agency_id: "1",
                   direction_id: 1
                 }
               ]
      end
    end

    test "R informed entities with direction expanding Green Line routes" do
      with_mocks([
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]},
        {RoutesRepo, [],
         [
           get: fn route_id, _opts -> %Route{id: route_id, type: 1} end,
           green_line: fn -> @green_line_virtual_route end
         ]}
      ]) do
        alert_data = %{
          route_type: 1,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["Red", "Green", "Green-D"],
          direction: "1"
        }

        result = AlertBuilder.build_alert(alert_data, :R)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Red",
                   route_type: 1,
                   agency_id: "1",
                   direction_id: 1
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-B",
                   route_type: 1,
                   agency_id: "1",
                   direction_id: 1
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-C",
                   route_type: 1,
                   agency_id: "1",
                   direction_id: 1
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-D",
                   route_type: 1,
                   agency_id: "1",
                   direction_id: 1
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-E",
                   route_type: 1,
                   agency_id: "1",
                   direction_id: 1
                 }
               ]
      end
    end

    test "properly builds RDT informed entity" do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
        alert_data = %{
          route_type: 3,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["57"],
          trip_ids: ["123", "345", "456"],
          trip_information_by_id: %{
            "123" => %{direction_id: 0, route_id: "57"},
            "345" => %{direction_id: 0, route_id: "57"},
            "456" => %{direction_id: 0, route_id: "57"}
          }
        }

        result = AlertBuilder.build_alert(alert_data, :RDT)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   trip: %{
                     trip_id: "123",
                     route_id: "57",
                     direction_id: 0
                   }
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   trip: %{
                     trip_id: "345",
                     route_id: "57",
                     direction_id: 0
                   }
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   trip: %{
                     trip_id: "456",
                     route_id: "57",
                     direction_id: 0
                   }
                 }
               ]
      end
    end

    test "properly builds RDT informed entity with multiple routes, multiple trips" do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
        alert_data = %{
          route_type: 3,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["57", "58"],
          trip_ids: ["123", "345", "456"],
          trip_information_by_id: %{
            "123" => %{direction_id: 0, route_id: "57"},
            "345" => %{direction_id: 0, route_id: "57"},
            "456" => %{direction_id: 0, route_id: "58"}
          }
        }

        result = AlertBuilder.build_alert(alert_data, :RDT)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   trip: %{
                     trip_id: "123",
                     route_id: "57",
                     direction_id: 0
                   }
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   trip: %{
                     trip_id: "345",
                     route_id: "57",
                     direction_id: 0
                   }
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "58",
                   route_type: 3,
                   agency_id: "1",
                   trip: %{
                     trip_id: "456",
                     route_id: "58",
                     direction_id: 0
                   }
                 }
               ]
      end
    end

    test "properly builds RDT informed entity with 1 route, all trips" do
      with_mocks([
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 3} end]}
      ]) do
        alert_data = %{
          route_type: 3,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["57"],
          trip_ids: [],
          direction: "default"
        }

        result = AlertBuilder.build_alert(alert_data, :RDT)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1"
                 }
               ]
      end
    end

    test "RDTS informed entity with trips and no stops selected treated as RDT" do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
        alert_data = %{
          route_type: 3,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["57"],
          trip_ids: ["123", "345", "456"],
          trip_information_by_id: %{
            "123" => %{direction_id: 0, route_id: "57"},
            "345" => %{direction_id: 0, route_id: "57"},
            "456" => %{direction_id: 0, route_id: "57"}
          },
          stop_ids: [],
          direction: "default"
        }

        result = AlertBuilder.build_alert(alert_data, :RDTS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   trip: %{
                     trip_id: "123",
                     route_id: "57",
                     direction_id: 0
                   }
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   trip: %{
                     trip_id: "345",
                     route_id: "57",
                     direction_id: 0
                   }
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   trip: %{
                     trip_id: "456",
                     route_id: "57",
                     direction_id: 0
                   }
                 }
               ]
      end
    end

    test "RDTS informed entity with stops and no trips selected treated as RDS" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["57"],
        trip_ids: [],
        trip_information_by_id: %{},
        stop_ids: ["a", "b", "c"],
        direction: "0"
      }

      parent_stops = [
        %Stop{id: "a"},
        %Stop{id: "b"},
        %Stop{id: "c"}
      ]

      child_stops = [
        %Stop{id: "1", parent_id: "a"},
        %Stop{id: "2", parent_id: "b"},
        %Stop{id: "3", parent_id: "c"}
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn route_id, _opts ->
             [
               %APIRoutePattern{
                 direction_id: 1,
                 stops: child_stops,
                 route_id: route_id,
                 id: "rp_1"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 3} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDTS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   direction_id: 1,
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   stop_id: "1"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   direction_id: 1,
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   stop_id: "2"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   direction_id: 1,
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   stop_id: "3"
                 }
               ]
      end
    end

    test "RDTS informed entity with no stops and no trips selected treated as R" do
      with_mocks([
        {RoutePatternsRepo, [], by_route_id: fn _route_id, _opts -> [] end},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 3} end]}
      ]) do
        alert_data = %{
          route_type: 3,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["57", "58"],
          trip_ids: [],
          stop_ids: [],
          direction: "default"
        }

        result = AlertBuilder.build_alert(alert_data, :RDTS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "58",
                   route_type: 3,
                   agency_id: "1"
                 }
               ]
      end
    end

    test "RDTS informed entity with trips and stops is build properly" do
      alert_data = %{
        route_type: 2,
        effect_name: "Delay",
        route_ids: ["CR-Fitchburg"],
        direction: "default",
        trip_ids: ["default", "CR-627754-435"],
        trip_information_by_id: %{
          "CR-627754-435" => %{direction_id: 0, route_id: "CR-Fitchburg"}
        },
        stop_ids: ["place-FR-0201", "place-FR-0219"],
        header_text: "t",
        description_text: "t"
      }

      parent_stops = [%Stop{id: "place-FR-0201"}, %Stop{id: "place-FR-0219"}]

      child_stops = [
        %Stop{
          id: "FR-0201-01",
          parent_id: "place-FR-0201"
        },
        %Stop{
          id: "FR-0219-01",
          parent_id: "place-FR-0219"
        },
        # Intentional duplicates
        %Stop{
          id: "FR-0201-01",
          parent_id: "place-FR-0201"
        },
        %Stop{
          id: "FR-0219-01",
          parent_id: "place-FR-0219"
        }
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn route_id, _opts ->
             [
               %APIRoutePattern{
                 direction_id: 0,
                 stops: child_stops,
                 route_id: route_id,
                 id: "rp-1"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {SchedulesRepo, [],
         [trip: fn "CR-627754-435" -> %Trip{id: "CR-627754-435", direction_id: 0} end]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 2} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDTS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   agency_id: "1",
                   route_id: "CR-Fitchburg",
                   route_type: 2,
                   stop_id: "FR-0201-01",
                   trip: %{
                     direction_id: 0,
                     route_id: "CR-Fitchburg",
                     trip_id: "CR-627754-435"
                   }
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   agency_id: "1",
                   route_id: "CR-Fitchburg",
                   route_type: 2,
                   stop_id: "FR-0219-01",
                   trip: %{
                     direction_id: 0,
                     route_id: "CR-Fitchburg",
                     trip_id: "CR-627754-435"
                   }
                 }
               ]
      end
    end

    test "RDTS informed entity with trips and stops uses parents stops if no child stops available" do
      alert_data = %{
        route_type: 4,
        effect_name: "Delay",
        route_ids: ["Boat-EastBoston"],
        direction: "default",
        trip_ids: ["default", "Boat-EastBoston-1115-Long-BEB-01-Weekday-Summer-24"],
        trip_information_by_id: %{
          "Boat-EastBoston-1115-Long-BEB-01-Weekday-Summer-24" => %{
            direction_id: 0,
            route_id: "Boat-EastBoston"
          }
        },
        stop_ids: ["Boat-Long"],
        header_text: "t",
        description_text: "t"
      }

      parent_stops = [%Stop{id: "Boat-Long"}]

      child_stops = []

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn route_id, _opts ->
             [
               %APIRoutePattern{
                 direction_id: 0,
                 stops: child_stops,
                 route_id: route_id,
                 id: "rp_1"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {SchedulesRepo, [],
         [
           trip: fn "Boat-EastBoston-1115-Long-BEB-01-Weekday-Summer-24" ->
             %Trip{id: "Boat-EastBoston-1115-Long-BEB-01-Weekday-Summer-24", direction_id: 0}
           end
         ]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 4} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDTS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   agency_id: "1",
                   route_id: "Boat-EastBoston",
                   route_type: 4,
                   stop_id: "Boat-Long",
                   trip: %{
                     direction_id: 0,
                     route_id: "Boat-EastBoston",
                     trip_id: "Boat-EastBoston-1115-Long-BEB-01-Weekday-Summer-24"
                   }
                 }
               ]
      end
    end

    test "RDTS CR track change 1 trip" do
      alert_data = %{
        route_type: 2,
        effect_name: "Track Change",
        description_text: "CR track change",
        header_text: "CR track change",
        route_ids: ["CR-Haverhill"],
        direction: "0",
        trip_ids: ["default", "CR-627678-295"],
        trip_information_by_id: %{
          "CR-627678-295" => %{direction_id: 0, route_id: "CR-Haverhill"}
        },
        stop_ids: ["place-WR-0067", "place-WR-0075"]
      }

      parent_stops = [%Stop{id: "place-WR-0067"}, %Stop{id: "place-WR-0075"}]

      child_stops = [
        %Stop{
          id: "WR-0067-01",
          parent_id: "place-WR-0067",
          vehicle_type: 2
        },
        %Stop{
          id: "WR-0075-01",
          parent_id: "place-WR-0075",
          vehicle_type: 2
        }
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn route_id, _opts ->
             [
               %APIRoutePattern{
                 direction_id: 0,
                 stops: child_stops,
                 route_id: route_id,
                 id: "rp_1"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {SchedulesRepo, [],
         [trip: fn "CR-627678-295" -> %Trip{id: "CR-627678-295", direction_id: 0} end]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 2} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDTS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD],
                   route_id: "CR-Haverhill",
                   route_type: 2,
                   agency_id: "1",
                   stop_id: "WR-0067-01",
                   trip: %{
                     trip_id: "CR-627678-295",
                     route_id: "CR-Haverhill",
                     direction_id: 0
                   }
                 },
                 %{
                   activities: [:BOARD],
                   route_id: "CR-Haverhill",
                   route_type: 2,
                   agency_id: "1",
                   stop_id: "WR-0075-01",
                   trip: %{
                     trip_id: "CR-627678-295",
                     route_id: "CR-Haverhill",
                     direction_id: 0
                   }
                 }
               ]
      end
    end

    test "RDTS CR delay does not include duplicate informed entities" do
      alert_data = %{
        route_type: 2,
        effect_name: "Track Change",
        description_text: "CR track change",
        header_text: "CR track change",
        route_ids: ["CR-Haverhill"],
        direction: "0",
        trip_ids: ["default", "CR-627678-295"],
        trip_information_by_id: %{
          "CR-627678-295" => %{direction_id: 0, route_id: "CR-Haverhill"}
        },
        stop_ids: ["place-WR-0067", "place-WR-0075"]
      }

      parent_stops = [%Stop{id: "place-WR-0067"}, %Stop{id: "place-WR-0075"}]

      child_stops = [
        %Stop{
          id: "WR-0067-01",
          parent_id: "place-WR-0067",
          vehicle_type: 2
        },
        %Stop{
          id: "WR-0075-01",
          parent_id: "place-WR-0075",
          vehicle_type: 2
        }
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn route_id, _opts ->
             [
               %APIRoutePattern{
                 direction_id: 0,
                 stops: child_stops,
                 route_id: route_id,
                 id: "rp_1"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {SchedulesRepo, [],
         [trip: fn "CR-627678-295" -> %Trip{id: "CR-627678-295", direction_id: 0} end]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 2} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDTS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD],
                   route_id: "CR-Haverhill",
                   route_type: 2,
                   agency_id: "1",
                   stop_id: "WR-0067-01",
                   trip: %{
                     trip_id: "CR-627678-295",
                     route_id: "CR-Haverhill",
                     direction_id: 0
                   }
                 },
                 %{
                   activities: [:BOARD],
                   route_id: "CR-Haverhill",
                   route_type: 2,
                   agency_id: "1",
                   stop_id: "WR-0075-01",
                   trip: %{
                     trip_id: "CR-627678-295",
                     route_id: "CR-Haverhill",
                     direction_id: 0
                   }
                 }
               ]
      end
    end

    test "RDTS CR delay does not include child stops for other direction than trip" do
      trip_id = "CR-627754-435"

      alert_data = %{
        route_type: 2,
        effect_name: "Delay",
        description_text: "CR delay",
        header_text: "CR delay",
        route_ids: ["CR-Fitchburg"],
        direction: "default",
        trip_ids: ["default", trip_id],
        trip_information_by_id: %{
          trip_id => %{direction_id: 0, route_id: "CR-Fitchburg"}
        },
        stop_ids: ["place-FR-0201", "place-FR-0219"]
      }

      parent_stops = [%Stop{id: "place-FR-0201"}, %Stop{id: "place-FR-0219"}]

      child_stops_0 = [
        %Stop{id: "FR-0201-01", parent_id: "place-FR-0201"},
        %Stop{id: "FR-0219-01", parent_id: "place-FR-0219"}
      ]

      child_stops_1 = [
        %Stop{id: "FR-0219-02", parent_id: "place-FR-0219"},
        %Stop{id: "FR-0201-02", parent_id: "place-FR-0201"}
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn "CR-Fitchburg", [include: "representative_trip.stops"] ->
             [
               %APIRoutePattern{
                 direction_id: 0,
                 stops: child_stops_0,
                 route_id: "CR-Fitchburg",
                 id: "CR-Fitchburg-1"
               },
               %APIRoutePattern{
                 direction_id: 1,
                 stops: child_stops_1,
                 route_id: "CR-Fitchburg",
                 id: "CR-Fitchburg-2"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction ->
             child_stops_0 ++ child_stops_1
           end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route_id, _direction ->
             parent_stops ++ child_stops_0 ++ child_stops_1
           end
         ]},
        {SchedulesRepo, [], [trip: fn ^trip_id -> %Trip{id: trip_id, direction_id: 0} end]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 2} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDTS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "CR-Fitchburg",
                   route_type: 2,
                   agency_id: "1",
                   stop_id: "FR-0201-01",
                   trip: %{
                     trip_id: trip_id,
                     route_id: "CR-Fitchburg",
                     direction_id: 0
                   }
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "CR-Fitchburg",
                   route_type: 2,
                   agency_id: "1",
                   stop_id: "FR-0219-01",
                   trip: %{
                     trip_id: trip_id,
                     route_id: "CR-Fitchburg",
                     direction_id: 0
                   }
                 }
               ]
      end
    end

    test "SR informed entity routes and stops includes route type" do
      alert_data = %{
        route_type: 1,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["56", "57", "58"],
        route_types_by_id: %{"56" => 1, "57" => 3, "58" => 1},
        stop_ids: ["a", "b"],
        direction: "default"
      }

      parent_stops = [%Stop{id: "a"}, %Stop{id: "b"}]

      child_stops = [
        %Stop{
          id: "child-a",
          parent_id: "a",
          vehicle_type: 1
        },
        %Stop{
          id: "child-b",
          parent_id: "b",
          vehicle_type: 1
        }
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn route_id, _opts ->
             [
               %APIRoutePattern{
                 direction_id: 0,
                 stops: child_stops,
                 route_id: route_id,
                 id: "rp_1"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 1} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :SR)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "56",
                   route_type: 1,
                   agency_id: "1",
                   stop_id: "child-a"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "56",
                   route_type: 1,
                   agency_id: "1",
                   stop_id: "child-b"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   stop_id: "child-a"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   stop_id: "child-b"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "58",
                   route_type: 1,
                   agency_id: "1",
                   stop_id: "child-a"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "58",
                   route_type: 1,
                   agency_id: "1",
                   stop_id: "child-b"
                 }
               ]
      end
    end

    test "SR informed entity when stop has no child stops" do
      alert_data = %{
        stop_ids: ["Boat-Charlestown"],
        route_type: 4,
        route_ids: ["Boat-F4"],
        effect_name: "Dock Closure",
        description_text: "b",
        header_text: "a",
        route_types_by_id: %{"Boat-F4" => 4}
      }

      parent_stops = [%Stop{id: "Boat-Charlestown"}]

      child_stops = []

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn route_id, _opts ->
             [
               %APIRoutePattern{
                 direction_id: 0,
                 stops: child_stops,
                 route_id: route_id,
                 id: "rp_1"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {RoutesRepo, [],
         [get: fn "Boat-F4", _opts -> %Route{id: "Boat-F4", line_id: "line-Boat-F4", type: 4} end]},
        {LinesRepo, [],
         [
           get: fn
             "line-Boat-F4", _opts ->
               %Line{
                 id: "line-Boat-F4",
                 route_ids: ["Boat-F4"],
                 routes: [
                   %Route{id: "Boat-F4", line_id: "line-Boat-F4", type: 4}
                 ]
               }
           end
         ]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :SR)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT],
                   agency_id: "1",
                   route_id: "Boat-F4",
                   route_type: 4,
                   stop_id: "Boat-Charlestown"
                 }
               ]
      end
    end

    test "SR informed entity for bus when route patterns have parent stops on them" do
      # Unlike the above tests, we will have entries in "child stops with context"
      # but we need to avoid filtering out our stops when we check to see if they're on the route
      alert_data = %{
        stop_ids: ["4561"],
        route_type: 3,
        route_ids: ["435"],
        effect_name: "Multi-Route Detour",
        description_text: "b",
        header_text: "a",
        route_types_by_id: %{"435" => 3}
      }

      parent_stops = [%Stop{id: "4561"}]

      child_stops = []

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn route_id, _opts ->
             [
               %APIRoutePattern{
                 direction_id: 0,
                 stops: parent_stops ++ child_stops,
                 route_id: route_id
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> parent_stops ++ child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {RoutesRepo, [],
         [
           get: fn "435", _opts -> %Route{id: "435", line_id: "line-435", type: 3} end,
           green_line: fn -> @green_line_virtual_route end
         ]},
        {LinesRepo, [],
         [
           get: fn
             "line-435", _opts ->
               %Line{
                 id: "line-435",
                 route_ids: ["435"],
                 routes: [
                   %Route{id: "435", type: 3}
                 ]
               }
           end
         ]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :SR)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT],
                   agency_id: "1",
                   route_id: "435",
                   route_type: 3,
                   stop_id: "4561"
                 }
               ]
      end
    end

    test "SR informed entity expanding Green Line routes" do
      alert_data = %{
        route_type: 0,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["Green", "Green-D"],
        route_types_by_id: %{"Green" => 0, "Green-D" => 0},
        stop_ids: ["place-hymnl", "place-kencl", "place-fenwy"],
        direction: "default"
      }

      hynes = %Stop{id: "place-hymnl"}
      kenmore = %Stop{id: "place-kencl"}
      fenway = %Stop{id: "place-fenwy"}

      hynes_child = %Stop{id: "hynes-child", parent_id: "place-hymnl"}
      kenmore_child = %Stop{id: "kenmore-child", parent_id: "place-kencl"}
      fenway_child = %Stop{id: "fenway-child", parent_id: "place-fenwy"}
      child_stops = [hynes_child, kenmore_child, fenway_child]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn route_id, _opts ->
             [
               %APIRoutePattern{
                 direction_id: 0,
                 stops: child_stops,
                 route_id: route_id,
                 id: "rp_1"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [],
         [
           by_route: fn
             "Green-B", 0 -> [hynes, hynes_child, kenmore, kenmore_child]
             "Green-B", 1 -> [hynes, hynes_child, kenmore, kenmore_child]
             "Green-C", 0 -> [hynes, hynes_child, kenmore, kenmore_child]
             "Green-C", 1 -> [hynes, hynes_child, kenmore, kenmore_child]
             "Green-D", 0 -> [hynes, hynes_child, kenmore, kenmore_child, fenway, fenway_child]
             "Green-D", 1 -> [hynes, hynes_child, kenmore, kenmore_child, fenway, fenway_child]
             "Green-E", 0 -> []
             "Green-E", 1 -> []
           end
         ]},
        {RoutesRepo, [],
         [
           get: fn route_id, _opts -> %Route{id: route_id, type: 0} end,
           green_line: fn -> @green_line_virtual_route end
         ]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :SR)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-B",
                   route_type: 0,
                   agency_id: "1",
                   stop_id: "hynes-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-B",
                   route_type: 0,
                   agency_id: "1",
                   stop_id: "kenmore-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-C",
                   route_type: 0,
                   agency_id: "1",
                   stop_id: "hynes-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-C",
                   route_type: 0,
                   agency_id: "1",
                   stop_id: "kenmore-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-D",
                   route_type: 0,
                   agency_id: "1",
                   stop_id: "hynes-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-D",
                   route_type: 0,
                   agency_id: "1",
                   stop_id: "kenmore-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-D",
                   route_type: 0,
                   agency_id: "1",
                   stop_id: "fenway-child"
                 }
               ]
      end
    end

    test "SR CR Station Issue" do
      alert_data = %{
        route_type: 2,
        route_ids: ["CR-Kingston"],
        stop_ids: ["place-PB-0194"],
        effect_name: "Station Issue",
        header_text: "Test 10",
        description_text: "Test 10",
        route_types_by_id: %{"CR-Kingston" => 2}
      }

      parent_stops = [%Stop{id: "place-PB-0194"}]

      child_stops = [
        %Stop{
          id: "PB-0194-S",
          parent_id: "place-PB-0194"
        },
        # Intentional duplicate
        %Stop{
          id: "PB-0194-S",
          parent_id: "place-PB-0194"
        }
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn route_id, _opts ->
             [
               %APIRoutePattern{
                 direction_id: 0,
                 stops: child_stops,
                 route_id: route_id,
                 id: "rp_1"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {RoutesRepo, [], [get: fn route_id, _opts -> %Route{id: route_id, type: 2} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :SR)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD],
                   agency_id: "1",
                   route_id: "CR-Kingston",
                   route_type: 2,
                   stop_id: "PB-0194-S"
                 }
               ]
      end
    end

    test "builds systemwide bus informed entity" do
      alert_data = %{
        route_type: nil,
        effect_name: "Delay",
        service_types: [3],
        header_text: "test header",
        description_text: "test description"
      }

      result = AlertBuilder.build_alert(alert_data, nil)

      assert result.informed_entity == [
               %{
                 activities: [:BOARD, :EXIT, :RIDE],
                 route_type: 3,
                 agency_id: "1"
               }
             ]
    end

    test "builds systemwide subway informed entities" do
      alert_data = %{
        route_type: nil,
        effect_name: "Delay",
        service_types: [1],
        header_text: "test header",
        description_text: "test description"
      }

      result = AlertBuilder.build_alert(alert_data, nil)

      assert result.informed_entity == [
               %{
                 activities: [:BOARD, :EXIT, :RIDE],
                 route_type: 0,
                 agency_id: "1"
               },
               %{
                 activities: [:BOARD, :EXIT, :RIDE],
                 route_type: 1,
                 agency_id: "1"
               }
             ]
    end

    test "builds systemwide informed entities for multiple service types" do
      alert_data = %{
        route_type: nil,
        effect_name: "Delay",
        service_types: [3, 1],
        header_text: "test header",
        description_text: "test description"
      }

      result = AlertBuilder.build_alert(alert_data, nil)

      assert result.informed_entity == [
               %{
                 activities: [:BOARD, :EXIT, :RIDE],
                 route_type: 3,
                 agency_id: "1"
               },
               %{
                 activities: [:BOARD, :EXIT, :RIDE],
                 route_type: 0,
                 agency_id: "1"
               },
               %{
                 activities: [:BOARD, :EXIT, :RIDE],
                 route_type: 1,
                 agency_id: "1"
               }
             ]
    end

    test "builds systemwide informed entities for all service types" do
      alert_data = %{
        route_type: nil,
        effect_name: "Delay",
        header_text: "test header",
        description_text: "test description"
      }

      result = AlertBuilder.build_alert(alert_data, nil)

      assert result.informed_entity == [
               %{
                 activities: [:BOARD, :EXIT, :RIDE],
                 agency_id: "1"
               }
             ]
    end
  end

  test "builds facility informed entities and filters out shuttle routes" do
    alert_data = %{
      route_type: nil,
      effect_name: "Elevator Closure",
      header_text: "test header",
      description_text: "test description",
      facility_id: "349"
    }

    facility = %Facility{
      id: "349",
      type: "ESCALATOR",
      short_name: "Platform to Russell Field",
      long_name: "Alewife Escalator 349 (Platform to Russell Field)",
      stop: %Stop{
        id: "place-alfcl",
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

    stop = %Stop{
      id: "place-alfcl",
      type: "stop",
      child_ids: [
        "141",
        "70061",
        "9070061",
        "Alewife-01",
        "Alewife-02",
        "door-alfcl-alewife",
        "door-alfcl-busway",
        "door-alfcl-cambridgepark",
        "door-alfcl-pathbusway",
        "door-alfcl-russell",
        "door-alfcl-steel"
      ]
    }

    route = %Route{
      id: "Red",
      type: 1
    }

    shuttle_route = %Route{
      id: "Shuttle-BraintreeSouthStationExpress",
      type: 3,
      description: :rail_replacement_bus
    }

    with_mocks([
      {FacilitiesRepo, [], [get: fn _facility_id -> facility end]},
      {StopsRepo, [], [get!: fn _stop_id -> stop end]},
      {RoutesRepo, [], [by_stop: fn _stop_id -> [route, shuttle_route] end]}
    ]) do
      result = AlertBuilder.build_alert(alert_data, :ACCESS)

      assert result.informed_entity == [
               %{
                 stop_id: "70061",
                 route_id: "Red",
                 facility_id: "349",
                 activities: [:USING_WHEELCHAIR]
               },
               %{
                 stop_id: "Alewife-01",
                 route_id: "Red",
                 facility_id: "349",
                 activities: [:USING_WHEELCHAIR]
               },
               %{
                 stop_id: "Alewife-02",
                 route_id: "Red",
                 facility_id: "349",
                 activities: [:USING_WHEELCHAIR]
               },
               %{
                 stop_id: "door-alfcl-russell",
                 route_id: "Red",
                 facility_id: "349",
                 activities: [:USING_WHEELCHAIR]
               }
             ]
    end
  end

  test "builds facility informed entities with nil stop" do
    alert_data = %{
      route_type: nil,
      effect_name: "Elevator Closure",
      header_text: "test header",
      description_text: "test description",
      facility_id: "retailsale-303012"
    }

    facility = %Facility{
      id: "retailsale-303012",
      type: "FARE_VENDING_RETAILER",
      short_name: "7-Eleven",
      long_name: "7-Eleven",
      stop: nil,
      latitude: 42.395428,
      longitude: -71.142483,
      properties: [
        %{name: "dispenses", value: "fare-media"}
      ]
    }

    with_mocks([
      {FacilitiesRepo, [], [get: fn _facility_id -> facility end]}
    ]) do
      result = AlertBuilder.build_alert(alert_data, :ACCESS)

      assert result.informed_entity == [
               %{
                 facility_id: "retailsale-303012",
                 activities: [:USING_WHEELCHAIR]
               }
             ]
    end
  end

  test "informed entity is empty list if alert data doesn't match anything" do
    alert_data = %{
      route_type: nil,
      effect_name: "Delay",
      header_text: "test header",
      description_text: "test description",
      route_ids: []
    }

    result = AlertBuilder.build_alert(alert_data, :RDS)

    assert result.informed_entity == []
  end
end
