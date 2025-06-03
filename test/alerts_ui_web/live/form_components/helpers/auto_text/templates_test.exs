defmodule AlertsUIWeb.FormComponents.Helpers.AutoText.TemplatesTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.FormComponents.Helpers.AutoText.Templates
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Stop

  @facility %Facility{
    id: "952",
    type: "ELEVATOR",
    short_name: "Alewife platform to lobby",
    long_name: "Charles/MGH Elevator 952 (Alewife platform to lobby)"
  }

  @route_1 %Route{id: "1", name: "1", direction_names: %{0 => "Westbound", 1 => "Eastbound"}}
  @stop_1 %Stop{id: "place-lech", name: "Lechmere"}

  @schedule_1 %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683300-527", name: "527", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    departure_time: ~U[2024-02-21 14:01:00.00Z]
  }

  describe "build_auto_text/2" do
    # access
    test "access alert bike issue" do
      autotext_data = %{
        facility: @facility,
        combination: :ACCESS,
        route_type: nil,
        effect_name: "Bike Issue",
        cause_detail: "HOLIDAY",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected =
        "Charles/MGH Elevator 952 (Alewife platform to lobby) issue today due to the holiday"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "access alert escalator closure" do
      autotext_data = %{
        facility: @facility,
        combination: :ACCESS,
        route_type: nil,
        effect_name: "Escalator Closure",
        cause_detail: "HOLIDAY",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected =
        "Charles/MGH Elevator 952 (Alewife platform to lobby) unavailable today due to the holiday"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "access alert parking closure" do
      autotext_data = %{
        facility: @facility,
        combination: :ACCESS,
        route_type: nil,
        effect_name: "Parking Closure",
        cause_detail: "HOLIDAY",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected =
        "Charles/MGH Elevator 952 (Alewife platform to lobby) closed today due to the holiday"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "access alert elevator closure" do
      autotext_data = %{
        facility: @facility,
        combination: :ACCESS,
        route_type: nil,
        effect_name: "Elevator Closure",
        cause_detail: "HOLIDAY",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected =
        "Charles/MGH Elevator 952 (Alewife platform to lobby) unavailable today due to the holiday"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "access alert access issue" do
      autotext_data = %{
        facility: @facility,
        combination: :ACCESS,
        route_type: nil,
        effect_name: "Access Issue",
        cause_detail: "HOLIDAY",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected =
        "Charles/MGH Elevator 952 (Alewife platform to lobby) issue today due to the holiday"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "access alert facility issue" do
      autotext_data = %{
        facility: @facility,
        route_type: nil,
        effect_name: "Facility Issue",
        cause_detail: "HOLIDAY",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected =
        "Charles/MGH Elevator 952 (Alewife platform to lobby) issue today due to the holiday"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "access alert parking issue" do
      autotext_data = %{
        facility: @facility,
        route_type: nil,
        effect_name: "Parking Issue",
        cause_detail: "HOLIDAY",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected =
        "Charles/MGH Elevator 952 (Alewife platform to lobby) issue today due to the holiday"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
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

      expected =
        "Ferry and Commuter Rail notice: until Sat, May 10 due to a slippery rail"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
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

      expected =
        "Ferry and Commuter Rail service suspended until Sat, May 10 due to a slippery rail"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "systemwide alert amber alert issue" do
      autotext_data = %{
        route_type: nil,
        effect_name: "Amber Alert"
      }

      expected =
        "Amber Alert"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "systemwide alert policy change issue" do
      autotext_data = %{
        route_type: nil,
        service_types: [4, 2],
        effect_name: "Policy Change"
      }

      expected =
        "Policy change affecting Ferry and Commuter Rail service"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
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

      expected =
        "Ferry and Commuter Rail service may experience delays until Sat, May 10 due to a slippery rail"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
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

      expected =
        "Ferry and Commuter Rail notice until Sat, May 10 due to a slippery rail"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
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

      expected =
        "Planned Ferry and Commuter Rail schedule change until Sat, May 10 due to a slippery rail"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
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

      expected =
        "Extra Ferry and Commuter Rail service until Sat, May 10 due to a slippery rail"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    # ferry
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

      expected =
        "Lechmere closed until Sat, May 10 due to an unruly passenger"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "Ferry suspension" do
      autotext_data = %{
        route_type: 4,
        routes: [@route_1],
        effect_name: "Suspension",
        cause_detail: "UNRULY_PASSENGER",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected =
        "Route 1 suspended until Sat, May 10 due to an unruly passenger"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
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

      expected =
        "Route 1 trip 527 (9:01 AM from South Station) cancelled until Sat, May 10 due to an unruly passenger"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
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

      expected =
        "Route 1 trip 527 (9:01 AM from South Station) operation about 10 minutes late until Sat, May 10 due to an unruly passenger"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    # Bus
    test "Bus cancellation" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        schedules: [@schedule_1],
        effect_name: "Cancellation",
        cause_detail: "PARADE",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected =
        "Route 1 - 527 (9:01 AM from South Station) cancelled until Sat, May 10 due to a parade"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

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

      expected = "The following stop is closed until Sat, May 10 due to a parade: Lechmere"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "Bus stop shovelling" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        stops: [@stop_1],
        effect_name: "Stop Shovelling",
        direction: [0],
        cause_detail: "PARADE",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected =
        "Route 1 westbound bus stops have been cleared of snow until Sat, May 10 due to a parade"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "Bus delay" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        stops: [@stop_1],
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

      expected = "Route 1 is experiencing eastbound delays of about 10 minutes due to a parade"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "Bus suspension" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        stops: [@stop_1],
        effect_name: "Suspension",
        direction: [1],
        cause_detail: "PARADE",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected = "Route 1 eastbound suspended until Sat, May 10 due to a parade"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "Bus multi-route detour" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        stops: [@stop_1],
        effect_name: "Multi-Route Detour",
        cause_detail: "PARADE",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected = "Route 1 detoured until Sat, May 10 due to a parade"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
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

      expected = "Lechmere stop moving until Sat, May 10 due to a parade"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "Bus detour" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        effect_name: "Detour",
        cause_detail: "PARADE",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected = "Route 1 detoured until Sat, May 10 due to a parade"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "Bus snow route" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        effect_name: "Snow Route",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected = "Route 1 snow route in effect until Sat, May 10"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    # subway

    test "Subway suspension" do
      autotext_data = %{
        route_type: 1,
        routes: [@route_1],
        direction: [0],
        effect_name: "Suspension",
        cause_detail: "ICE_IN_HARBOR",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected = "Route 1: westbound service is suspended until Sat, May 10 due to ice in harbor"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "Subway delay" do
      autotext_data = %{
        route_type: 1,
        routes: [@route_1],
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

      expected = "Route 1: westbound delays of about 10 minutes due to ice in harbor"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "Subway service change" do
      autotext_data = %{
        route_type: 1,
        routes: [@route_1],
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

      expected = "Route 1: until Sat, May 10 due to ice in harbor"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "Subway shuttle" do
      autotext_data = %{
        route_type: 1,
        routes: [@route_1],
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

      expected =
        "Route 1: Shuttle buses replace westbound service until Sat, May 10 due to ice in harbor"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    # Commuter Rail

    test "CR Delay" do
      autotext_data = %{
        route_type: 2,
        routes: [@route_1],
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

      expected =
        "Route 1 train 527 (9:01 AM from South Station) trip is operating about 10 minutes behind schedule until Sat, May 10 due to a hazmat condition"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "CR Shuttle" do
      autotext_data = %{
        route_type: 2,
        routes: [@route_1],
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

      expected =
        "Route 1 westbound train 527 (9:01 AM from South Station) will be replaced by a shuttle bus until Sat, May 10 due to a hazmat condition"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "CR Track Change" do
      autotext_data = %{
        route_type: 2,
        routes: [@route_1],
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

      expected =
        "Please board Route 1 train 527 (9:01 AM from South Station) on opposite track until Sat, May 10 due to a hazmat condition"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
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

      expected =
        "Route 1 train 527 (9:01 AM from South Station) trip is cancelled until Sat, May 10 due to a hazmat condition"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
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

      expected =
        "Route 1 notice: train 527 (9:01 AM from South Station) until Sat, May 10 due to a hazmat condition"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    # mode not specified
    test "Service change" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        effect_name: "Service Change",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected =
        "Route 1 notice: until Sat, May 10 due to a slippery rail"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "Dock issue" do
      autotext_data = %{
        route_type: 3,
        stops: [@stop_1],
        effect_name: "Dock Issue",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected =
        "Change at Lechmere until Sat, May 10 due to a slippery rail"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "Shuttle" do
      autotext_data = %{
        route_type: 3,
        routes: [@route_1],
        direction: [1],
        effect_name: "Shuttle",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected =
        "Shuttle buses replacing Route 1 eastbound service until Sat, May 10 due to a slippery rail"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "Suspension" do
      autotext_data = %{
        route_type: 2,
        routes: [@route_1],
        direction: [1],
        effect_name: "Suspension",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected =
        "Route 1 eastbound service suspended until Sat, May 10 due to a slippery rail"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "Extra service" do
      autotext_data = %{
        route_type: 2,
        routes: [@route_1],
        effect_name: "Extra Service",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected =
        "Extra service on Route 1 until Sat, May 10 due to a slippery rail"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
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

      expected =
        "Lechmere closed until Sat, May 10 due to a slippery rail"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
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

      expected =
        "Route 1 trip 527 (9:01 AM from South Station) experiencing delays of about 10 minutes until Sat, May 10 due to a slippery rail"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
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

      expected =
        "Planned schedule change on Route 1 until Sat, May 10 due to a slippery rail"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end

    test "Station issue" do
      autotext_data = %{
        route_type: 2,
        stops: [@stop_1],
        schedules: [@schedule_1],
        effect_name: "Station Issue",
        cause_detail: "SLIPPERY_RAIL",
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected = "Change at Lechmere until Sat, May 10 due to a slippery rail"

      actual = Templates.build_auto_text(autotext_data, :header_template)
      assert expected == actual
    end
  end
end
