defmodule AlertsUIWeb.FormComponents.Helpers.AutoText.BuildDescriptionTextTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.FormComponents.Helpers.AutoText.BuildDescriptionText
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Stop

  @stop_1 %Stop{id: "place-lech", name: "Lechmere"}
  @stop_2 %Stop{id: "place-lngmd", name: "Longwood Medical Area"}

  @route_1 %Route{id: "1", name: "1", direction_names: %{0 => "Westbound", 1 => "Eastbound"}}
  @route_2 %Route{id: "22", name: "22"}

  @schedule_1 %EnhancedSchedule{
    route: @route_1,
    trip: %Trip{id: "CR-683300-527", name: "527", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    departure_time: ~U[2024-02-21 14:01:00.00Z]
  }

  @schedule_2 %EnhancedSchedule{
    route: @route_2,
    trip: %Trip{id: "CR-687395-841", name: "841", direction_id: 0},
    stop: %Stop{id: "place-forhl", name: "Forest Hills"},
    arrival_time: nil,
    departure_time: ~U[2024-02-21 16:15:00.00Z]
  }

  describe "affected_routes/1" do
    test "1 route ferry suspension" do
      autotext_data = %{
        routes: [@route_1],
        effect: "Suspension",
        route_type: 4
      }

      expected = "Suspended ferries:\n1"

      actual = BuildDescriptionText.affected_routes(autotext_data)
      assert expected == actual
    end

    test "2 routes bus" do
      autotext_data = %{
        routes: [@route_1, @route_2],
        effect: "Parking Closure",
        route_type: 3
      }

      expected = "Affected routes:\n1\n22"

      actual = BuildDescriptionText.affected_routes(autotext_data)
      assert expected == actual
    end
  end

  describe "affected_stops/1" do
    test "one stop ferry dock closure" do
      autotext_data = %{
        stops: [@stop_1],
        effect: "Dock Closure",
        route_type: 4
      }

      expected = "Closed docks:\nLechmere"

      actual = BuildDescriptionText.affected_stops(autotext_data)
      assert expected == actual
    end

    test "two stops CR detour" do
      autotext_data = %{
        stops: [@stop_1, @stop_2],
        effect: "Detour",
        route_type: 2
      }

      expected = "Skipped stations:\nLechmere\nLongwood Medical Area"

      actual = BuildDescriptionText.affected_stops(autotext_data)
      assert expected == actual
    end
  end

  describe "affected_trips/1" do
    test "trips with one route" do
      autotext_data = %{
        routes: [@route_1],
        schedules: [@schedule_1],
        effect: "Delay"
      }

      expected = "Delayed trips:\n527 (9:01 AM from South Station)"

      actual = BuildDescriptionText.affected_trips(autotext_data)
      assert expected == actual
    end
  end
end
