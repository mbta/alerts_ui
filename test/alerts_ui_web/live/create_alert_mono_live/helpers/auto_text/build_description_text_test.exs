defmodule AlertsUIWeb.CreateAlertLive.Helpers.AutoText.BuildDescriptionTextTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.CreateAlertLive.Helpers.AutoText.BuildDescriptionText
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Stop

  @stop_1 %Stop{id: "place-lech", name: "Lechmere"}
  @stop_2 %Stop{id: "place-lngmd", name: "Longwood Medical Area"}

  @stop_1_bus %Stop{id: "place-lech", name: "Lechmere (inbound)"}
  @stop_2_bus %Stop{id: "place-lngmd", name: "Longwood Medical Area (outbound)"}
  @stop_3_bus %Stop{id: "730", name: "Franklin St @ Sydney St"}

  @route_1 %Route{id: "1", name: "1", direction_names: %{0 => "Westbound", 1 => "Eastbound"}}
  @route_2 %Route{id: "22", name: "22"}

  @schedule_1 %EnhancedSchedule{
    route_id: @route_1.id,
    trip: %Trip{id: "CR-683300-527", name: "527", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    departure_time: ~U[2024-02-21 14:01:00.00Z],
    use_trip_id_in_name?: true
  }

  @schedule_2 %EnhancedSchedule{
    route_id: @route_2.id,
    trip: %Trip{id: "CR-687395-841", name: "841", direction_id: 1},
    stop: %Stop{id: "place-forhl", name: "Forest Hills"},
    arrival_time: nil,
    departure_time: ~U[2024-02-21 16:15:00.00Z],
    use_trip_id_in_name?: true
  }

  @schedule_3 %EnhancedSchedule{
    route_id: @route_1.id,
    trip: %Trip{id: "CR-683300-527", name: "528", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    departure_time: ~U[2024-02-21 14:01:00.00Z]
  }

  @schedule_4 %EnhancedSchedule{
    route_id: @route_2.id,
    trip: %Trip{id: "CR-687395-841", name: "841", direction_id: 0},
    stop: %Stop{id: "place-forhl", name: "Forest Hills"},
    arrival_time: nil,
    departure_time: ~U[2024-02-21 16:15:00.00Z]
  }

  @facility_with_service_text %Facility{
    id: "Facility-3",
    long_name: "Example Facility",
    stop: %Stop{id: "place-sstat", name: "South Station"},
    properties: [
      %{
        name: "alternate-service-text",
        value: "To access the Bowdoin platform or Bremen St lobby from the Wonderland platform..."
      },
      %{name: "excludes-stop", value: 70_047},
      %{name: "excludes-stop", value: 70_96},
      %{name: "excludes-stop", value: 70_97}
    ]
  }

  @facility_no_service_text %Facility{
    id: "Facility-7",
    long_name: "Example Facility Two",
    stop: %Stop{id: "place-aqucl", name: "Aquarium"},
    properties: [
      %{name: "excludes-stop", value: 70_047},
      %{name: "excludes-stop", value: 70_96},
      %{name: "excludes-stop", value: 70_97}
    ]
  }

  describe "affected_routes/1" do
    test "1 route ferry suspension" do
      autotext_data = %{
        routes: [@route_1],
        effect_name: "Suspension",
        route_type: 4
      }

      expected = "Suspended ferries:\n1"

      actual = BuildDescriptionText.affected_routes(autotext_data)
      assert expected == actual
    end

    test "2 routes bus" do
      autotext_data = %{
        routes: [@route_1, @route_2],
        effect_name: "Parking Closure",
        route_type: 3
      }

      expected = "Affected routes:\n1\n22"

      actual = BuildDescriptionText.affected_routes(autotext_data)
      assert expected == actual
    end

    test "routes are sorted correctly" do
      autotext_data = %{
        routes: [
          %Route{name: "Red", type: 1},
          %Route{name: "Orange", type: 1},
          %Route{name: "119", type: 3},
          %Route{name: "22", type: 3},
          %Route{name: "CT3", type: 3}
        ],
        effect_name: "Parking Closure",
        route_type: 3
      }

      expected = "Affected routes:\nOrange\nRed\nCT3\n22\n119"

      actual = BuildDescriptionText.affected_routes(autotext_data)
      assert expected == actual
    end
  end

  describe "affected_stops/1" do
    test "one stop ferry dock closure" do
      autotext_data = %{
        stops: [@stop_1],
        effect_name: "Dock Closure",
        route_type: 4
      }

      expected = "Closed docks:\nLechmere"

      actual = BuildDescriptionText.affected_stops(autotext_data)
      assert expected == actual
    end

    test "two stops CR detour" do
      autotext_data = %{
        stops: [@stop_1, @stop_2],
        effect_name: "Detour",
        route_type: 2
      }

      expected = "Skipped stations:\nLechmere\nLongwood Medical Area"

      actual = BuildDescriptionText.affected_stops(autotext_data)
      assert expected == actual
    end

    test "two stops bus delay" do
      autotext_data = %{
        stops: [@stop_1_bus, @stop_2_bus],
        effect_name: "Delay",
        route_type: 3
      }

      expected =
        "Affected outbound stops:\nLongwood Medical Area\n\nAffected inbound stops:\nLechmere"

      actual = BuildDescriptionText.affected_stops(autotext_data)
      assert expected == actual
    end

    test "three stops bus delay, one stop goes both directions" do
      autotext_data = %{
        stops: [@stop_1_bus, @stop_2_bus, @stop_3_bus],
        effect_name: "Delay",
        route_type: 3
      }

      expected =
        "Affected outbound stops:\nLongwood Medical Area\nFranklin St @ Sydney St\n\nAffected inbound stops:\nLechmere\nFranklin St @ Sydney St"

      actual = BuildDescriptionText.affected_stops(autotext_data)
      assert expected == actual
    end
  end

  describe "affected_trips/1" do
    test "trips with one route" do
      autotext_data = %{
        routes: [@route_1],
        schedules: [@schedule_1],
        effect_name: "Delay",
        route_type: 2
      }

      expected = "Delayed trips:\n527 (9:01 AM from South Station)"

      actual = BuildDescriptionText.affected_trips(autotext_data)
      assert expected == actual
    end

    test "trips with two routes" do
      autotext_data = %{
        routes: [@route_1, @route_2],
        schedules: [@schedule_1, @schedule_2],
        effect_name: "Delay",
        route_type: 2
      }

      expected =
        "Delayed westbound trips on 1:\n527 (9:01 AM from South Station)\n\nDelayed inbound trips on 22:\n841 (11:15 AM from Forest Hills)"

      actual = BuildDescriptionText.affected_trips(autotext_data)

      assert expected == actual
    end

    test "multiple trips with two routes" do
      autotext_data = %{
        routes: [@route_1, @route_2],
        schedules: [@schedule_1, @schedule_2, @schedule_3, @schedule_4],
        effect_name: "Delay",
        route_type: 2
      }

      expected =
        "Delayed westbound trips on 1:\n527 (9:01 AM from South Station)\n528 (9:01 AM from South Station)\n\nDelayed inbound trips on 22:\n841 (11:15 AM from Forest Hills)\n\nDelayed outbound trips on 22:\n841 (11:15 AM from Forest Hills)"

      actual = BuildDescriptionText.affected_trips(autotext_data)

      assert expected == actual
    end
  end

  describe "affected_direction/1" do
    test "when there's 1 route and direction" do
      autotext_data = %{
        routes: [@route_1],
        direction: [0]
      }

      expected = "Affected direction: westbound"
      actual = BuildDescriptionText.affected_direction(autotext_data)

      assert expected == actual
    end

    test "when there's 2 routes" do
      autotext_data = %{
        routes: [@route_1, @route_2],
        direction: [0]
      }

      assert BuildDescriptionText.affected_direction(autotext_data) == ""
    end
  end

  describe "affected_facilities/1" do
    test "when facilities is empty" do
      assert BuildDescriptionText.affected_facilities(%{facilities: []}) == ""
    end

    test "when facility has no alternate service text" do
      autotext_data = %{
        facilities: [@facility_no_service_text]
      }

      actual = BuildDescriptionText.affected_facilities(autotext_data)
      assert "" == actual
    end

    test "when facility has alternate service text" do
      autotext_data = %{
        facilities: [@facility_with_service_text]
      }

      expected =
        "To access the Bowdoin platform or Bremen St lobby from the Wonderland platform..."

      actual = BuildDescriptionText.affected_facilities(autotext_data)
      assert expected == actual
    end

    test "when there are multiple facilities" do
      autotext_data = %{
        facilities: [
          @facility_with_service_text,
          @facility_no_service_text,
          @facility_with_service_text
        ]
      }

      expected =
        "To access the Bowdoin platform or Bremen St lobby from the Wonderland platform...\n\nTo access the Bowdoin platform or Bremen St lobby from the Wonderland platform..."

      actual = BuildDescriptionText.affected_facilities(autotext_data)
      assert expected == actual
    end
  end
end
