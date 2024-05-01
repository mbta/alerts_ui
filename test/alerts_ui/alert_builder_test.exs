defmodule AlertsUI.AlertBuilderTest do
  @moduledoc false
  use AlertsUI.DataCase, async: false
  import AlertsUI.Support.Factory
  import Mock
  alias AlertsUI.AlertBuilder
  alias AlertsUI.Alerts
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.RoutePatterns.RoutePattern, as: APIRoutePattern
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @route_data %{
    route_type: 1,
    description_text: "ok",
    header_text: "hello",
    effect_name: "Delay",
    route_ids: ["Red"],
    direction: "1"
  }

  describe "build_alert/1" do
    test "builds alert from map" do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
        existing_alert = insert(:alert, alert_id: "0")

        alert_data = %{
          route_type: 1,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["57"],
          direction: "default",
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end_specifier: :further_notice
        }

        result = AlertBuilder.build_alert(alert_data, :R)

        assert result == %{
                 effect: :SIGNIFICANT_DELAYS,
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
                 draft: false,
                 active_period: [%{start: ~U[2024-04-30 15:54:00Z], end: nil}],
                 duration_certainty: :UNKNOWN,
                 active_period_start: ~U[2024-04-30 15:54:00Z],
                 active_period_end: nil
               }

        result |> Alerts.create_or_update_alert()
        [alert_1, alert_2] = Alerts.list_all()
        assert alert_1.alert_id == existing_alert.alert_id
        assert alert_2.alert_id |> String.to_integer() > alert_1.alert_id |> String.to_integer()
      end
    end

    test "it correctly adds combo ids" do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
        existing_alert = insert(:alert, alert_id: "0")

        alert_data = %{
          route_type: 1,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["24", "27", "57"],
          direction: "default",
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end_specifier: :further_notice
        }

        result = AlertBuilder.build_alert(alert_data, :R)

        assert result == %{
                 effect: :SIGNIFICANT_DELAYS,
                 description_text: "ok",
                 header_text: "hello",
                 informed_entity: [
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "2427",
                     route_type: 1,
                     agency_id: "1"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "24",
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
                 draft: false,
                 active_period: [%{start: ~U[2024-04-30 15:54:00Z], end: nil}],
                 active_period_end: nil,
                 active_period_start: ~U[2024-04-30 15:54:00Z],
                 duration_certainty: :UNKNOWN
               }

        result |> Alerts.create_or_update_alert()
        [alert_1, alert_2] = Alerts.list_all() |> Enum.sort()
        assert alert_2.alert_id == existing_alert.alert_id
        assert alert_1.alert_id |> String.to_integer() > alert_2.alert_id |> String.to_integer()
      end
    end

    test "uses the correct agency ID for the CapeFLYER" do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
        existing_alert = insert(:alert, alert_id: "0")

        alert_data = %{
          route_type: 2,
          description_text: "ok",
          header_text: "hello",
          effect_name: "Delay",
          route_ids: ["CapeFlyer"],
          direction: "default",
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end_specifier: :further_notice
        }

        result = AlertBuilder.build_alert(alert_data, :R)

        assert result == %{
                 effect: :SIGNIFICANT_DELAYS,
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
                 draft: false,
                 active_period: [%{start: ~U[2024-04-30 15:54:00Z], end: nil}],
                 active_period_end: nil,
                 active_period_start: ~U[2024-04-30 15:54:00Z],
                 duration_certainty: :UNKNOWN
               }

        result |> Alerts.create_or_update_alert()
        [alert_1, alert_2] = Alerts.list_all()
        assert alert_1.alert_id == existing_alert.alert_id
        assert alert_2.alert_id |> String.to_integer() > alert_1.alert_id |> String.to_integer()
      end
    end

    test "builds active period with end value later_today" do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
        alert_data =
          %{
            active_period_start: ~N[2024-04-30 11:54:00],
            active_period_end: nil,
            active_period_end_specifier: :later_today
          }
          |> Map.merge(@route_data)

        result = AlertBuilder.build_alert(alert_data, :R)

        assert result.active_period == [%{start: ~U[2024-04-30 15:54:00Z], end: nil}]
        assert result.active_period_start == ~U[2024-04-30 15:54:00Z]
        assert result.active_period_end == nil
        assert result.duration_certainty == :ESTIMATED
      end
    end

    test "builds active period with end value further_notice" do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
        alert_data =
          %{
            active_period_start: ~N[2024-04-30 11:54:00],
            active_period_end: nil,
            active_period_end_specifier: :further_notice
          }
          |> Map.merge(@route_data)

        result = AlertBuilder.build_alert(alert_data, :R)

        assert result.active_period == [%{start: ~U[2024-04-30 15:54:00Z], end: nil}]
        assert result.active_period_start == ~U[2024-04-30 15:54:00Z]
        assert result.active_period_end == nil
        assert result.duration_certainty == :UNKNOWN
      end
    end

    test "builds active period with end value pick" do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
        alert_data =
          %{
            active_period_start: ~N[2024-04-30 11:54:00],
            active_period_end: ~N[2024-04-30 23:54:00],
            active_period_end_specifier: :pick
          }
          |> Map.merge(@route_data)

        result = AlertBuilder.build_alert(alert_data, :R)

        assert result.active_period == [
                 %{start: ~U[2024-04-30 15:54:00Z], end: ~U[2024-05-01 03:54:00Z]}
               ]

        assert result.active_period_start == ~U[2024-04-30 15:54:00Z]
        assert result.active_period_end == ~U[2024-05-01 03:54:00Z]
        assert result.duration_certainty == :KNOWN
      end
    end

    test "builds active period with end value end_of_service_today when time is before midnight" do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
        alert_data =
          %{
            active_period_start: ~N[2024-04-30 11:54:00],
            active_period_end: nil,
            active_period_end_specifier: :end_of_service_today
          }
          |> Map.merge(@route_data)

        result = AlertBuilder.build_alert(alert_data, :R)

        assert result.active_period == [
                 %{start: ~U[2024-04-30 15:54:00Z], end: ~U[2024-05-01 06:30:00Z]}
               ]

        assert result.active_period_start == ~U[2024-04-30 15:54:00Z]
        assert result.active_period_end == ~U[2024-05-01 06:30:00Z]
        assert result.duration_certainty == :KNOWN
      end
    end

    test "builds active period with end value end_of_service_today when time is after midnight" do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
        alert_data =
          %{
            active_period_start: ~N[2024-04-30 01:54:00],
            active_period_end: nil,
            active_period_end_specifier: :end_of_service_today
          }
          |> Map.merge(@route_data)

        result = AlertBuilder.build_alert(alert_data, :R)

        assert result.active_period == [
                 %{start: ~U[2024-04-30 05:54:00Z], end: ~U[2024-04-30 06:30:00Z]}
               ]

        assert result.active_period_start == ~U[2024-04-30 05:54:00Z]
        assert result.active_period_end == ~U[2024-04-30 06:30:00Z]
        assert result.duration_certainty == :KNOWN
      end
    end

    test "properly builds RDS all-stops informed entity with 1 route" do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
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
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
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
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
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
        %Stop{id: "1", parent_id: "a", vehicle_type: 3},
        %Stop{id: "2", parent_id: "b", vehicle_type: 3},
        %Stop{id: "3", parent_id: "c", vehicle_type: 3}
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts ->
             [%APIRoutePattern{direction_id: 1, stops: child_stops}]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {RoutesRepo, [], [get: fn route_id -> %Route{id: route_id, type: 3} end]}
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
           by_route_id: fn _route_id, _opts ->
             [%APIRoutePattern{direction_id: 0, stops: parent_stops}]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> parent_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops end]},
        {RoutesRepo, [], [get: fn route_id -> %Route{id: route_id, type: 3} end]}
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
          parent_id: "place-WR-0067",
          vehicle_type: 2
        },
        %Stop{
          id: "WR-0075-01",
          parent_id: "place-WR-0075",
          vehicle_type: 2
        },
        # Intentional duplicate
        %Stop{
          id: "WR-0075-01",
          parent_id: "place-WR-0075",
          vehicle_type: 2
        }
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts ->
             [%APIRoutePattern{direction_id: 0, stops: child_stops}]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {RoutesRepo, [], [get: fn route_id -> %Route{id: route_id, type: 2} end]}
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
        %Stop{id: "alfcl-child", parent_id: "place-alfcl", vehicle_type: 1},
        %Stop{id: "davis-child-0", parent_id: "place-davis", vehicle_type: 1},
        %Stop{id: "portr-child-0", parent_id: "place-portr", vehicle_type: 1},
        %Stop{id: "harsq-child-0", parent_id: "place-harsq", vehicle_type: 1}
      ]

      child_stops_1 = [
        %Stop{id: "harsq-child-1", parent_id: "place-harsq", vehicle_type: 1},
        %Stop{id: "portr-child-1", parent_id: "place-portr", vehicle_type: 1},
        %Stop{id: "davis-child-1", parent_id: "place-davis", vehicle_type: 1},
        %Stop{id: "alfcl-child", parent_id: "place-alfcl", vehicle_type: 1}
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn "Red", [include: "representative_trip.stops"] ->
             [
               %APIRoutePattern{direction_id: 0, stops: child_stops_0},
               %APIRoutePattern{direction_id: 1, stops: child_stops_1}
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
        {RoutesRepo, [], [get: fn route_id -> %Route{id: route_id, type: 1} end]}
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
        %Stop{id: "1", parent_id: "a", vehicle_type: 3},
        %Stop{id: "2", parent_id: "b", vehicle_type: 3},
        %Stop{id: "3", parent_id: "c", vehicle_type: 3}
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts ->
             [%APIRoutePattern{direction_id: 1, stops: child_stops}]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {RoutesRepo, [], [get: fn route_id -> %{id: route_id, type: 3} end]}
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

    test "RDS informed entities expanding Green Line routes" do
      hynes = %Stop{id: "place-hymnl"}
      kenmore = %Stop{id: "place-kencl"}
      fenway = %Stop{id: "place-fenwy"}

      hynes_child = %Stop{id: "hynes-child", parent_id: hynes.id, vehicle_type: 1}
      kenmore_child = %Stop{id: "kenmore-child", parent_id: kenmore.id, vehicle_type: 1}
      fenway_child = %Stop{id: "fenway-child", parent_id: fenway.id, vehicle_type: 1}

      alert_data = %{
        route_type: 1,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        stop_ids: ["place-hymnl", "place-kencl", "place-fenwy"],
        route_ids: ["Green", "Green-D"],
        trip_ids: nil,
        direction: "1"
      }

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn
             "Green-B", _ ->
               [%APIRoutePattern{direction_id: 1, stops: [hynes_child, kenmore_child]}]

             "Green-C", _ ->
               [%APIRoutePattern{direction_id: 1, stops: [hynes_child, kenmore_child]}]

             "Green-D", _ ->
               [
                 %APIRoutePattern{
                   direction_id: 1,
                   stops: [hynes_child, kenmore_child, fenway_child]
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
        {RoutesRepo, [], [get: fn route_id -> %Route{id: route_id, type: 1} end]}
      ]) do
        result = AlertBuilder.build_alert(alert_data, :RDS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   direction_id: 1,
                   route_id: "Green-B",
                   route_type: 1,
                   agency_id: "1",
                   stop_id: "hynes-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "Green-B",
                   route_type: 1,
                   agency_id: "1",
                   direction_id: 1,
                   stop_id: "kenmore-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   direction_id: 1,
                   route_id: "Green-C",
                   route_type: 1,
                   agency_id: "1",
                   stop_id: "hynes-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   direction_id: 1,
                   route_id: "Green-C",
                   route_type: 1,
                   agency_id: "1",
                   stop_id: "kenmore-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   direction_id: 1,
                   route_id: "Green-D",
                   route_type: 1,
                   agency_id: "1",
                   stop_id: "hynes-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   direction_id: 1,
                   route_id: "Green-D",
                   route_type: 1,
                   agency_id: "1",
                   stop_id: "kenmore-child"
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   direction_id: 1,
                   route_id: "Green-D",
                   route_type: 1,
                   agency_id: "1",
                   stop_id: "fenway-child"
                 }
               ]
      end
    end

    test "properly builds R informed entity" do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
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
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
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
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
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
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
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
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
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
        %Stop{id: "a", vehicle_type: 3},
        %Stop{id: "b", vehicle_type: 3},
        %Stop{id: "c", vehicle_type: 3}
      ]

      child_stops = [
        %Stop{id: "1", parent_id: "a", vehicle_type: 3},
        %Stop{id: "2", parent_id: "b", vehicle_type: 3},
        %Stop{id: "3", parent_id: "c", vehicle_type: 3}
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts ->
             [%APIRoutePattern{direction_id: 1, stops: child_stops}]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {RoutesRepo, [], [get: fn route_id -> %Route{id: route_id, type: 3} end]}
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
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
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
          parent_id: "place-FR-0201",
          vehicle_type: 2
        },
        %Stop{
          id: "FR-0219-01",
          parent_id: "place-FR-0219",
          vehicle_type: 2
        },
        # Intentional duplicates
        %Stop{
          id: "FR-0201-01",
          parent_id: "place-FR-0201",
          vehicle_type: 2
        },
        %Stop{
          id: "FR-0219-01",
          parent_id: "place-FR-0219",
          vehicle_type: 2
        }
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts ->
             [%APIRoutePattern{direction_id: 0, stops: child_stops}]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {SchedulesRepo, [],
         [trip: fn "CR-627754-435" -> %Trip{id: "CR-627754-435", direction_id: 0} end]},
        {RoutesRepo, [], [get: fn route_id -> %Route{id: route_id, type: 2} end]}
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
           by_route_id: fn _route_id, _opts ->
             [%APIRoutePattern{direction_id: 0, stops: child_stops}]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {SchedulesRepo, [],
         [trip: fn "CR-627678-295" -> %Trip{id: "CR-627678-295", direction_id: 0} end]},
        {RoutesRepo, [], [get: fn route_id -> %Route{id: route_id, type: 2} end]}
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
           by_route_id: fn _route_id, _opts ->
             [%APIRoutePattern{direction_id: 0, stops: child_stops}]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {SchedulesRepo, [],
         [trip: fn "CR-627678-295" -> %Trip{id: "CR-627678-295", direction_id: 0} end]},
        {RoutesRepo, [], [get: fn route_id -> %Route{id: route_id, type: 2} end]}
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
        %Stop{id: "FR-0201-01", parent_id: "place-FR-0201", vehicle_type: 2},
        %Stop{id: "FR-0219-01", parent_id: "place-FR-0219", vehicle_type: 2}
      ]

      child_stops_1 = [
        %Stop{id: "FR-0219-02", parent_id: "place-FR-0219", vehicle_type: 2},
        %Stop{id: "FR-0201-02", parent_id: "place-FR-0201", vehicle_type: 2}
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn "CR-Fitchburg", [include: "representative_trip.stops"] ->
             [
               %APIRoutePattern{direction_id: 0, stops: child_stops_0},
               %APIRoutePattern{direction_id: 1, stops: child_stops_1}
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
        {RoutesRepo, [], [get: fn route_id -> %Route{id: route_id, type: 2} end]}
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
           by_route_id: fn _route_id, _opts ->
             [%APIRoutePattern{direction_id: 0, stops: child_stops}]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {RoutesRepo, [], [get: fn route_id -> %Route{id: route_id, type: 1} end]}
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
        draft: nil,
        header_text: "a",
        route_types_by_id: %{"Boat-F4" => 4}
      }

      parent_stops = [%Stop{id: "Boat-Charlestown"}]

      child_stops = []

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts ->
             [%APIRoutePattern{direction_id: 0, stops: child_stops}]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]}
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

      hynes_child = %Stop{id: "hynes-child", parent_id: "place-hymnl", vehicle_type: 0}
      kenmore_child = %Stop{id: "kenmore-child", parent_id: "place-kencl", vehicle_type: 0}
      fenway_child = %Stop{id: "fenway-child", parent_id: "place-fenwy", vehicle_type: 0}
      child_stops = [hynes_child, kenmore_child, fenway_child]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts ->
             [%APIRoutePattern{direction_id: 0, stops: child_stops}]
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
        {RoutesRepo, [], [get: fn route_id -> %Route{id: route_id, type: 0} end]}
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
        draft: nil,
        route_types_by_id: %{"CR-Kingston" => 2}
      }

      parent_stops = [%Stop{id: "place-PB-0194"}]

      child_stops = [
        %Stop{
          id: "PB-0194-S",
          parent_id: "place-PB-0194",
          vehicle_type: 2
        },
        # Intentional duplicate
        %Stop{
          id: "PB-0194-S",
          parent_id: "place-PB-0194",
          vehicle_type: 2
        }
      ]

      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts ->
             [%APIRoutePattern{direction_id: 0, stops: child_stops}]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> child_stops end
         ]},
        {StopsRepo, [], [by_route: fn _route_id, _direction -> parent_stops ++ child_stops end]},
        {RoutesRepo, [], [get: fn route_id -> %Route{id: route_id, type: 2} end]}
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
  end
end
