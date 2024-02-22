defmodule AlertsUIWeb.FormComponents.Helpers.SelectFormatterTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUIWeb.FormComponents.Helpers.SelectFormatter

  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.{Schedule, Trip}
  alias MBTAV3API.Stops.Stop

  describe "formatted_select_options/1" do
    test "it returns properly formatted and ordered routes" do
      objects = [
        %Route{id: "202", name: "joe", sort_order: 2},
        %Route{id: "303", name: "", long_name: "bob", sort_order: 3},
        %Route{id: "101", name: "alice", sort_order: 1}
      ]

      results = SelectFormatter.formatted_select_options(objects)

      assert results == [
               {"alice", "101"},
               {"joe", "202"},
               {"bob", "303"}
             ]
    end

    test "it keeps original order for stops" do
      objects = [
        %Stop{id: "202", name: "joe"},
        %Stop{id: "303", name: "bob"},
        %Stop{id: "101", name: "alice"}
      ]

      results = SelectFormatter.formatted_select_options(objects)

      assert results == [
               {"joe", "202"},
               {"bob", "303"},
               {"alice", "101"}
             ]
    end
  end

  describe "formatted_trip_options/1" do
    test "it properly formats trips" do
      objects = [
        %Schedule{
          trip: %Trip{id: "202", name: "joe", direction_id: 0},
          stop: %Stop{id: "2022", name: "cool"},
          route: %Route{id: "b"},
          departure_time: ~U[2024-02-20 14:01:00.00Z]
        },
        %Schedule{
          trip: %Trip{id: "303", name: "bob", direction_id: 0},
          stop: %Stop{id: "3033", name: "bobb"},
          route: %Route{id: "c"},
          departure_time: ~U[2024-02-21 14:01:00.00Z]
        },
        %Schedule{
          trip: %Trip{id: "101", name: "alice", direction_id: 0},
          stop: %Stop{id: "1011", name: "shmalice"},
          route: %Route{id: "a"},
          departure_time: ~U[2024-02-22 14:01:00.00Z]
        }
      ]

      results = SelectFormatter.formatted_select_options(objects)

      assert results == [
               {"joe (9:01 AM from cool)", "b,202,0"},
               {"bob (9:01 AM from bobb)", "c,303,0"},
               {"alice (9:01 AM from shmalice)", "a,101,0"}
             ]
    end
  end

  describe "formatted_direction_options/1" do
    test "it returns direction options" do
      results = SelectFormatter.formatted_direction_options(["1"])

      assert results == [
               Outbound: "0",
               Inbound: "1"
             ]
    end
  end
end
