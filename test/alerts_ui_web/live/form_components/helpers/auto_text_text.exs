defmodule AlertsUIWeb.FormComponents.Helpers.AutoTextTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.FormComponents.Helpers.AutoText
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Stop

  @stop_1 %Stop{id: "place-lech", name: "Lechmere"}
  @stop_2 %Stop{id: "place-lngmd", name: "Longwood Medical Area"}
  @stop_3 %Stop{id: "place-masta", name: "Massachusetts Avenue"}
  @stop_4 %Stop{id: "place-matt", name: "Mattapan"}

  @schedule_1 %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683300-527", name: "527", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    departure_time: ~U[2024-02-21 14:01:00.00Z]
  }

  @schedule_2 %EnhancedSchedule{
    route: %Route{id: "CR-Providence", type: 2, name: "Providence/Stoughton Line"},
    trip: %Trip{id: "CR-687395-841", name: "841", direction_id: 0},
    stop: %Stop{id: "place-forhl", name: "Forest Hills"},
    arrival_time: nil,
    departure_time: ~U[2024-02-21 16:15:00.00Z]
  }

  @schedule_3 %EnhancedSchedule{
    route: %Route{id: "CR-Providence", type: 2, name: "Providence/Stoughton Line"},
    trip: %Trip{id: "CR-687393-839", name: "839", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    departure_time: ~U[2024-02-21 16:03:00.00Z]
  }

  @facility %Facility{
    id: "952",
    type: "ELEVATOR",
    short_name: "Alewife platform to lobby",
    long_name: "Charles/MGH Elevator 952 (Alewife platform to lobby)"
  }

  describe "build_header_auto_text/1" do
  end

  describe "build_description_auto_text/1" do
  end

  describe "cause/1" do
    test "when cause is empty" do
      assert AutoText.cause("") == ""
    end

    test "definite article" do
      expected = "the holiday"
      actual = AutoText.cause("HOLIDAY")
      assert expected == actual
    end

    test "indefinite article with vowel" do
      expected = "an unruly passenger"
      actual = AutoText.cause("UNRULY_PASSENGER")
      assert expected == actual
    end

    test "indefinite article no vowel" do
      expected = "a slippery rail"
      actual = AutoText.cause("SLIPPERY_RAIL")
      assert expected == actual
    end

    test "no article no vowel" do
      expected = "heavy ridership"
      actual = AutoText.cause("HEAVY_RIDERSHIP")
      assert expected == actual
    end
  end

  describe "severity/1" do
    test "when severity is nil" do
      assert AutoText.severity(nil) == ""
    end

    test "returns severity description for severity integer" do
      expected = "up to 10 minutes"
      actual = AutoText.severity(3)
      assert expected == actual
    end
  end

  describe "service_types/1" do
    test "service types empty" do
      assert AutoText.service_types([]) == ""
    end

    test "one service type" do
      expected = "Commuter Rail"
      actual = AutoText.service_types([2])
      assert expected == actual
    end

    test "two service types" do
      expected = "Ferry and Commuter Rail"
      actual = AutoText.service_types([4, 2])
      assert expected == actual
    end

    test "more than two service types" do
      expected = "Subway, Bus, Ferry, and Commuter Rail"
      actual = AutoText.service_types([1, 3, 4, 2])
      assert expected == actual
    end
  end

  describe "stop_names/1" do
    test "stops empty" do
      assert AutoText.stop_names([]) == ""
    end

    test "one stop" do
      expected = "Lechmere"
      actual = AutoText.stop_names([@stop_1])
      assert expected == actual
    end

    test "two stops" do
      expected = "Lechmere and Longwood Medical Area"
      actual = AutoText.stop_names([@stop_1, @stop_2])
      assert expected == actual
    end

    test "more than two stops" do
      expected = "Lechmere, Longwood Medical Area, Massachusetts Avenue, and Mattapan"
      actual = AutoText.stop_names([@stop_1, @stop_2, @stop_3, @stop_4])
      assert expected == actual
    end
  end

  describe "stop_form/1" do
    test "stops empty" do
      assert AutoText.stop_form([]) == ""
    end

    test "one stop" do
      assert AutoText.stop_form([@stop_1]) == "stop is"
    end

    test "multiple stops" do
      assert AutoText.stop_form([@stop_1, @stop_2]) == "stops are"
    end
  end

  describe "trip_names/2" do
    test "schedules empty" do
      assert AutoText.trip_names([], 0) == ""
    end

    test "one schedule" do
      expected = "trip 527 (9:01 AM from South Station)"
      actual = assert AutoText.trip_names([@schedule_1], 3)
      assert expected == actual
    end

    test "one schedule when commuter rail" do
      expected = "train 527 (9:01 AM from South Station)"
      actual = assert AutoText.trip_names([@schedule_1], 2)
      assert expected == actual
    end

    test "two schedules" do
      expected = "trips 527 (9:01 AM from South Station) and 841 (11:15 AM from Forest Hills)"
      actual = assert AutoText.trip_names([@schedule_1, @schedule_2], 3)
      assert expected == actual
    end

    test "two schedules when commuter rail" do
      expected = "trains 527 (9:01 AM from South Station) and 841 (11:15 AM from Forest Hills)"
      actual = assert AutoText.trip_names([@schedule_1, @schedule_2], 2)
      assert expected == actual
    end

    test "more than two schedules" do
      expected =
        "trips 527 (9:01 AM from South Station), 841 (11:15 AM from Forest Hills), and 839 (11:03 AM from South Station)"

      actual = assert AutoText.trip_names([@schedule_1, @schedule_2, @schedule_3], 3)
      assert expected == actual
    end
  end

  describe "trip_form/1" do
    test "trips empty" do
      assert AutoText.trip_form([]) == ""
    end

    test "one trip" do
      assert AutoText.trip_form([@schedule_1]) == "trip is"
    end

    test "multiple trips" do
      assert AutoText.trip_form([@schedule_1, @schedule_2]) == "trips are"
    end
  end

  describe "facility_name/1" do
    test "facility nil" do
      assert AutoText.facility_name(nil) == ""
    end

    test "facility has long name" do
      expected = "Charles/MGH Elevator 952 (Alewife platform to lobby)"
      actual = AutoText.facility_name(@facility)
      assert expected == actual
    end
  end
end
