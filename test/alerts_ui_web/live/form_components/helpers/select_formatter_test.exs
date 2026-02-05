defmodule AlertsUIWeb.FormComponents.Helpers.SelectFormatterTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.FormComponents.Helpers.SelectFormatter
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Stop

  describe "formatted_select_options/1" do
    test "it returns properly formatted and ordered routes" do
      options = [
        %Route{id: "202", name: "joe", sort_order: 2},
        %Route{id: "303", name: "", long_name: "bob", sort_order: 3},
        %Route{id: "202", name: "joe", sort_order: 2},
        %Route{id: "101", name: "alice", sort_order: 1}
      ]

      results = SelectFormatter.formatted_select_options(%SelectFormatter{options: options})

      assert results == [
               [key: "alice", value: "101"],
               [key: "joe", value: "202"],
               [key: "bob", value: "303"]
             ]
    end

    test "stops have original order, tooltips" do
      options = [
        %Stop{id: "202", name: "joe"},
        %Stop{id: "303", name: "bob"},
        %Stop{id: "303", name: "bob"},
        %Stop{id: "101", name: "alice"}
      ]

      results = SelectFormatter.formatted_select_options(%SelectFormatter{options: options})

      assert results == [
               [id: "joe", key: "joe", value: "202", "phx-hook": "Tippy", "data-tippy-content": "Stop ID 202"],
               [id: "bob", key: "bob", value: "303", "phx-hook": "Tippy", "data-tippy-content": "Stop ID 303"],
               [id: "alice", key: "alice", value: "101", "phx-hook": "Tippy", "data-tippy-content": "Stop ID 101"],
             ]
    end

    test "values will be combo of stop names and ids if second argument is true" do
      options = [
        %Stop{id: "202", name: "joe"},
        %Stop{id: "303", name: "bob"},
        %Stop{id: "303", name: "bob"},
        %Stop{id: "101", name: "alice"}
      ]

      results = SelectFormatter.formatted_select_options(%SelectFormatter{options: options}, true)


      assert results == [
               [id: "joe", key: "joe", value: "joe|202", "phx-hook": "Tippy", "data-tippy-content": "Stop ID 202"],
               [id: "bob", key: "bob", value: "bob|303", "phx-hook": "Tippy", "data-tippy-content": "Stop ID 303"],
               [id: "alice", key: "alice", value: "alice|101", "phx-hook": "Tippy", "data-tippy-content": "Stop ID 101"],
             ]
    end
  end

  describe "formatted_select_options/2" do
    test "it returns properly filtered options by name and value" do
      options = [
        %Facility{
          id: "952",
          type: "ELEVATOR",
          short_name: "Alewife platform to lobby",
          long_name: "Charles/MGH Elevator 952 (Alewife platform to lobby)"
        },
        %Facility{
          id: "951",
          type: "ELEVATOR",
          short_name: "Ashmont/Braintree platform to lobby"
        },
        %Facility{
          id: "861",
          type: "ELEVATOR",
          short_name: "Ashmont/Braintree platform to Massachusetts Avenue"
        },
        %Facility{
          id: "860",
          type: "ELEVATOR",
          short_name: "Alewife platform to Massachusetts Avenue",
          long_name: "Central Elevator 860 (Alewife platform to Massachusetts Avenue)"
        }
      ]

      results =
        SelectFormatter.formatted_select_options(%SelectFormatter{
          options: options,
          search_term: "Ashmont/Braintree"
        })

      assert results == [
               [key: "Ashmont/Braintree platform to lobby", value: "951"],
               [key: "Ashmont/Braintree platform to Massachusetts Avenue", value: "861"]
             ]

      results =
        SelectFormatter.formatted_select_options(%SelectFormatter{
          options: options,
          search_term: "951"
        })

      assert results == [
               [key: "Ashmont/Braintree platform to lobby", value: "951"],
             ]
    end
  end

  describe "formatted_trip_options/2" do
    test "it properly formats non-ferry trips" do
      trip_map = %{
        "Framingham/Worcester line" => [
          %EnhancedSchedule{
            route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
            trip: %Trip{id: "CR-683300-527", name: "527", direction_id: 0},
            stop: %Stop{id: "place-sstat", name: "South Station"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 14:01:00.00Z],
            use_trip_id_in_name?: true
          },
          %EnhancedSchedule{
            route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
            trip: %Trip{id: "CR-683300-special", name: "527", direction_id: 0},
            stop: %Stop{id: "place-sstat", name: "South Station"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 14:01:00.00Z],
            use_trip_id_in_name?: true
          },
          %EnhancedSchedule{
            route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
            trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
            stop: %Stop{id: "place-sstat", name: "South Station"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 14:15:00.00Z]
          },
          %EnhancedSchedule{
            route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
            trip: %Trip{id: "CR-683321-594", name: "594", direction_id: 1},
            stop: %Stop{id: "place-WML-0214", name: "Framingham"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 14:45:00.00Z]
          },
          %EnhancedSchedule{
            route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
            trip: %Trip{id: "CR-683302-529", name: "529", direction_id: 0},
            stop: %Stop{id: "place-sstat", name: "South Station"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 15:01:00.00Z]
          }
        ]
      }

      results =
        SelectFormatter.formatted_select_options(%SelectFormatter{
          schedules_by_route_name: trip_map,
          route_type: 2
        })

      assert results == [
               [key: "527 (9:01 AM from South Station) CR-683300-527", value: "CR-683300-527"],
               [key: "527 (9:01 AM from South Station) CR-683300-special", value: "CR-683300-special"],
               [key: "595 (9:15 AM from South Station)", value: "CR-683322-595"],
               [key: "594 (9:45 AM from Framingham)", value: "CR-683321-594"],
               [key: "529 (10:01 AM from South Station)", value: "CR-683302-529"]
             ]
    end

    test "it properly formats ferry trips" do
      trip_map = %{
        "Framingham/Worcester line" => [
          %EnhancedSchedule{
            route: %MBTAV3API.Routes.Route{
              id: "Boat-F4",
              type: 4,
              name: "Charlestown Ferry"
            },
            trip: %Trip{
              id: "Boat-F4-1430-Long-B-01-Weekday-Fall-24",
              name: ""
            },
            stop: %Stop{
              id: "Boat-Long-South",
              name: "Long Wharf (South)"
            },
            arrival_time: nil,
            departure_time: ~U[2024-02-21 15:01:00.00Z],
            last_stop_name: "Charlestown Navy Yard"
          }
        ]
      }

      results =
        SelectFormatter.formatted_select_options(%SelectFormatter{
          schedules_by_route_name: trip_map,
          route_type: 4
        })

      assert results == [
        [
          key: "10:01 AM from Long Wharf (South) to Charlestown Navy Yard",
          value: "Boat-F4-1430-Long-B-01-Weekday-Fall-24"
        ]
      ]
    end

    test "it properly formats nested trips" do
      trip_map = %{
        "Framingham/Worcester line" => [
          %EnhancedSchedule{
            route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
            trip: %Trip{id: "CR-683300-527", name: "527", direction_id: 0},
            stop: %Stop{id: "place-sstat", name: "South Station"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 14:01:00.00Z]
          },
          %EnhancedSchedule{
            route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
            trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
            stop: %Stop{id: "place-fram", name: "Framingham"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 14:15:00.00Z]
          }
        ],
        "Providence/Stoughton Line" => [
          %EnhancedSchedule{
            route: %Route{id: "CR-Providence", type: 2, name: "Providence/Stoughton Line"},
            trip: %Trip{id: "CR-687393-839", name: "839", direction_id: 0},
            stop: %Stop{id: "place-sstat", name: "South Station"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 16:03:00.00Z]
          },
          %EnhancedSchedule{
            route: %Route{id: "CR-Providence", type: 2, name: "Providence/Stoughton Line"},
            trip: %Trip{id: "CR-687395-841", name: "841", direction_id: 0},
            stop: %Stop{id: "place-forhl", name: "Forest Hills"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 16:15:00.00Z]
          }
        ]
      }

      results =
        SelectFormatter.formatted_select_options(%SelectFormatter{
          schedules_by_route_name: trip_map,
          route_type: 2
        })

      assert results == [
               {"Framingham/Worcester line",
                [
                  [key: "527 (9:01 AM from South Station)", value: "CR-683300-527"],
                  [key: "595 (9:15 AM from Framingham)", value: "CR-683322-595"]
                ]},
               {"Providence/Stoughton Line",
                [
                  [key: "839 (11:03 AM from South Station)", value: "CR-687393-839"],
                  [key: "841 (11:15 AM from Forest Hills)", value: "CR-687395-841"]
                ]}
             ]
    end

    test "it properly filters nested trips" do
      trip_map = %{
        "Framingham/Worcester line" => [
          %EnhancedSchedule{
            route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
            trip: %Trip{id: "CR-683300-527", name: "527", direction_id: 0},
            stop: %Stop{id: "place-sstat", name: "South Station"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 14:01:00.00Z]
          },
          %EnhancedSchedule{
            route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
            trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
            stop: %Stop{id: "place-fram", name: "Framingham"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 14:15:00.00Z]
          }
        ],
        "Providence/Stoughton Line" => [
          %EnhancedSchedule{
            route: %Route{id: "CR-Providence", type: 2, name: "Providence/Stoughton Line"},
            trip: %Trip{id: "CR-687393-839", name: "839", direction_id: 0},
            stop: %Stop{id: "place-sstat", name: "South Station"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 16:03:00.00Z]
          },
          %EnhancedSchedule{
            route: %Route{id: "CR-Providence", type: 2, name: "Providence/Stoughton Line"},
            trip: %Trip{id: "CR-687395-841", name: "841", direction_id: 0},
            stop: %Stop{id: "place-forhl", name: "Forest Hills"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 16:15:00.00Z]
          }
        ]
      }

      results =
        SelectFormatter.formatted_select_options(%SelectFormatter{
          schedules_by_route_name: trip_map,
          route_type: 2,
          search_term: "Forest"
        })

      assert results == [
               {"Framingham/Worcester line", []},
               {"Providence/Stoughton Line",
                [
                  [key: "841 (11:15 AM from Forest Hills)", value: "CR-687395-841"]
                ]}
             ]
    end
  end

  describe "formatted_direction_options/1" do
    test "it returns direction options if there are multiple routes" do
      results = SelectFormatter.formatted_direction_options(["1", "2"], %{})

      assert results == [
               Outbound: "0",
               Inbound: "1"
             ]
    end

    test "it returns correctly formatted direction options if only one route" do
      direction_map = %{
        "1" => %{0 => "Westbound", 1 => "Eastbound"},
        "2" => %{0 => "Northbound", 1 => "Southbound"}
      }

      results = SelectFormatter.formatted_direction_options(["1"], direction_map)

      assert results == [{"Westbound", "0"}, {"Eastbound", "1"}]
    end

    test "it returns empty list if direction is nil" do
      results = SelectFormatter.formatted_direction_options(nil, %{})

      assert results == []
    end
  end
end
