defmodule AlertsUIWeb.CreateAlertLive.Helpers.SelectFormatterTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.CreateAlertLive.Helpers.SelectFormatter
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Stop

  describe "formatted_select_options/2" do
    test "returns properly formatted and ordered routes" do
      options = [
        %Route{id: "202", name: "joe", sort_order: 2},
        %Route{id: "303", name: "", long_name: "bob", sort_order: 3},
        %Route{id: "202", name: "joe", sort_order: 2},
        %Route{id: "101", name: "alice", sort_order: 1}
      ]

      results = SelectFormatter.formatted_select_options(%SelectFormatter{options: options})

      assert results == [
               [key: "alice", value: "101", id: "option-101"],
               [key: "joe", value: "202", id: "option-202"],
               [key: "bob", value: "303", id: "option-303"]
             ]
    end

    test "falls back to long_name when name is nil" do
      results =
        SelectFormatter.formatted_select_options(%SelectFormatter{
          options: [%Route{id: "1", name: nil, long_name: "Long Name", sort_order: 1}]
        })

      assert results == [[key: "Long Name", value: "1", id: "option-1"]]
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
               [
                 key: "joe",
                 value: "202",
                 id: "option-202",
                 title: "Stop ID 202"
               ],
               [
                 key: "bob",
                 value: "303",
                 id: "option-303",
                 title: "Stop ID 303"
               ],
               [
                 key: "alice",
                 value: "101",
                 id: "option-101",
                 title: "Stop ID 101"
               ]
             ]
    end

    test "values will be combo of stop names and ids if second argument is true" do
      options = [
        %Stop{id: "202", name: "joe"},
        %Stop{id: "303", name: "bob"},
        %Stop{id: "303", name: "bob"},
        %Stop{id: "101", name: "alice"}
      ]

      results =
        SelectFormatter.formatted_select_options(%SelectFormatter{options: options}, true)

      assert results == [
               [
                 key: "joe",
                 value: "joe|202",
                 id: "option-joe|202",
                 title: "Stop ID 202"
               ],
               [
                 key: "bob",
                 value: "bob|303",
                 id: "option-bob|303",
                 title: "Stop ID 303"
               ],
               [
                 key: "alice",
                 value: "alice|101",
                 id: "option-alice|101",
                 title: "Stop ID 101"
               ]
             ]
    end

    test "it returns properly filtered facility options by name and value" do
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

      by_name =
        SelectFormatter.formatted_select_options(%SelectFormatter{
          options: options,
          search_term: "Ashmont/Braintree"
        })

      assert by_name == [
               [
                 key: "Ashmont/Braintree platform to lobby",
                 value: "951",
                 id: "option-951"
               ],
               [
                 key: "Ashmont/Braintree platform to Massachusetts Avenue",
                 value: "861",
                 id: "option-861"
               ]
             ]

      by_value =
        SelectFormatter.formatted_select_options(%SelectFormatter{
          options: options,
          search_term: "951"
        })

      assert by_value == [
               [
                 key: "Ashmont/Braintree platform to lobby",
                 value: "951",
                 id: "option-951"
               ]
             ]
    end

    test "it properly formats non-ferry trips" do
      trip_map = %{
        "Framingham/Worcester line" => [
          %EnhancedSchedule{
            route_id: "CR-Worcester",
            trip: %Trip{id: "CR-683300-527", name: "527", direction_id: 0},
            stop: %Stop{id: "place-sstat", name: "South Station"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 14:01:00.00Z],
            use_trip_id_in_name?: true
          },
          %EnhancedSchedule{
            route_id: "CR-Worcester",
            trip: %Trip{id: "CR-683300-special", name: "527", direction_id: 0},
            stop: %Stop{id: "place-sstat", name: "South Station"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 14:01:00.00Z],
            use_trip_id_in_name?: true
          },
          %EnhancedSchedule{
            route_id: "CR-Worcester",
            trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
            stop: %Stop{id: "place-sstat", name: "South Station"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 14:15:00.00Z]
          },
          %EnhancedSchedule{
            route_id: "CR-Worcester",
            trip: %Trip{id: "CR-683321-594", name: "594", direction_id: 1},
            stop: %Stop{id: "place-WML-0214", name: "Framingham"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 14:45:00.00Z]
          },
          %EnhancedSchedule{
            route_id: "CR-Worcester",
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
               [
                 key: "527 (9:01 AM from South Station) CR-683300-527",
                 value: "CR-683300-527",
                 id: "option-CR-683300-527",
                 title: "Trip ID CR-683300-527"
               ],
               [
                 key: "527 (9:01 AM from South Station) CR-683300-special",
                 value: "CR-683300-special",
                 id: "option-CR-683300-special",
                 title: "Trip ID CR-683300-special"
               ],
               [
                 key: "595 (9:15 AM from South Station)",
                 value: "CR-683322-595",
                 id: "option-CR-683322-595",
                 title: "Trip ID CR-683322-595"
               ],
               [
                 key: "594 (9:45 AM from Framingham)",
                 value: "CR-683321-594",
                 id: "option-CR-683321-594",
                 title: "Trip ID CR-683321-594"
               ],
               [
                 key: "529 (10:01 AM from South Station)",
                 value: "CR-683302-529",
                 id: "option-CR-683302-529",
                 title: "Trip ID CR-683302-529"
               ]
             ]
    end

    test "single-route ferry trip uses last_stop_name in the name" do
      trip_map = %{
        "Charlestown Ferry" => [
          %EnhancedSchedule{
            route_id: "Boat-F4",
            trip: %Trip{id: "Boat-F4-1430-Long-B-01-Weekday-Fall-24", name: ""},
            stop: %Stop{id: "Boat-Long-South", name: "Long Wharf (South)"},
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
                 value: "Boat-F4-1430-Long-B-01-Weekday-Fall-24",
                 id: "option-Boat-F4-1430-Long-B-01-Weekday-Fall-24",
                 title: "Trip ID Boat-F4-1430-Long-\nB-01-Weekday-Fall-24"
               ]
             ]
    end

    test "it properly formats nested trips" do
      trip_map = %{
        "Framingham/Worcester line" => [
          %EnhancedSchedule{
            route_id: "CR-Worcester",
            trip: %Trip{id: "CR-683300-527", name: "527", direction_id: 0},
            stop: %Stop{id: "place-sstat", name: "South Station"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 14:01:00.00Z]
          }
        ],
        "Providence/Stoughton Line" => [
          %EnhancedSchedule{
            route_id: "CR-Providence",
            trip: %Trip{id: "CR-687393-839", name: "839", direction_id: 0},
            stop: %Stop{id: "place-sstat", name: "South Station"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 16:03:00.00Z]
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
                  [
                    key: "527 (9:01 AM from South Station)",
                    value: "CR-683300-527",
                    id: "option-CR-683300-527",
                    title: "Trip ID CR-683300-527"
                  ]
                ]},
               {"Providence/Stoughton Line",
                [
                  [
                    key: "839 (11:03 AM from South Station)",
                    value: "CR-687393-839",
                    id: "option-CR-687393-839",
                    title: "Trip ID CR-687393-839"
                  ]
                ]}
             ]
    end

    test "search filters within each nested group, preserving the group entries" do
      trip_map = %{
        "Framingham/Worcester line" => [
          %EnhancedSchedule{
            route_id: "CR-Worcester",
            trip: %Trip{id: "CR-683300-527", name: "527", direction_id: 0},
            stop: %Stop{id: "place-sstat", name: "South Station"},
            arrival_time: nil,
            departure_time: ~U[2024-02-21 14:01:00.00Z]
          }
        ],
        "Providence/Stoughton Line" => [
          %EnhancedSchedule{
            route_id: "CR-Providence",
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
                  [
                    key: "841 (11:15 AM from Forest Hills)",
                    value: "CR-687395-841",
                    id: "option-CR-687395-841",
                    title: "Trip ID CR-687395-841"
                  ]
                ]}
             ]
    end
  end

  describe "apply_search/3" do
    test "returns the original options when search term is nil" do
      opts = [[key: "alice", value: "1"]]

      assert SelectFormatter.apply_search(opts, nil, []) == opts
    end

    test "returns the original options when search term is empty string" do
      opts = [[key: "alice", value: "1"]]

      assert SelectFormatter.apply_search(opts, "", []) == opts
    end

    test "keeps options listed in values_to_keep even if they don't match" do
      opts = [
        [key: "alice", value: "1"],
        [key: "bob", value: "2"]
      ]

      assert SelectFormatter.apply_search(opts, "zzz", ["2"]) == [[key: "bob", value: "2"]]
    end
  end

  describe "sort_order/1" do
    test "returns the sort_order for a Route" do
      assert SelectFormatter.sort_order(%Route{sort_order: 42}) == 42
    end

    test "returns nil for stops, schedules, and facilities (preserve original order)" do
      assert SelectFormatter.sort_order(%Stop{}) == nil
      assert SelectFormatter.sort_order(%EnhancedSchedule{}) == nil
      assert SelectFormatter.sort_order(%Facility{}) == nil
    end

    test "returns nil for unknown shapes" do
      assert SelectFormatter.sort_order("anything") == nil
    end
  end

  describe "name_for_option/2" do
    test "returns the stop name for a Stop" do
      assert SelectFormatter.name_for_option(%Stop{name: "Park Street"}, 1) == "Park Street"
    end

    test "returns the long_name for a Route with empty name" do
      assert SelectFormatter.name_for_option(%Route{name: "", long_name: "Long"}, 1) == "Long"
      assert SelectFormatter.name_for_option(%Route{name: nil, long_name: "Long"}, 1) == "Long"
    end

    test "returns the name for a Route with a non-empty name" do
      assert SelectFormatter.name_for_option(%Route{name: "Red"}, 1) == "Red"
    end

    test "returns the short_name for a Facility with nil long_name" do
      assert SelectFormatter.name_for_option(%Facility{long_name: nil, short_name: "Short"}, 1) ==
               "Short"
    end

    test "returns the long_name for a Facility with a long_name" do
      assert SelectFormatter.name_for_option(%Facility{long_name: "Long"}, 1) == "Long"
    end

    test "returns the {name, _} tuple's name when no route_type is given" do
      assert SelectFormatter.name_for_option({"foo", "bar"}, nil) == "foo"
    end

    test "returns an empty string for an unknown shape when route_type is nil" do
      assert SelectFormatter.name_for_option(:weird, nil) == ""
    end
  end

  describe "id_for_option/2" do
    test "returns the Stop id when split_stops? is false" do
      assert SelectFormatter.id_for_option(%Stop{id: "1", name: "Park"}, false) == "1"
    end

    test "returns name|id when split_stops? is true for a Stop" do
      assert SelectFormatter.id_for_option(%Stop{id: "1", name: "Park"}, true) == "Park|1"
    end

    test "returns the id for a Route" do
      assert SelectFormatter.id_for_option(%Route{id: "Red"}, false) == "Red"
    end

    test "returns the id for a Facility" do
      assert SelectFormatter.id_for_option(%Facility{id: "fac-1"}, false) == "fac-1"
    end

    test "returns the trip id for an EnhancedSchedule" do
      assert SelectFormatter.id_for_option(
               %EnhancedSchedule{trip: %Trip{id: "trip-1"}},
               false
             ) == "trip-1"
    end

    test "stringifies the second element of a 2-tuple option" do
      assert SelectFormatter.id_for_option({"key", 5}, false) == "5"
    end
  end

  describe "formatted_direction_options/2" do
    test "returns the default Outbound/Inbound options for multiple routes" do
      assert SelectFormatter.formatted_direction_options(["1", "2"], %{}) ==
               [Outbound: "0", Inbound: "1"]
    end

    test "returns route-specific direction names when only one route is selected" do
      direction_map = %{
        "1" => %{0 => "Westbound", 1 => "Eastbound"}
      }

      assert SelectFormatter.formatted_direction_options(["1"], direction_map) ==
               [{"Westbound", "0"}, {"Eastbound", "1"}]
    end

    test "falls back to Outbound/Inbound when single route has no direction names" do
      assert SelectFormatter.formatted_direction_options(["unknown"], %{}) ==
               [Outbound: "0", Inbound: "1"]
    end

    test "returns an empty list when no routes are provided" do
      assert SelectFormatter.formatted_direction_options(nil, %{}) == []
    end
  end
end
