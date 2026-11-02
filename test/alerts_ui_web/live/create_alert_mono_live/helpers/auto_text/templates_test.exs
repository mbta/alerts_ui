defmodule AlertsUIWeb.CreateAlertLive.Helpers.AutoText.TemplatesTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.CreateAlertLive.Helpers.AutoText.Templates
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Stop

  @facility %Facility{
    id: "952",
    type: "ELEVATOR",
    short_name: "Alewife platform to lobby",
    long_name: "Charles/MGH Elevator 952 (Alewife platform to lobby)",
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

  @facility_2 %Facility{
    id: "953",
    type: "ELEVATOR",
    short_name: "Alewife platform 2 to lobby",
    long_name: "Charles/MGH Elevator 953 (Alewife platform 2 to lobby 2)",
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

  @route_1 %Route{id: "1", name: "1", direction_names: %{0 => "Westbound", 1 => "Eastbound"}}
  @route_2 %Route{id: "22", name: "22"}

  @stop_1 %Stop{id: "place-lech", name: "Lechmere"}
  @stop_2 %Stop{id: "place-lngmd", name: "Longwood Medical Area"}

  @stop_1_bus %Stop{id: "place-lech", name: "Lechmere (inbound)"}
  @stop_2_bus %Stop{id: "place-lngmd", name: "Longwood Medical Area (outbound)"}

  @schedule_1 %EnhancedSchedule{
    route_id: @route_1.id,
    trip: %Trip{id: "CR-683300-527", name: "527", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    departure_time: ~U[2024-02-21 14:01:00.00Z],
    last_stop_name: "Forest Hills"
  }

  @schedule_2 %EnhancedSchedule{
    route_id: @route_2.id,
    trip: %Trip{id: "CR-687395-841", name: "841", direction_id: 1},
    stop: %Stop{id: "place-forhl", name: "Forest Hills"},
    arrival_time: nil,
    departure_time: ~U[2024-02-21 16:15:00.00Z],
    last_stop_name: "South Station"
  }

  @schedule_3 %EnhancedSchedule{
    route_id: @route_1.id,
    trip: %Trip{id: "CR-683300-527", name: "528", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    departure_time: ~U[2024-02-21 14:01:00.00Z],
    last_stop_name: "Forest Hills"
  }

  # putting these here to prevent a weird test race condition
  # with string_to_existing_atom
  :facility_names
  :route_names
  :impacted_modes
  :stop_form
  :stop_names
  :stop_names_short
  :route_name

  describe "build_auto_text/2 (header templates)" do
    test "Properly renders when some parts are empty" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        stops: [@stop_1],
        effect_name: "Stop Closure",
        cause_detail: "",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :later_today,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-08 15:00:00]
      }

      expected_header = "Lechmere is closed."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Lechmere closed"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    # access
    test "access alert bike issue" do
      autotext_data = %{
        facilities: [@facility],
        combination: :ACCESS,
        route_type: nil,
        effect_name: "Bike Issue",
        cause_detail: "HOLIDAY",
        stops: [@stop_1],
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected_header =
        "Charles/MGH Elevator 952 (Alewife platform to lobby): issue today due to the holiday."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Lechmere bicycle issue"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "access alert escalator closure" do
      autotext_data = %{
        facilities: [@facility],
        combination: :ACCESS,
        route_type: nil,
        effect_name: "Escalator Closure",
        cause_detail: "HOLIDAY",
        stops: [@stop_1],
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected_header =
        "Charles/MGH Elevator 952 (Alewife platform to lobby) is unavailable today due to the holiday."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Lechmere escalator unavailable"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "access alert parking closure" do
      autotext_data = %{
        facilities: [@facility],
        combination: :ACCESS,
        route_type: nil,
        effect_name: "Parking Closure",
        cause_detail: "HOLIDAY",
        stops: [@stop_1],
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected_header =
        "Charles/MGH Elevator 952 (Alewife platform to lobby) is closed today due to the holiday."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Lechmere parking closure"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "access alert elevator closure" do
      autotext_data = %{
        facilities: [@facility, @facility_2],
        combination: :ACCESS,
        route_type: nil,
        effect_name: "Elevator Closure",
        cause_detail: "HOLIDAY",
        stops: [@stop_1],
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected_header =
        "Charles/MGH Elevator 952 (Alewife platform to lobby) and Charles/MGH Elevator 953 (Alewife platform 2 to lobby 2) are unavailable today due to the holiday."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Lechmere elevator unavailable"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "access alert access issue" do
      autotext_data = %{
        facilities: [@facility],
        combination: :ACCESS,
        route_type: nil,
        effect_name: "Access Issue",
        cause_detail: "HOLIDAY",
        stops: [@stop_1],
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected_header =
        "Charles/MGH Elevator 952 (Alewife platform to lobby): issue today due to the holiday."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Lechmere access issue"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "access alert facility issue" do
      autotext_data = %{
        facilities: [@facility],
        route_type: nil,
        effect_name: "Facility Issue",
        cause_detail: "HOLIDAY",
        stops: [@stop_1],
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected_header =
        "Charles/MGH Elevator 952 (Alewife platform to lobby): issue today due to the holiday."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Lechmere issue"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "access alert parking issue" do
      autotext_data = %{
        facilities: [@facility],
        route_type: nil,
        effect_name: "Parking Issue",
        cause_detail: "HOLIDAY",
        stops: [@stop_1],
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected_header =
        "Charles/MGH Elevator 952 (Alewife platform to lobby): issue today due to the holiday."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Lechmere parking issue"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    # systemwide
    test "systemwide alert service change issue" do
      autotext_data = %{
        route_type: nil,
        service_types: [4, 2],
        effect_name: "Service Change",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Ferry and Commuter Rail service change until Sat, May 10 at 3:00 PM due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Ferry and Commuter Rail service change"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "systemwide alert suspension issue" do
      autotext_data = %{
        route_type: nil,
        service_types: [4, 2],
        effect_name: "Suspension",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Ferry and Commuter Rail service is suspended until Sat, May 10 at 3:00 PM due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Ferry and Commuter Rail service suspension"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "systemwide alert amber alert issue" do
      autotext_data = %{
        route_type: nil,
        effect_name: "Amber Alert"
      }

      expected_header =
        "Amber Alert"

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Amber Alert"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "systemwide alert notice" do
      autotext_data = %{
        route_type: nil,
        service_types: [4],
        effect_name: "Notice",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Ferry notice until Sat, May 10 at 3:00 PM due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Ferry notice"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "systemwide alert policy change issue" do
      autotext_data = %{
        route_type: nil,
        service_types: [4, 2],
        effect_name: "Policy Change"
      }

      expected_header =
        "Policy change affecting Ferry and Commuter Rail service."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Ferry and Commuter Rail policy change"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "systemwide alert delay" do
      autotext_data = %{
        route_type: nil,
        service_types: [4, 2],
        effect_name: "Delay",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Ferry and Commuter Rail service may experience delays until Sat, May 10 at 3:00 PM due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Ferry and Commuter Rail delays"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "systemwide alert summary" do
      autotext_data = %{
        route_type: nil,
        service_types: [4, 2],
        effect_name: "Summary",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Ferry and Commuter Rail notice until Sat, May 10 at 3:00 PM due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Ferry and Commuter Rail notice"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "systemwide alert schedule change" do
      autotext_data = %{
        route_type: nil,
        service_types: [4, 2],
        effect_name: "Schedule Change",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Planned Ferry and Commuter Rail schedule change until Sat, May 10 at 3:00 PM due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Ferry and Commuter Rail schedule change"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "systemwide alert extra service" do
      autotext_data = %{
        route_type: nil,
        service_types: [4, 2],
        effect_name: "Extra Service",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Extra Ferry and Commuter Rail service until Sat, May 10 at 3:00 PM due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Extra Ferry and Commuter Rail service"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    # ferry
    test "Ferry dock bypass" do
      autotext_data = %{
        route_type: 4,
        routes: [@route_1],
        stops: [@stop_1, @stop_2],
        schedules: [@schedule_1, @schedule_2, @schedule_3],
        direction: [0],
        severity: 3,
        effect_name: "Dock Bypass",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        cause_detail: "ICE_IN_HARBOR",
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected =
        "Route 1 westbound trip 9:01 AM from South Station to Forest Hills and 2 other trips will not stop at Lechmere and Longwood Medical Area today through Sat, May 10 due to ice in harbor."

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual

      expected_service_effect = "Lechmere and Longwood Medical Area bypassed"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Ferry dock closure" do
      autotext_data = %{
        route_type: 4,
        stops: [@stop_1],
        effect_name: "Dock Closure",
        cause_detail: "UNRULY_PASSENGER",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Lechmere is closed until Sat, May 10 at 3:00 PM due to an unruly passenger."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Lechmere closed"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Ferry suspension" do
      autotext_data = %{
        route_type: 4,
        routes: [@route_1],
        stops: [@stop_1],
        direction: [1],
        schedules: [@schedule_1],
        effect_name: "Suspension",
        cause_detail: "UNRULY_PASSENGER",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 eastbound trip 9:01 AM from South Station to Forest Hills: service is suspended at Lechmere today through Sat, May 10 due to an unruly passenger."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Suspension of service on Route 1"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Ferry cancellation" do
      autotext_data = %{
        route_type: 4,
        routes: [@route_1],
        schedules: [@schedule_1],
        effect_name: "Cancellation",
        cause_detail: "UNRULY_PASSENGER",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 trip 9:01 AM from South Station to Forest Hills is cancelled today through Sat, May 10 due to an unruly passenger."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 trip cancelled"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Ferry delay" do
      autotext_data = %{
        route_type: 4,
        routes: [@route_1],
        schedules: [@schedule_1],
        effect_name: "Delay",
        severity: 3,
        cause_detail: "UNRULY_PASSENGER",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 trip 9:01 AM from South Station to Forest Hills operating about 10 minutes late today through Sat, May 10 due to an unruly passenger."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 delay"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    # Bus
    test "Bus stop closure" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        stops: [@stop_1],
        effect_name: "Stop Closure",
        cause_detail: "PARADE",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Lechmere is closed until Sat, May 10 at 3:00 PM due to a parade."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Lechmere closed"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Bus delay" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        stops: [@stop_1],
        schedules: [],
        effect_name: "Delay",
        severity: 3,
        direction: [1],
        cause_detail: "PARADE",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 is experiencing eastbound delays of about 10 minutes due to a parade."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 delay"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Bus suspension" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        stops: [@stop_1],
        schedules: [],
        effect_name: "Suspension",
        direction: [1],
        cause_detail: "PARADE",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 eastbound service is suspended at Lechmere until Sat, May 10 at 3:00 PM due to a parade."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Suspension of service on Route 1"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Bus multi-route detour" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        stops: [@stop_1],
        schedules: [],
        effect_name: "Multi-Route Detour",
        cause_detail: "PARADE",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 is detoured until Sat, May 10 at 3:00 PM, skipping Lechmere due to a parade."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 detour"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Bus stop move" do
      autotext_data = %{
        route_type: 3,
        stops: [@stop_1],
        effect_name: "Stop Move",
        cause_detail: "PARADE",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header = "Lechmere is moving until Sat, May 10 at 3:00 PM due to a parade."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Lechmere stop moved"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Bus detour" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        stops: [@stop_1_bus],
        direction: [0],
        schedules: [],
        effect_name: "Detour",
        cause_detail: "PARADE",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 westbound is detoured until Sat, May 10 at 3:00 PM, skipping Lechmere due to a parade. The closest stops with service are ___ and ___."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 detour"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Bus snow route" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        schedules: [],
        effect_name: "Snow Route",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header = "Route 1 snow route in effect until Sat, May 10 at 3:00 PM."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 on snow route"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    # subway

    test "Subway suspension" do
      autotext_data = %{
        route_type: 1,
        routes: [@route_1],
        stops: [@stop_1],
        schedules: [],
        direction: [0],
        effect_name: "Suspension",
        cause_detail: "ICE_IN_HARBOR",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1: westbound service is suspended at Lechmere until Sat, May 10 at 3:00 PM due to ice in harbor."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Suspension of service on Route 1"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Subway delay" do
      autotext_data = %{
        route_type: 1,
        routes: [@route_1],
        schedules: [],
        direction: [0],
        severity: 3,
        effect_name: "Delay",
        cause_detail: "ICE_IN_HARBOR",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header = "Route 1: westbound delays of about 10 minutes due to ice in harbor."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 delay"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Subway service change" do
      autotext_data = %{
        route_type: 1,
        routes: [@route_1],
        schedules: [],
        direction: [0],
        severity: 3,
        effect_name: "Service Change",
        cause_detail: "ICE_IN_HARBOR",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 service change until Sat, May 10 at 3:00 PM due to ice in harbor."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 service change"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Subway shuttle" do
      autotext_data = %{
        route_type: 1,
        routes: [@route_1],
        stops: [@stop_1],
        schedules: [],
        direction: [0],
        severity: 3,
        effect_name: "Shuttle",
        cause_detail: "ICE_IN_HARBOR",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1: Shuttle buses are replacing westbound service at Lechmere until Sat, May 10 at 3:00 PM due to ice in harbor."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 shuttle"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Subway single tracking" do
      autotext_data = %{
        route_type: 1,
        routes: [@route_1],
        stops: [@stop_1, @stop_2],
        schedules: [],
        direction: [0],
        severity: 3,
        effect_name: "Single Tracking",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected =
        "Route 1: Trains in both directions are operating on a single track between Lechmere and Longwood Medical Area. Riders may experience longer wait times."

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual

      expected_service_effect = "Single tracking on Route 1"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    # Commuter Rail

    test "CR Delay" do
      autotext_data = %{
        route_type: 2,
        routes: [@route_1],
        stops: [@stop_1],
        schedules: [@schedule_1],
        direction: [0],
        severity: 3,
        effect_name: "Delay",
        cause_detail: "HAZMAT_CONDITION",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 Train 527 (9:01 AM from South Station) is operating about 10 minutes behind schedule at Lechmere due to a hazmat condition."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 delay"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "CR Shuttle" do
      autotext_data = %{
        route_type: 2,
        routes: [@route_1],
        stops: [@stop_1],
        schedules: [@schedule_1],
        direction: [0],
        severity: 3,
        effect_name: "Shuttle",
        cause_detail: "HAZMAT_CONDITION",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 westbound Train 527 (9:01 AM from South Station) will be replaced by a shuttle bus at Lechmere today through Sat, May 10 due to a hazmat condition."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 shuttle"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "CR Track Change" do
      autotext_data = %{
        route_type: 2,
        routes: [@route_1],
        stops: [@stop_1],
        schedules: [@schedule_1],
        direction: [0],
        severity: 3,
        effect_name: "Track Change",
        cause_detail: "HAZMAT_CONDITION",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Please board Route 1 Train 527 (9:01 AM from South Station) on the ___ platform (Track ___) at Lechmere today through Sat, May 10 due to a hazmat condition."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 track change"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "CR Cancellation" do
      autotext_data = %{
        route_type: 2,
        routes: [@route_1],
        schedules: [@schedule_1],
        direction: [0],
        effect_name: "Cancellation",
        cause_detail: "HAZMAT_CONDITION",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 Train 527 (9:01 AM from South Station) is cancelled today through Sat, May 10 due to a hazmat condition."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 train cancelled"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "CR Service change" do
      autotext_data = %{
        route_type: 2,
        routes: [@route_1],
        schedules: [@schedule_1],
        direction: [0],
        effect_name: "Service Change",
        cause_detail: "HAZMAT_CONDITION",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 Train 527 (9:01 AM from South Station) service change today through Sat, May 10 due to a hazmat condition."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 service change"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    # mode not specified
    test "Service change" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        schedules: [],
        effect_name: "Service Change",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 service change until Sat, May 10 at 3:00 PM due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 service change"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Dock issue" do
      autotext_data = %{
        route_type: 4,
        stops: [@stop_1],
        effect_name: "Dock Issue",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Dock issue at Lechmere until Sat, May 10 at 3:00 PM due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Dock issue at Lechmere"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Shuttle" do
      autotext_data = %{
        route_type: 4,
        routes: [@route_1],
        stops: [@stop_1],
        schedules: [],
        direction: [1],
        effect_name: "Shuttle",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 eastbound will be replaced by shuttle buses at Lechmere today through Sat, May 10 due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 shuttle"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Suspension" do
      autotext_data = %{
        route_type: 2,
        routes: [@route_1],
        stops: [@stop_1],
        schedules: [@schedule_1],
        direction: [1],
        effect_name: "Suspension",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 eastbound Train 527 (9:01 AM from South Station): service is suspended at Lechmere today through Sat, May 10 due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Suspension of service on Route 1"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Extra service" do
      autotext_data = %{
        route_type: 2,
        routes: [@route_1],
        schedules: [],
        effect_name: "Extra Service",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Extra service on Route 1 until Sat, May 10 at 3:00 PM due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Extra Route 1 service"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Station closure" do
      autotext_data = %{
        route_type: 2,
        stops: [@stop_1],
        effect_name: "Station Closure",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Lechmere is closed until Sat, May 10 at 3:00 PM due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Lechmere closed"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Delay" do
      # there is no current circustance under which you would see this one
      autotext_data = %{
        route_type: 0,
        routes: [@route_1],
        schedules: [@schedule_1],
        stops: [@stop_1],
        severity: 3,
        effect_name: "Delay",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 trip 527 (9:01 AM from South Station) experiencing delays of about 10 minutes until Sat, May 10 at 3:00 PM due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 delay"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Notice" do
      autotext_data = %{
        route_type: 2,
        routes: [@route_1],
        schedules: [],
        effect_name: "Notice",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Route 1 notice today through Sat, May 10 due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 notice"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Schedule change" do
      autotext_data = %{
        route_type: 2,
        routes: [@route_1],
        schedules: [@schedule_1],
        effect_name: "Schedule Change",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Planned schedule change on Route 1 until Sat, May 10 at 3:00 PM due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Route 1 schedule change"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Station issue" do
      autotext_data = %{
        route_type: 2,
        stops: [@stop_1],
        schedules: [@schedule_1],
        routes: [@route_1],
        effect_name: "Station Issue",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected_header =
        "Station issue at Lechmere until Sat, May 10 at 3:00 PM due to a slippery rail."

      actual_header = Templates.build_auto_text(autotext_data, :header_template)
      assert expected_header == actual_header

      expected_service_effect = "Station issue at Lechmere"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end

    test "Station bypass" do
      autotext_data = %{
        route_type: 1,
        routes: [@route_1],
        stops: [@stop_1, @stop_2],
        schedules: [@schedule_1, @schedule_2, @schedule_3],
        direction: [0],
        severity: 3,
        effect_name: "Station Bypass",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        cause_detail: "ICE_IN_HARBOR",
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected =
        "Route 1 westbound trip 527 (9:01 AM from South Station) and 2 other trips will not stop at Lechmere and Longwood Medical Area until Sat, May 10 at 3:00 PM due to ice in harbor."

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual

      expected_service_effect = "Lechmere and Longwood Medical Area bypassed"
      actual_service_effect = Templates.build_auto_text(autotext_data, :service_effect_template)
      assert expected_service_effect == actual_service_effect
    end
  end

  describe "build_auto_text/2 (description templates)" do
    test "systemwide" do
      autotext_data = %{
        route_type: nil,
        effect_name: "Policy Change"
      }

      assert Templates.build_auto_text(autotext_data, :description_template) == ""
    end

    test "access" do
      autotext_data = %{
        route_type: nil,
        effect_name: "Elevator Closure",
        facilities: [@facility]
      }

      expected =
        "To access the Bowdoin platform or Bremen St lobby from the Wonderland platform..."

      actual = Templates.build_auto_text(autotext_data, :description_template)

      assert expected == actual
    end

    test "when stuff is empty" do
      autotext_data = %{
        route_type: 4,
        effect_name: "Cancellation",
        routes: [],
        schedules: [],
        stops: [],
        direction: []
      }

      assert Templates.build_auto_text(autotext_data, :description_template) == ""
    end

    # ferry
    test "ferry cancellation w/ routes" do
      autotext_data = %{
        route_type: 4,
        effect_name: "Cancellation",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [],
        stops: [],
        direction: []
      }

      expected = "Affected ferries:\n1\n1\n1\n22\n22\n22"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "ferry cancellation w/ trips" do
      autotext_data = %{
        route_type: 4,
        effect_name: "Cancellation",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [@schedule_1, @schedule_2, @schedule_3],
        stops: [],
        direction: [0]
      }

      expected =
        "Cancelled westbound trips on 1:\n9:01 AM from South Station to Forest Hills\n9:01 AM from South Station to Forest Hills\n\nCancelled inbound trips on 22:\n11:15 AM from Forest Hills to South Station"

      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "ferry cancellation w/ direction" do
      autotext_data = %{
        route_type: 4,
        effect_name: "Cancellation",
        routes: [@route_1],
        schedules: [],
        stops: [],
        direction: [0]
      }

      expected =
        "Affected direction: westbound"

      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "ferry delay w/ routes" do
      autotext_data = %{
        route_type: 4,
        effect_name: "Delay",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [],
        stops: [],
        direction: [0]
      }

      expected = "Affected ferries:\n1\n1\n1\n22\n22\n22"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "ferry delay w/ trips and stops" do
      autotext_data = %{
        route_type: 4,
        effect_name: "Delay",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [@schedule_1, @schedule_2, @schedule_3],
        stops: [@stop_1, @stop_1, @stop_1],
        direction: [0]
      }

      expected =
        "Affected docks:\nLechmere\nLechmere\nLechmere\n\nDelayed westbound trips on 1:\n9:01 AM from South Station to Forest Hills\n9:01 AM from South Station to Forest Hills\n\nDelayed inbound trips on 22:\n11:15 AM from Forest Hills to South Station"

      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "ferry dock closure" do
      autotext_data = %{
        route_type: 4,
        effect_name: "Dock Closure",
        routes: [@route_1],
        schedules: [],
        stops: [@stop_1, @stop_1, @stop_1]
      }

      expected = "Affected ferries:\n1\n\nClosed docks:\nLechmere\nLechmere\nLechmere"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "ferry suspension" do
      autotext_data = %{
        route_type: 4,
        effect_name: "Suspension",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [],
        stops: [@stop_1]
      }

      expected = "Suspended ferries:\n1\n1\n1\n22\n22\n22\n\nAffected docks:\nLechmere"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    # bus
    test "bus delay" do
      autotext_data = %{
        route_type: 3,
        effect_name: "Delay",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [],
        stops: [@stop_1_bus],
        direction: []
      }

      expected = "Affected routes:\n1\n1\n1\n22\n22\n22\n\nAffected inbound stops:\nLechmere"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "bus detour" do
      autotext_data = %{
        route_type: 3,
        effect_name: "Detour",
        routes: [@route_1],
        schedules: [],
        stops: [],
        direction: [0]
      }

      expected = "Affected direction: westbound"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "bus multi-route detour" do
      autotext_data = %{
        route_type: 3,
        effect_name: "Multi-Route Detour",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [],
        stops: [@stop_1_bus],
        direction: []
      }

      expected = "Affected routes:\n1\n1\n1\n22\n22\n22\n\nSkipped inbound stops:\nLechmere"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "bus snow route" do
      autotext_data = %{
        route_type: 3,
        effect_name: "Snow Route",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [],
        stops: [@stop_1_bus],
        direction: [1]
      }

      expected = "Affected routes:\n1\n1\n1\n22\n22\n22\n\nSkipped inbound stops:\nLechmere"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "bus stop closure" do
      autotext_data = %{
        route_type: 3,
        effect_name: "Stop Closure",
        routes: [@route_1],
        schedules: [],
        stops: [@stop_1_bus, @stop_2_bus, @stop_1_bus],
        direction: [1]
      }

      expected =
        "Affected routes:\n1\n\nClosed outbound stops:\nLongwood Medical Area\n\nClosed inbound stops:\nLechmere"

      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "bus stop move" do
      autotext_data = %{
        route_type: 3,
        effect_name: "Stop Move",
        routes: [@route_1],
        schedules: [],
        stops: [@stop_1_bus],
        direction: [1]
      }

      expected = "Affected routes:\n1"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "bus suspension" do
      autotext_data = %{
        route_type: 3,
        effect_name: "Suspension",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [],
        stops: [],
        direction: [1]
      }

      expected = "Suspended routes:\n1\n1\n1\n22\n22\n22"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    # Commuter Rail
    test "CR cancellation" do
      autotext_data = %{
        route_type: 2,
        effect_name: "Cancellation",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [@schedule_1, @schedule_2, @schedule_3],
        stops: [],
        direction: [1]
      }

      expected =
        "Cancelled westbound trips on 1:\n527 (9:01 AM from South Station)\n528 (9:01 AM from South Station)\n\nCancelled inbound trips on 22:\n841 (11:15 AM from Forest Hills)"

      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "CR delay" do
      autotext_data = %{
        route_type: 2,
        effect_name: "Delay",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [],
        stops: [@stop_1],
        direction: [0, 1]
      }

      expected = "Affected lines:\n1\n1\n1\n22\n22\n22\n\nAffected stations:\nLechmere"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "CR shuttle" do
      autotext_data = %{
        route_type: 2,
        effect_name: "Shuttle",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [@schedule_1, @schedule_2, @schedule_3],
        stops: [@stop_1],
        direction: []
      }

      expected =
        "Affected stations:\nLechmere\n\nAffected westbound trips on 1:\n527 (9:01 AM from South Station)\n528 (9:01 AM from South Station)\n\nAffected inbound trips on 22:\n841 (11:15 AM from Forest Hills)"

      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "CR track change" do
      autotext_data = %{
        route_type: 2,
        effect_name: "Track Change",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [@schedule_1, @schedule_2, @schedule_3],
        stops: [@stop_1, @stop_2],
        direction: [1]
      }

      expected =
        "Affected westbound trips on 1:\n527 (9:01 AM from South Station)\n528 (9:01 AM from South Station)\n\nAffected inbound trips on 22:\n841 (11:15 AM from Forest Hills)"

      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    # subway

    test "subway delay" do
      autotext_data = %{
        route_type: 1,
        effect_name: "Delay",
        routes: [@route_1],
        schedules: [],
        stops: [@stop_1, @stop_2, @stop_1],
        direction: [1]
      }

      expected =
        "Affected stations:\nLechmere\nLongwood Medical Area\nLechmere"

      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "subway service change" do
      autotext_data = %{
        route_type: 1,
        effect_name: "Service Change",
        routes: [@route_1],
        schedules: [],
        stops: [@stop_1],
        direction: [1]
      }

      expected = "Affected direction: eastbound\n\nAffected stations:\nLechmere"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "subway shuttle" do
      autotext_data = %{
        route_type: 1,
        effect_name: "Shuttle",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [],
        stops: [@stop_1],
        direction: []
      }

      expected = "Affected lines:\n1\n1\n1\n22\n22\n22\n\nAffected stations:\nLechmere"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "subway single tracking" do
      autotext_data = %{
        route_type: 1,
        effect_name: "Single Tracking",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [],
        stops: [@stop_1],
        direction: []
      }

      expected = "Affected lines:\n1\n1\n1\n22\n22\n22\n\nAffected stations:\nLechmere"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "subway suspension" do
      autotext_data = %{
        route_type: 1,
        effect_name: "Suspension",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [],
        stops: [@stop_1],
        direction: []
      }

      expected = "Suspended lines:\n1\n1\n1\n22\n22\n22\n\nAffected stations:\nLechmere"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    # mode not specified
    test "dock issue" do
      autotext_data = %{
        route_type: 4,
        effect_name: "Dock Issue",
        routes: [@route_1],
        schedules: [],
        stops: [@stop_1, @stop_1, @stop_1]
      }

      expected = "Affected ferries:\n1\n\nAffected docks:\nLechmere\nLechmere\nLechmere"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "extra service" do
      autotext_data = %{
        route_type: 4,
        effect_name: "Extra Service",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [],
        stops: [@stop_1]
      }

      expected = "Affected ferries:\n1\n1\n1\n22\n22\n22"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "schedule change" do
      autotext_data = %{
        route_type: 4,
        effect_name: "Schedule Change",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [],
        stops: [@stop_1]
      }

      expected = "Affected ferries:\n1\n1\n1\n22\n22\n22"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "service change w/ routes" do
      autotext_data = %{
        route_type: 4,
        effect_name: "Service Change",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [],
        stops: [@stop_1]
      }

      expected = "Affected ferries:\n1\n1\n1\n22\n22\n22\n\nAffected docks:\nLechmere"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "service change w/ trips and stops" do
      autotext_data = %{
        route_type: 4,
        effect_name: "Service Change",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [@schedule_1, @schedule_2, @schedule_3],
        stops: [@stop_1]
      }

      expected =
        "Affected docks:\nLechmere\n\nAffected westbound trips on 1:\n9:01 AM from South Station to Forest Hills\n9:01 AM from South Station to Forest Hills\n\nAffected inbound trips on 22:\n11:15 AM from Forest Hills to South Station"

      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "shuttle" do
      autotext_data = %{
        route_type: 4,
        effect_name: "Shuttle",
        routes: [@route_1, @route_2, @route_1, @route_2, @route_1, @route_2],
        schedules: [],
        stops: [@stop_1]
      }

      expected = "Affected ferries:\n1\n1\n1\n22\n22\n22\n\nAffected docks:\nLechmere"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "station issue" do
      autotext_data = %{
        route_type: 2,
        effect_name: "Station Issue",
        routes: [@route_1],
        schedules: [],
        stops: [@stop_1, @stop_2, @stop_2],
        direction: []
      }

      expected =
        "Affected lines:\n1\n\nAffected stations:\nLechmere\nLongwood Medical Area\nLongwood Medical Area"

      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end

    test "suspension" do
      autotext_data = %{
        route_type: 2,
        effect_name: "Suspension",
        routes: [@route_1],
        schedules: [],
        stops: [@stop_1, @stop_2, @stop_2],
        direction: []
      }

      expected = "Affected stations:\nLechmere\nLongwood Medical Area\nLongwood Medical Area"
      actual = Templates.build_auto_text(autotext_data, :description_template)
      assert expected == actual
    end
  end
end
