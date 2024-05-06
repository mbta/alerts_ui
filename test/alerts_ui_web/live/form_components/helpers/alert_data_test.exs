defmodule AlertsUIWeb.FormComponents.Helpers.AlertDataTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  alias AlertsUIWeb.FormComponents.Helpers.AlertData

  describe "build_alert_data/1" do
    test "it returns empty map given nil" do
      assert AlertData.build_alert_data(nil) == %AlertData{}
    end

    test "works if informed entities empty" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: []
      })

      assert AlertData.build_alert_data("1") == %AlertData{
               combination: nil,
               direction: nil,
               effect_name: "Access Issue",
               route_type: nil,
               route_ids: [],
               stop_ids: [],
               trip_ids: [],
               header_text: "cool header text",
               description_text: "description text",
               service_types: []
             }
    end

    test "handles directions correctly" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [
          %{route_type: 1, route_id: "1", direction_id: 0},
          %{route_type: 1, route_id: "2", stop_id: "a2", direction_id: 0},
          %{route_type: 1, route_id: "3", stop_id: "a3", direction_id: 1},
          %{route_type: 1, route_id: "4", trip: build(:trip_descriptor, %{trip_id: "b1"})}
        ]
      })

      assert AlertData.build_alert_data("1") == %AlertData{
               combination: :RDTS,
               direction: nil,
               effect_name: "Access Issue",
               route_type: 1,
               route_ids: ["1", "2", "3", "4"],
               stop_ids: ["a2", "a3"],
               trip_ids: ["b1"],
               header_text: "cool header text",
               description_text: "description text",
               service_types: []
             }
    end

    test "builds alert data from alert" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end: ~U[2024-05-04 01:09:34.007545Z],
        active_period: [
          %{start: ~U[2024-05-02 16:09:34.007545Z], end: ~U[2024-05-04 01:09:34.007545Z]}
        ],
        duration_certainty: :KNOWN,
        informed_entity: [
          %{route_type: 3, route_id: "1", direction_id: 0},
          %{route_type: 3, route_id: "2", stop_id: "a2"},
          %{route_type: 3, route_id: "3", stop_id: "a3", direction_id: 0},
          %{route_type: 3, route_id: "4", trip: build(:trip_descriptor, %{trip_id: "b1"})}
        ]
      })

      assert AlertData.build_alert_data("1") == %AlertData{
               combination: :RDTS,
               direction: "0",
               effect_name: "Access Issue",
               route_type: 3,
               route_ids: ["1", "2", "3", "4"],
               stop_ids: ["a2", "a3"],
               trip_ids: ["b1"],
               header_text: "cool header text",
               description_text: "description text",
               active_period_end_specifier: :pick_a_date_and_time,
               active_period_end: ~N[2024-05-03 21:09:34],
               active_period_start: ~N[2024-05-02 12:09:34],
               service_types: []
             }
    end

    test "builds data for a systemwide alert" do
      insert(:alert, %{
        alert_id: "1",
        effect: :SIGNIFICANT_DELAYS,
        effect_detail: "DELAY",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [
          %{route_type: 3}
        ]
      })

      assert AlertData.build_alert_data("1") == %AlertData{
               combination: nil,
               effect_name: "Delay",
               service_types: [3],
               route_ids: [],
               stop_ids: [],
               trip_ids: [],
               header_text: "cool header text",
               description_text: "description text"
             }
    end

    test "builds data for a systemwide alert affecting the subway" do
      insert(:alert, %{
        alert_id: "1",
        effect: :SIGNIFICANT_DELAYS,
        effect_detail: "DELAY",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [
          %{route_type: 0},
          %{route_type: 1},
          %{route_type: 3}
        ]
      })

      assert AlertData.build_alert_data("1") == %AlertData{
               combination: nil,
               effect_name: "Delay",
               service_types: [1, 3],
               route_ids: [],
               stop_ids: [],
               trip_ids: [],
               header_text: "cool header text",
               description_text: "description text"
             }
    end

    test "handles unknown duration" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [],
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end: nil,
        active_period: [%{start: ~U[2024-05-02 16:09:34.007545Z], end: nil}],
        duration_certainty: :UNKNOWN
      })

      assert AlertData.build_alert_data("1").active_period_end_specifier == :further_notice
    end

    test "handles estimated duration" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [],
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end: nil,
        active_period: [%{start: ~U[2024-05-02 16:09:34.007545Z], end: nil}],
        duration_certainty: :ESTIMATED
      })

      assert AlertData.build_alert_data("1").active_period_end_specifier == :later_today
    end

    test "handles known end-of-service duration" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [],
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end: ~U[2024-05-03 06:30:00.007545Z],
        active_period: [
          %{start: ~U[2024-05-02 16:09:34.007545Z], end: ~U[2024-05-03 06:30:00.007545Z]}
        ],
        duration_certainty: :KNOWN
      })

      assert AlertData.build_alert_data("1").active_period_end_specifier == :end_of_service_today
    end
  end
end
