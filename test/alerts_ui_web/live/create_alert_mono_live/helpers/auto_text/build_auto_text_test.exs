defmodule AlertsUIWeb.CreateAlertLive.Helpers.AutoText.BuildAutoTextTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.CreateAlertLive.Helpers.AutoText.BuildAutoText
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Stop

  @now AlertsUIWeb.Helpers.DateTimeHelpers.current_time()
  @one_hour_from_now NaiveDateTime.add(@now, 1, :hour)

  @stop_1 %Stop{id: "place-lech", name: "Lechmere"}
  @stop_2 %Stop{id: "place-lngmd", name: "Longwood Medical Area"}
  @stop_3 %Stop{id: "place-masta", name: "Massachusetts Avenue"}
  @stop_4 %Stop{id: "place-matt", name: "Mattapan"}

  @route_1 %Route{id: "1", name: "1", direction_names: %{0 => "Westbound", 1 => "Eastbound"}}
  @route_2 %Route{id: "22", name: "22"}
  @route_3 %Route{id: "333", name: "333"}

  @route_4 %Route{id: "741", name: "SL1"}
  @route_5 %Route{id: "742", name: "SL2"}
  @route_6 %Route{id: "746", name: "SLW"}

  @schedule_1 %EnhancedSchedule{
    route_id: "CR-Worcester",
    trip: %Trip{id: "CR-683300-527", name: "527", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    departure_time: ~U[2024-02-21 14:01:00.00Z],
    last_stop_name: "Forest Hills",
    use_trip_id_in_name?: true
  }

  @schedule_2 %EnhancedSchedule{
    route_id: "CR-Providence",
    trip: %Trip{id: "CR-687395-841", name: "841", direction_id: 0},
    stop: %Stop{id: "place-forhl", name: "Forest Hills"},
    arrival_time: nil,
    departure_time: ~U[2024-02-21 16:15:00.00Z],
    last_stop_name: "South Station"
  }

  @schedule_3 %EnhancedSchedule{
    route_id: "CR-Providence",
    trip: %Trip{id: "CR-687393-839", name: "839", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    departure_time: ~U[2024-02-21 16:03:00.00Z],
    last_stop_name: "Forest Hills"
  }

  @facility %Facility{
    id: "952",
    type: "ELEVATOR",
    short_name: "Alewife platform to lobby",
    long_name: "Charles/MGH Elevator 952 (Alewife platform to lobby)"
  }
  @facility_2 %Facility{
    id: "953",
    type: "ELEVATOR",
    short_name: "Alewife platform to lobby",
    long_name: "Charles/MGH Elevator 953"
  }

  @facility_3 %Facility{
    id: "954",
    type: "ELEVATOR",
    short_name: "Alewife platform to lobby",
    long_name: "Charles/MGH Elevator 954"
  }

  @facility_4 %Facility{
    id: "955",
    type: "ELEVATOR",
    short_name: "Alewife platform to lobby",
    long_name: "Charles/MGH Elevator 955"
  }

  describe "due_to_cause/1" do
    test "when cause is empty string" do
      assert BuildAutoText.due_to_cause(%{cause_detail: ""}) == ""
    end

    test "adds due to in front of causes" do
      expected = "due to a slippery rail"
      actual = BuildAutoText.due_to_cause(%{cause_detail: "SLIPPERY_RAIL"})
      assert expected == actual
    end

    test "capitalizes Amtrak" do
      expected = "due to Amtrak train traffic"
      actual = BuildAutoText.due_to_cause(%{cause_detail: "AMTRAK_TRAIN_TRAFFIC"})
      assert expected == actual
    end

    test "capitalizes Coast Guard" do
      expected = "due to a Coast Guard restriction"
      actual = BuildAutoText.due_to_cause(%{cause_detail: "COAST_GUARD_RESTRICTION"})
      assert expected == actual
    end
  end

  describe "cause/1" do
    test "when cause is empty" do
      assert BuildAutoText.cause("") == ""
    end

    test "definite article" do
      expected = "the holiday"
      actual = BuildAutoText.cause("HOLIDAY")
      assert expected == actual
    end

    test "indefinite article with vowel" do
      expected = "an unruly passenger"
      actual = BuildAutoText.cause("UNRULY_PASSENGER")
      assert expected == actual
    end

    test "indefinite article no vowel" do
      expected = "a slippery rail"
      actual = BuildAutoText.cause("SLIPPERY_RAIL")
      assert expected == actual
    end

    test "no article no vowel" do
      expected = "heavy ridership"
      actual = BuildAutoText.cause("HEAVY_RIDERSHIP")
      assert expected == actual
    end
  end

  describe "severity_name/1" do
    test "when severity is nil" do
      assert BuildAutoText.severity_name(%{severity: nil}) == ""
    end

    test "returns severity description for severity integer" do
      expected = "about 10 minutes"
      actual = BuildAutoText.severity_name(%{severity: 3})
      assert expected == actual
    end
  end

  describe "impacted_modes/1" do
    test "service types empty" do
      assert BuildAutoText.impacted_modes(%{service_types: []}) == ""
    end

    test "one service type" do
      expected = "Commuter Rail"
      actual = BuildAutoText.impacted_modes(%{service_types: [2]})
      assert expected == actual
    end

    test "two service types" do
      expected = "Ferry and Commuter Rail"
      actual = BuildAutoText.impacted_modes(%{service_types: [4, 2]})
      assert expected == actual
    end

    test "more than two service types" do
      expected = "Subway, Bus, Ferry, and Commuter Rail"
      actual = BuildAutoText.impacted_modes(%{service_types: [1, 3, 4, 2]})
      assert expected == actual
    end
  end

  describe "direction_name/2" do
    test "routes empty" do
      assert BuildAutoText.direction_name(%{direction: [0], routes: []}) == ""
    end

    test "directions empty" do
      assert BuildAutoText.direction_name(%{direction: [], routes: [@route_1]}) == ""
    end

    test "multiple routes" do
      assert BuildAutoText.direction_name(%{direction: [0], routes: [@route_1, @route_2]}) == ""
    end

    test "multiple directions" do
      assert BuildAutoText.direction_name(%{direction: [0, 1], routes: [@route_1, @route_2]}) ==
               ""
    end

    test "1 direction, 1 route with direction names" do
      assert BuildAutoText.direction_name(%{direction: [0], routes: [@route_1]}) == "westbound"
    end

    test "1 direction, 1 route with no direction names" do
      assert BuildAutoText.direction_name(%{direction: [1], routes: [@route_2]}) == "inbound"
    end
  end

  describe "stop_names/1" do
    test "stops empty" do
      assert BuildAutoText.stop_names(%{stops: []}) == ""
    end

    test "one stop" do
      expected = "Lechmere"
      actual = BuildAutoText.stop_names(%{stops: [@stop_1]})
      assert expected == actual
    end

    test "two stops" do
      expected = "Lechmere and Longwood Medical Area"
      actual = BuildAutoText.stop_names(%{stops: [@stop_1, @stop_2]})
      assert expected == actual
    end

    test "more than two stops" do
      expected = "4 stops"
      actual = BuildAutoText.stop_names(%{stops: [@stop_1, @stop_2, @stop_3, @stop_4]})
      assert expected == actual
    end
  end

  describe "stop_form/1" do
    test "stops empty" do
      assert BuildAutoText.stop_form(%{stops: [], start_datetime: nil}) == ""
    end

    test "starts in future" do
      assert BuildAutoText.stop_form(%{stops: [@stop_1], start_datetime: @one_hour_from_now}) ==
               "will be"
    end

    test "one stop starts now" do
      assert BuildAutoText.stop_form(%{stops: [@stop_1], start_datetime: @now}) == "is"
    end

    test "multiple stops starts now" do
      assert BuildAutoText.stop_form(%{stops: [@stop_1, @stop_2], start_datetime: @now}) == "are"
    end

    test "start_specifier :now overrides future start_datetime" do
      assert BuildAutoText.stop_form(%{
               stops: [@stop_1],
               start_datetime: @one_hour_from_now,
               start_specifier: :now
             }) == "is"
    end
  end

  describe "stop_word/1" do
    test "stops empty" do
      assert BuildAutoText.stop_word(%{stops: []}) == ""
    end

    test "one stop" do
      assert BuildAutoText.stop_word(%{stops: [@stop_1]}) == "stop"
    end

    test "multiple stops" do
      assert BuildAutoText.stop_word(%{stops: [@stop_1, @stop_2]}) == "stops"
    end
  end

  describe "stop_range_between/1" do
    test "stops empty" do
      assert BuildAutoText.stop_range_between(%{stops: []}) == ""
    end

    test "one stop" do
      expected = "at Lechmere"
      actual = assert BuildAutoText.stop_range_between(%{stops: [@stop_1]})
      assert expected == actual
    end

    test "multiple stops" do
      expected = "between Lechmere and Mattapan"
      actual = BuildAutoText.stop_range_between(%{stops: [@stop_1, @stop_2, @stop_3, @stop_4]})
      assert expected == actual
    end
  end

  describe "stop_range_at/1" do
    test "stops empty" do
      assert BuildAutoText.stop_range_at(%{stops: []}) == ""
    end

    test "1 stop" do
      expected = "at Lechmere"
      actual = BuildAutoText.stop_range_at(%{stops: [@stop_1]})
      assert expected == actual
    end

    test "2 stops" do
      expected = "at Lechmere and Longwood Medical Area"
      actual = BuildAutoText.stop_range_at(%{stops: [@stop_1, @stop_2]})
      assert expected == actual
    end

    test "3 stops" do
      expected = "at Lechmere, Longwood Medical Area, and Massachusetts Avenue"
      actual = BuildAutoText.stop_range_at(%{stops: [@stop_1, @stop_2, @stop_3]})
      assert expected == actual
    end

    test "4 stops" do
      expected = "at Lechmere through Mattapan"
      actual = BuildAutoText.stop_range_at(%{stops: [@stop_1, @stop_2, @stop_3, @stop_4]})
      assert expected == actual
    end
  end

  describe "skipping stop text/1" do
    test "when there's missed stops but they're empty" do
      assert BuildAutoText.skipping_stop_text(%{missed_stops: []}) ==
               ", but no stops are being skipped"
    end

    test "when there's multiple directions" do
      assert BuildAutoText.skipping_stop_text(%{direction: [0, 1]}) == ""
    end

    test "when there's only 1 direction" do
      assert BuildAutoText.skipping_stop_text(%{
               direction: [0],
               stops: [
                 %{@stop_1 | name: "Lechmere (outbound)"},
                 %{@stop_2 | name: "Longwood Medical Area (outbound)"}
               ]
             }) ==
               ", skipping Lechmere and Longwood Medical Area"
    end
  end

  describe "closest_stop_text/1" do
    test "when there's connection points but they're empty" do
      assert BuildAutoText.closest_stop_text(%{connection_points: [], missed_stops: ["72"]}) ==
               ""
    end

    test "when there's connection points but no missed stops" do
      assert BuildAutoText.closest_stop_text(%{
               connection_points: ["Massachusetts Ave opp Inman St"],
               missed_stops: []
             }) == ""
    end

    test "when there's 1 connection point" do
      assert BuildAutoText.closest_stop_text(%{
               connection_points: ["Massachusetts Ave opp Inman St"],
               missed_stops: ["72"]
             }) ==
               "The closest stop with service is Massachusetts Ave opp Inman St."
    end

    test "when there's multiple connection points" do
      assert BuildAutoText.closest_stop_text(%{
               connection_points: [
                 "Massachusetts Ave opp Inman St",
                 "Massachusetts Ave @ Sidney St"
               ],
               missed_stops: ["72"]
             }) ==
               "The closest stops with service are Massachusetts Ave opp Inman St and Massachusetts Ave @ Sidney St."
    end

    test "when there's only 1 direction" do
      assert BuildAutoText.closest_stop_text(%{direction: [0]}) ==
               "The closest stops with service are ___ and ___."
    end

    test "when there's multiple directions" do
      assert BuildAutoText.closest_stop_text(%{direction: [0, 1]}) ==
               "The closest stops with outbound service are ___ and ___. The closest stops with inbound service are ___ and ___."
    end
  end

  describe "trip_names_only/1" do
    test "schedules empty" do
      autotext_data = %{
        schedules: []
      }

      assert BuildAutoText.trip_names_only(autotext_data) == ""
    end

    test "one schedule" do
      autotext_data = %{
        schedules: [@schedule_1],
        route_type: 4
      }

      expected = "9:01 AM from South Station to Forest Hills"
      actual = assert BuildAutoText.trip_names_only(autotext_data)
      assert expected == actual
    end

    test "two schedules" do
      autotext_data = %{
        schedules: [@schedule_1, @schedule_2],
        route_type: 4
      }

      expected =
        "9:01 AM from South Station to Forest Hills and 11:15 AM from Forest Hills to South Station"

      actual = assert BuildAutoText.trip_names_only(autotext_data)
      assert expected == actual
    end

    test "more than two schedules" do
      autotext_data = %{
        schedules: [@schedule_1, @schedule_2, @schedule_3],
        route_type: 4
      }

      expected =
        "9:01 AM from South Station to Forest Hills and 2 other trips"

      actual = assert BuildAutoText.trip_names_only(autotext_data)
      assert expected == actual
    end
  end

  describe "trip_names/1" do
    test "schedules empty" do
      autotext_data = %{
        schedules: [],
        route_type: 0
      }

      assert BuildAutoText.trip_names(autotext_data) == ""
    end

    test "one schedule" do
      autotext_data = %{
        schedules: [@schedule_1],
        route_type: 3
      }

      expected = "trip 527 (9:01 AM from South Station)"
      actual = assert BuildAutoText.trip_names(autotext_data)
      assert expected == actual
    end

    test "one schedule when commuter rail" do
      autotext_data = %{
        schedules: [@schedule_1],
        route_type: 2
      }

      expected = "Train 527 (9:01 AM from South Station)"
      actual = assert BuildAutoText.trip_names(autotext_data)
      assert expected == actual
    end

    test "two schedules" do
      autotext_data = %{
        schedules: [@schedule_1, @schedule_2],
        route_type: 3
      }

      expected = "trips 527 (9:01 AM from South Station) and 841 (11:15 AM from Forest Hills)"
      actual = assert BuildAutoText.trip_names(autotext_data)
      assert expected == actual
    end

    test "two schedules when commuter rail" do
      autotext_data = %{
        schedules: [@schedule_1, @schedule_2],
        route_type: 2
      }

      expected = "Trains 527 (9:01 AM from South Station) and 841 (11:15 AM from Forest Hills)"
      actual = assert BuildAutoText.trip_names(autotext_data)
      assert expected == actual
    end

    test "more than two schedules" do
      autotext_data = %{
        schedules: [@schedule_1, @schedule_2, @schedule_3],
        route_type: 3
      }

      expected =
        "trip 527 (9:01 AM from South Station) and 2 other trips"

      actual = assert BuildAutoText.trip_names(autotext_data)
      assert expected == actual
    end

    test "more than two schedules when commuter rail" do
      autotext_data = %{
        schedules: [@schedule_1, @schedule_2, @schedule_3],
        route_type: 2
      }

      expected =
        "Train 527 (9:01 AM from South Station) and 2 other trains"

      actual = assert BuildAutoText.trip_names(autotext_data)
      assert expected == actual
    end
  end

  describe "trip_form/1" do
    test "trips empty" do
      assert BuildAutoText.trip_form(%{schedules: [], start_datetime: nil}) == ""
    end

    test "starts in future" do
      assert BuildAutoText.trip_form(%{
               schedules: [@schedule_1],
               start_datetime: @one_hour_from_now
             }) == "will be"
    end

    test "one trip" do
      assert BuildAutoText.trip_form(%{schedules: [@schedule_1], start_datetime: @now}) == "is"
    end

    test "multiple trips" do
      assert BuildAutoText.trip_form(%{
               schedules: [@schedule_1, @schedule_2],
               start_datetime: @now
             }) == "are"
    end

    test "start_specifier :now overrides future start_datetime" do
      assert BuildAutoText.trip_form(%{
               schedules: [@schedule_1],
               start_datetime: @one_hour_from_now,
               start_specifier: :now
             }) == "is"
    end
  end

  describe "facility_names/1" do
    test "facility empty" do
      assert BuildAutoText.facility_names(%{facilities: []}) == ""
    end

    test "facility has long name" do
      expected = "Charles/MGH Elevator 952 (Alewife platform to lobby)"
      actual = BuildAutoText.facility_names(%{facilities: [@facility]})
      assert expected == actual
    end

    test "there's 3 facilities" do
      expected =
        "Charles/MGH Elevator 952 (Alewife platform to lobby), Charles/MGH Elevator 953, and Charles/MGH Elevator 954"

      actual = BuildAutoText.facility_names(%{facilities: [@facility, @facility_2, @facility_3]})
      assert expected == actual
    end

    test "there's 4 facilities" do
      expected =
        "Charles/MGH Elevator 952 (Alewife platform to lobby), Charles/MGH Elevator 953, and 2 other facilities"

      actual =
        BuildAutoText.facility_names(%{
          facilities: [@facility, @facility_2, @facility_3, @facility_4]
        })

      assert expected == actual
    end
  end

  describe "route_names_short/2" do
    test "when routes are empty" do
      assert BuildAutoText.route_names_short(%{routes: [], route_type: 1}) == ""
    end

    test "when there is 1 numeric route" do
      expected = "Route 1"

      actual =
        BuildAutoText.route_names_short(%{routes: [@route_1], schedules: [], route_type: 3})

      assert expected == actual
    end

    test "when there is 1 non-numeric route" do
      expected = "SL1"

      actual =
        BuildAutoText.route_names_short(%{routes: [@route_4], schedules: [], route_type: 3})

      assert expected == actual
    end

    test "when there are 2 numeric routes" do
      expected = "Routes 1 and 22"

      actual =
        BuildAutoText.route_names_short(%{
          routes: [@route_1, @route_2],
          schedules: [],
          route_type: 3
        })

      assert expected == actual
    end

    test "when there are 2 non-numeric routes" do
      expected = "SL1 and SL2"

      actual =
        BuildAutoText.route_names_short(%{
          routes: [@route_4, @route_5],
          schedules: [],
          route_type: 3
        })

      assert expected == actual
    end

    test "when there is 1 numeric and 1 non-numeric routes" do
      expected = "SL1 and Route 1"

      actual =
        BuildAutoText.route_names_short(%{
          routes: [@route_1, @route_4],
          schedules: [],
          route_type: 3
        })

      assert expected == actual
    end

    test "when there are more than 3 routes" do
      expected = "Bus"

      actual =
        BuildAutoText.route_names_short(%{routes: [@route_1, @route_4, @route_5], route_type: 3})

      assert expected == actual
    end
  end

  describe "route_names/1" do
    test "when routes are empty" do
      assert BuildAutoText.route_names(%{routes: []}) == ""
    end

    test "when there is a branch name" do
      expected = "Providence Line"
      actual = BuildAutoText.route_names(%{routes: [@route_1], branch_name: "Providence Line"})
      assert expected == actual
    end

    test "when there is 1 numeric route" do
      expected = "Route 1"
      actual = BuildAutoText.route_names(%{routes: [@route_1], schedules: []})
      assert expected == actual
    end

    test "when there are 2 numeric route" do
      expected = "Routes 1 and 22"
      actual = BuildAutoText.route_names(%{routes: [@route_1, @route_2], schedules: []})
      assert expected == actual
    end

    test "when there are more than 2 numeric routes" do
      expected = "Routes 1, 22, and 333"
      actual = BuildAutoText.route_names(%{routes: [@route_1, @route_2, @route_3], schedules: []})
      assert expected == actual
    end

    test "when there is 1 non-numeric route" do
      expected = "SL1"
      actual = BuildAutoText.route_names(%{routes: [@route_4], schedules: []})
      assert expected == actual
    end

    test "when there are 2 non-numeric routes" do
      expected = "SL1 and SL2"
      actual = BuildAutoText.route_names(%{routes: [@route_4, @route_5], schedules: []})
      assert expected == actual
    end

    test "when there are more than 2 non-numeric routes" do
      expected = "SL1, SL2, and SLW"
      actual = BuildAutoText.route_names(%{routes: [@route_4, @route_5, @route_6], schedules: []})
      assert expected == actual
    end

    test "when there is 1 numeric and 1 non-numeric route" do
      expected = "SL1 and Route 1"
      actual = BuildAutoText.route_names(%{routes: [@route_1, @route_4], schedules: []})
      assert expected == actual
    end

    test "when there is 1 numeric and 2 non-numeric routes" do
      expected = "SL1 and Routes 1 and 22"
      actual = BuildAutoText.route_names(%{routes: [@route_1, @route_2, @route_4], schedules: []})
      assert expected == actual
    end

    test "when there are 2 numeric and 2 non-numeric routes" do
      expected = "SL1, SL2 and Routes 1 and 22"

      actual =
        BuildAutoText.route_names(%{
          routes: [@route_1, @route_2, @route_4, @route_5],
          schedules: []
        })

      assert expected == actual
    end

    test "when there are 2 numeric and 3 non-numeric routes" do
      expected = "SL1, SL2, SLW and Routes 1 and 22"

      actual =
        BuildAutoText.route_names(%{
          routes: [@route_1, @route_2, @route_4, @route_5, @route_6],
          schedules: []
        })

      assert expected == actual
    end

    test "when there are 6 numeric routes" do
      expected = "Route 1 and 5 other routes"

      actual =
        BuildAutoText.route_names(%{
          routes: [@route_1, @route_2, @route_3, @route_1, @route_2, @route_3],
          schedules: []
        })

      assert expected == actual
    end

    test "when there are 6 non-numeric routes" do
      expected = "SL1 and 5 other routes"

      actual =
        BuildAutoText.route_names(%{
          routes: [@route_4, @route_5, @route_6, @route_4, @route_5, @route_6],
          schedules: []
        })

      assert expected == actual
    end

    test "when there are 1 numeric and 5 non-numeric routes" do
      expected = "SL1 and 5 other routes"

      actual =
        BuildAutoText.route_names(%{
          routes: [@route_1, @route_4, @route_5, @route_6, @route_4, @route_5],
          schedules: []
        })

      assert expected == actual
    end

    test "when there are 5 numeric and 1 non-numeric routes" do
      expected = "SL1 and 5 other routes"

      actual =
        BuildAutoText.route_names(%{
          routes: [@route_1, @route_2, @route_3, @route_2, @route_3, @route_4],
          schedules: []
        })

      assert expected == actual
    end

    test "route names are sorted correctly" do
      expected = "Orange, Red and Routes 22 and 119"

      routes = [
        %Route{name: "Red", type: 1},
        %Route{name: "Orange", type: 1},
        %Route{name: "119", type: 3},
        %Route{name: "22", type: 3}
      ]

      actual =
        BuildAutoText.route_names(%{
          routes: routes,
          schedules: []
        })

      assert expected == actual
    end

    test "when there is a route not associated with a given schedule" do
      expected = "Framingham/Worcester Line"
      route_2 = %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"}
      actual = BuildAutoText.route_names(%{routes: [@route_1, route_2], schedules: [@schedule_1]})
      assert expected == actual
    end
  end

  describe "route_form/1" do
    test "routes empty" do
      assert BuildAutoText.route_form(%{routes: [], start_datetime: nil}) == ""
    end

    test "starts in future" do
      assert BuildAutoText.route_form(%{routes: [@route_1], start_datetime: @one_hour_from_now}) ==
               "will be"
    end

    test "one route" do
      assert BuildAutoText.route_form(%{routes: [@route_1], start_datetime: @now}) == "is"
    end

    test "multiple routes" do
      assert BuildAutoText.route_form(%{routes: [@route_1, @route_2], start_datetime: @now}) ==
               "are"
    end

    test "start_specifier :now overrides future start_datetime" do
      assert BuildAutoText.route_form(%{
               routes: [@route_1],
               start_datetime: @one_hour_from_now,
               start_specifier: :now
             }) == "is"
    end
  end

  describe "facility_form/1" do
    @facility %Facility{id: "elev-alewife", short_name: "Alewife Elevator 843"}

    test "facilities empty" do
      assert BuildAutoText.facility_form(%{facilities: [], start_datetime: nil}) == ""
    end

    test "starts in future" do
      assert BuildAutoText.facility_form(%{
               facilities: [@facility],
               start_datetime: @one_hour_from_now
             }) == "will be"
    end

    test "one facility starts now" do
      assert BuildAutoText.facility_form(%{facilities: [@facility], start_datetime: @now}) == "is"
    end

    test "start_specifier :now overrides future start_datetime" do
      assert BuildAutoText.facility_form(%{
               facilities: [@facility],
               start_datetime: @one_hour_from_now,
               start_specifier: :now
             }) == "is"
    end
  end

  describe "singular_copula/1" do
    test "start datetime is nil" do
      assert BuildAutoText.singular_copula(%{start_datetime: nil}) == ""
    end

    test "starts in future" do
      assert BuildAutoText.singular_copula(%{
               start_datetime: @one_hour_from_now
             }) == "will be"
    end

    test "starts now" do
      assert BuildAutoText.singular_copula(%{start_datetime: @now}) == "is"
    end

    test "start_specifier :now overrides future start_datetime" do
      assert BuildAutoText.singular_copula(%{
               start_datetime: @one_hour_from_now,
               start_specifier: :now
             }) == "is"
    end
  end

  describe "plural_copula/1" do
    test "start datetime is nil" do
      assert BuildAutoText.plural_copula(%{start_datetime: nil}) == ""
    end

    test "starts in future" do
      assert BuildAutoText.plural_copula(%{
               start_datetime: @one_hour_from_now
             }) == "will be"
    end

    test "starts now" do
      assert BuildAutoText.plural_copula(%{start_datetime: @now}) == "are"
    end

    test "start_specifier :now overrides future start_datetime" do
      assert BuildAutoText.plural_copula(%{
               start_datetime: @one_hour_from_now,
               start_specifier: :now
             }) == "are"
    end
  end
end
