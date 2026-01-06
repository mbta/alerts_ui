defmodule AlertsUIWeb.PredictionSuppressionWarningModalTest do
  use ExUnit.Case, async: true

  import AlertsUIWeb.PredictionSuppressionWarningModal

  alias AlertsUI.Models.InformedEntity
  alias MBTAV3API.Routes.Route

  @route_one %Route{sort_order: 1, id: "1", name: "bus route 1"}
  @route_two %Route{sort_order: 2, id: "2", name: "route 2"}
  @routes [@route_one, @route_two]

  describe "show_warning?/1" do
    test "returns true if the alert is predictable and does not have info" do
      alert_data = %{
        combination: :RDTS,
        route_type: InformedEntity.route_type_mapping(:commuter_rail),
        route_ids: ["CR-Lowell"],
        effect_name: "Shuttle"
      }

      assert show_warning?(alert_data) == true
    end

    test "returns false if no route is selected" do
      alert_data = %{
        combination: :RDTS,
        route_type: InformedEntity.route_type_mapping(:commuter_rail),
        effect_name: "Shuttle"
      }

      assert show_warning?(alert_data) == false
    end

    test "returns false if the alert is predictable but has info" do
      alert_data = %{
        combination: :RDTS,
        route_type: InformedEntity.route_type_mapping(:commuter_rail),
        route_ids: ["CR-Lowell"],
        effect_name: "Shuttle",
        trip_ids: ["1"],
        stop_ids: ["1"]
      }

      assert show_warning?(alert_data) == false
    end

    test "returns false if the alert is not predictable but has no info" do
      alert_data = %{
        combination: :RDTS,
        route_type: InformedEntity.route_type_mapping(:commuter_rail),
        route_ids: ["CR-Lowell"],
        effect_name: "Delay"
      }

      assert show_warning?(alert_data) == false
    end
  end

  describe "warning_message/2" do
    test "RDTS alerts with 0 trips and 0 stops" do
      alert_data = %{
        combination: :RDTS,
        route_ids: ["CR-Lowell"],
        route_type: InformedEntity.route_type_mapping(:commuter_rail)
      }

      assert warning_message(alert_data, @routes) ==
               "There are no trips or stops selected. This will suppress predictions for all trips and stops on the bus route 1 and route 2. Do you still want to continue?"
    end

    test "RDTS alerts with 1 trips and 0 stops" do
      alert_data = %{
        combination: :RDTS,
        route_ids: ["CR-Lowell"],
        route_type: InformedEntity.route_type_mapping(:commuter_rail),
        trip_ids: ["1"]
      }

      assert warning_message(alert_data, @routes) ==
               "There are no stops selected. This will suppress predictions for this trip at all stops on the bus route 1 and route 2. Do you still want to continue?"
    end

    test "RDTS alerts with 2+ trips and 0 stops" do
      alert_data = %{
        combination: :RDTS,
        route_ids: ["CR-Lowell"],
        route_type: InformedEntity.route_type_mapping(:commuter_rail),
        trip_ids: ["1", "2"]
      }

      assert warning_message(alert_data, @routes) ==
               "There are no stops selected. This will suppress predictions for these trips at all stops on the bus route 1 and route 2. Do you still want to continue?"
    end

    test "RDTS alerts with 0 trips and 1 stop" do
      alert_data = %{
        combination: :RDTS,
        route_ids: ["CR-Lowell"],
        route_type: InformedEntity.route_type_mapping(:commuter_rail),
        stop_ids: ["1"]
      }

      assert warning_message(alert_data, @routes) ==
               "There are no trips selected. This will suppress predictions at this stop for all trips on the bus route 1 and route 2. Do you still want to continue?"
    end

    test "RDTS alerts with 0 trips and 2+ stops" do
      alert_data = %{
        combination: :RDTS,
        route_ids: ["CR-Lowell"],
        route_type: InformedEntity.route_type_mapping(:commuter_rail),
        stop_ids: ["1", "2"]
      }

      assert warning_message(alert_data, @routes) ==
               "There are no trips selected. This will suppress predictions at these stops for all trips on the bus route 1 and route 2. Do you still want to continue?"
    end

    test "RDT alerts with 0 trips" do
      alert_data = %{
        combination: :RDT,
        route_ids: ["CR-Lowell"],
        route_type: InformedEntity.route_type_mapping(:commuter_rail),
        trip_ids: []
      }

      assert warning_message(alert_data, @routes) ==
               "There are no trips selected. This will suppress predictions for all trips on the bus route 1 and route 2. Do you still want to continue?"
    end

    test "RDS alerts with 0 stops" do
      alert_data = %{
        combination: :RDS,
        route_ids: ["CR-Lowell"],
        route_type: InformedEntity.route_type_mapping(:commuter_rail),
        stop_ids: []
      }

      assert warning_message(alert_data, @routes) ==
               "There are no stops selected. This will suppress predictions at all stops on the bus route 1 and route 2. Do you still want to continue?"
    end
  end
end
