defmodule AlertsUI.AlertBuilderTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  import Mock
  alias AlertsUI.AlertBuilder
  alias AlertsUI.Alerts
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.RoutePatterns.RoutePattern, as: APIRoutePattern
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

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
          direction: "default"
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
                 draft: false
               }

        result |> Alerts.create_alert()
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
          direction: "default"
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
                 draft: false
               }

        result |> Alerts.create_alert()
        [alert_1, alert_2] = Alerts.list_all()
        assert alert_1.alert_id == existing_alert.alert_id
        assert alert_2.alert_id |> String.to_integer() > alert_1.alert_id |> String.to_integer()
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
          direction: "default"
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
                 draft: false
               }

        result |> Alerts.create_alert()
        [alert_1, alert_2] = Alerts.list_all()
        assert alert_1.alert_id == existing_alert.alert_id
        assert alert_2.alert_id |> String.to_integer() > alert_1.alert_id |> String.to_integer()
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
        %Stop{id: "1", parent_id: "a"},
        %Stop{id: "2", parent_id: "b"},
        %Stop{id: "3", parent_id: "c"}
      ]

      with_mock(RoutePatternsRepo,
        by_route_id: fn _route_id, _opts ->
          [%APIRoutePattern{direction_id: 1, stops: child_stops}]
        end,
        included_stops_by_route_id: fn _route_id, _direction -> child_stops end
      ) do
        with_mock(StopsRepo,
          by_route: fn _route_id, _direction -> parent_stops ++ child_stops end
        ) do
          result = AlertBuilder.build_alert(alert_data, :RDS)

          assert result.informed_entity == [
                   # Includes parent stops…
                   %{
                     direction_id: 1,
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     activities: [:BOARD, :RIDE],
                     stop_id: "a"
                   },
                   # …as well as child stops
                   %{
                     activities: [:BOARD, :RIDE],
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     direction_id: 1,
                     stop_id: "1"
                   },
                   %{
                     direction_id: 1,
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     activities: [:BOARD, :EXIT, :RIDE],
                     stop_id: "b"
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
                     direction_id: 1,
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     activities: [:EXIT, :RIDE],
                     stop_id: "c"
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

      with_mock(RoutePatternsRepo,
        by_route_id: fn _route_id, _opts ->
          [%APIRoutePattern{direction_id: 0, stops: parent_stops}]
        end,
        included_stops_by_route_id: fn _route_id, _direction -> parent_stops end
      ) do
        with_mock(StopsRepo,
          by_route: fn _route_id, _direction -> parent_stops end
        ) do
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
    end

    test "RDS informed entity with both directions combines child activities in parent" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Shuttle",
        stop_ids: ["a", "b", "c"],
        route_ids: ["57"],
        trip_ids: nil,
        direction: "default"
      }

      parent_stops = [%Stop{id: "a"}, %Stop{id: "b"}, %Stop{id: "c"}]

      child_stops = [
        %Stop{id: "1", parent_id: "a"},
        %Stop{id: "2", parent_id: "b"},
        %Stop{id: "3", parent_id: "c"}
      ]

      with_mock(RoutePatternsRepo,
        by_route_id: fn _route_id, _opts ->
          [
            %APIRoutePattern{direction_id: 0, stops: child_stops},
            %APIRoutePattern{direction_id: 1, stops: Enum.reverse(child_stops)}
          ]
        end,
        included_stops_by_route_id: fn _route_id, _direction -> child_stops end
      ) do
        with_mock(StopsRepo,
          by_route: fn _route_id, _direction -> parent_stops ++ child_stops end
        ) do
          result = AlertBuilder.build_alert(alert_data, :RDS)

          assert result.informed_entity == [
                   # Parent stop includes the combined activities of all children
                   %{
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     activities: [:BOARD, :RIDE, :EXIT],
                     stop_id: "a"
                   },
                   # Child stops listed per-direction
                   %{
                     activities: [:BOARD, :RIDE],
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     direction_id: 0,
                     stop_id: "1"
                   },
                   %{
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     activities: [:EXIT, :RIDE],
                     direction_id: 1,
                     stop_id: "1"
                   },
                   %{
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     activities: [:BOARD, :EXIT, :RIDE],
                     stop_id: "b"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     direction_id: 0,
                     stop_id: "2"
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
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     activities: [:EXIT, :RIDE, :BOARD],
                     stop_id: "c"
                   },
                   %{
                     activities: [:EXIT, :RIDE],
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     direction_id: 0,
                     stop_id: "3"
                   },
                   %{
                     activities: [:BOARD, :RIDE],
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     direction_id: 1,
                     stop_id: "3"
                   }
                 ]
        end
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

      with_mock(RoutePatternsRepo,
        by_route_id: fn _route_id, _opts ->
          [%APIRoutePattern{direction_id: 1, stops: child_stops}]
        end,
        included_stops_by_route_id: fn _route_id, _direction -> child_stops end
      ) do
        with_mock(StopsRepo,
          by_route: fn _route_id, _direction -> parent_stops ++ child_stops end
        ) do
          result = AlertBuilder.build_alert(alert_data, :RDS)

          assert result.informed_entity == [
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     direction_id: 1,
                     stop_id: "a"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "58",
                     route_type: 3,
                     agency_id: "1",
                     direction_id: 1,
                     stop_id: "a"
                   },
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
                     route_id: "58",
                     route_type: 3,
                     agency_id: "1",
                     stop_id: "1"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     direction_id: 1,
                     stop_id: "b"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "58",
                     route_type: 3,
                     agency_id: "1",
                     direction_id: 1,
                     stop_id: "b"
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
                     stop_id: "2"
                   }
                 ]
        end
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
        route_ids: ["Green", "Green-D"],
        trip_ids: nil,
        direction: "1"
      }

      with_mock(RoutePatternsRepo,
        by_route_id: fn
          "Green-B", _ ->
            [%APIRoutePattern{direction_id: 1, stops: [hynes_child, kenmore_child]}]

          "Green-C", _ ->
            [%APIRoutePattern{direction_id: 1, stops: [hynes_child, kenmore_child]}]

          "Green-D", _ ->
            [%APIRoutePattern{direction_id: 1, stops: [hynes_child, kenmore_child, fenway_child]}]

          "Green-E", _ ->
            []
        end,
        included_stops_by_route_id: fn _route_id, _direction ->
          [hynes_child, kenmore_child, fenway_child]
        end
      ) do
        with_mock(StopsRepo,
          by_route: fn
            "Green-B", _ -> [hynes, kenmore]
            "Green-C", _ -> [hynes, kenmore]
            "Green-D", _ -> [hynes, kenmore, fenway]
            "Green-E", _ -> []
          end
        ) do
          result = AlertBuilder.build_alert(alert_data, :RDS)

          assert result.informed_entity == [
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     direction_id: 1,
                     route_id: "Green-D",
                     route_type: 1,
                     agency_id: "1",
                     stop_id: "place-fenwy"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     direction_id: 1,
                     route_id: "Green-D",
                     route_type: 1,
                     agency_id: "1",
                     stop_id: "fenway-child"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "Green-B",
                     route_type: 1,
                     agency_id: "1",
                     direction_id: 1,
                     stop_id: "place-hymnl"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "Green-C",
                     route_type: 1,
                     agency_id: "1",
                     direction_id: 1,
                     stop_id: "place-hymnl"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "Green-D",
                     route_type: 1,
                     agency_id: "1",
                     direction_id: 1,
                     stop_id: "place-hymnl"
                   },
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
                     direction_id: 1,
                     route_id: "Green-C",
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
                     stop_id: "hynes-child"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "Green-B",
                     route_type: 1,
                     agency_id: "1",
                     direction_id: 1,
                     stop_id: "place-kencl"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "Green-C",
                     route_type: 1,
                     agency_id: "1",
                     direction_id: 1,
                     stop_id: "place-kencl"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "Green-D",
                     route_type: 1,
                     agency_id: "1",
                     direction_id: 1,
                     stop_id: "place-kencl"
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
                     stop_id: "kenmore-child"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     direction_id: 1,
                     route_id: "Green-D",
                     route_type: 1,
                     agency_id: "1",
                     stop_id: "kenmore-child"
                   }
                 ]
        end
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

      parent_stops = [%Stop{id: "a"}, %Stop{id: "b"}, %Stop{id: "c"}]

      child_stops = [
        %Stop{id: "1", parent_id: "a"},
        %Stop{id: "2", parent_id: "b"},
        %Stop{id: "3", parent_id: "c"}
      ]

      with_mock(RoutePatternsRepo,
        by_route_id: fn _route_id, _opts ->
          [%APIRoutePattern{direction_id: 1, stops: child_stops}]
        end,
        included_stops_by_route_id: fn _route_id, _direction -> child_stops end
      ) do
        with_mock(StopsRepo,
          by_route: fn _route_id, _direction -> parent_stops ++ child_stops end
        ) do
          result = AlertBuilder.build_alert(alert_data, :RDTS)

          assert result.informed_entity == [
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     direction_id: 0,
                     stop_id: "a"
                   },
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
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     direction_id: 0,
                     stop_id: "b"
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
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     direction_id: 0,
                     stop_id: "c"
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
        stop_ids: ["a", "b"],
        direction: "default"
      }

      with_mock(RoutePatternsRepo,
        by_route_id: fn _route_id, _opts -> [] end,
        included_stops_by_route_id: fn _route_id, _direction -> [] end
      ) do
        result = AlertBuilder.build_alert(alert_data, :RDTS)

        assert result.informed_entity == [
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   stop_id: "a",
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
                   stop_id: "a",
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
                   stop_id: "a",
                   trip: %{
                     trip_id: "456",
                     route_id: "57",
                     direction_id: 0
                   }
                 },
                 %{
                   activities: [:BOARD, :EXIT, :RIDE],
                   route_id: "57",
                   route_type: 3,
                   agency_id: "1",
                   stop_id: "b",
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
                   stop_id: "b",
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
                   stop_id: "b",
                   trip: %{
                     trip_id: "456",
                     route_id: "57",
                     direction_id: 0
                   }
                 }
               ]
      end
    end

    test "SR informed entity routes and stops includes route type" do
      with_mock(StopsRepo,
        by_route: fn _route_id, _direction -> [%Stop{id: "a"}, %Stop{id: "b"}] end
      ) do
        with_mock(RoutePatternsRepo,
          by_route_id: fn _route_id, _opts -> [] end,
          included_stops_by_route_id: fn _route_id, _direction -> [] end
        ) do
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

          result = AlertBuilder.build_alert(alert_data, :SR)

          assert result.informed_entity == [
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "56",
                     route_type: 1,
                     agency_id: "1",
                     stop_id: "a"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     stop_id: "a"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "58",
                     route_type: 1,
                     agency_id: "1",
                     stop_id: "a"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "56",
                     route_type: 1,
                     agency_id: "1",
                     stop_id: "b"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "57",
                     route_type: 3,
                     agency_id: "1",
                     stop_id: "b"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "58",
                     route_type: 1,
                     agency_id: "1",
                     stop_id: "b"
                   }
                 ]
        end
      end
    end

    test "SR informed entity expanding Green Line routes" do
      hynes = %Stop{id: "place-hymnl"}
      kenmore = %Stop{id: "place-kencl"}
      fenway = %Stop{id: "place-fenwy"}

      with_mock(StopsRepo,
        by_route: fn
          "Green-B", 0 -> [hynes, kenmore]
          "Green-B", 1 -> [hynes, kenmore]
          "Green-C", 0 -> [hynes, kenmore]
          "Green-C", 1 -> [hynes, kenmore]
          "Green-D", 0 -> [hynes, kenmore, fenway]
          "Green-D", 1 -> [hynes, kenmore, fenway]
          "Green-E", 0 -> []
          "Green-E", 1 -> []
        end
      ) do
        with_mock(RoutePatternsRepo,
          by_route_id: fn _route_id, _opts -> [] end,
          included_stops_by_route_id: fn _route_id, _direction -> [] end
        ) do
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

          result = AlertBuilder.build_alert(alert_data, :SR)

          assert result.informed_entity == [
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "Green-B",
                     route_type: 0,
                     agency_id: "1",
                     stop_id: "place-hymnl"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "Green-C",
                     route_type: 0,
                     agency_id: "1",
                     stop_id: "place-hymnl"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "Green-D",
                     route_type: 0,
                     agency_id: "1",
                     stop_id: "place-hymnl"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "Green-B",
                     route_type: 0,
                     agency_id: "1",
                     stop_id: "place-kencl"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "Green-C",
                     route_type: 0,
                     agency_id: "1",
                     stop_id: "place-kencl"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "Green-D",
                     route_type: 0,
                     agency_id: "1",
                     stop_id: "place-kencl"
                   },
                   %{
                     activities: [:BOARD, :EXIT, :RIDE],
                     route_id: "Green-D",
                     route_type: 0,
                     agency_id: "1",
                     stop_id: "place-fenwy"
                   }
                 ]
        end
      end
    end
  end
end
