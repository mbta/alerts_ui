defmodule AlertsUIWeb.AlertHistoryTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory

  alias AlertsUI.{AlertHistory, Alerts}

  @first_alert_params %{
    alert_id: "123",
    header_text: "old header text",
    description_text: "its snowing",
    effect_name: "Snow Route",
    effect: :DETOUR,
    effect_detail: "SNOW_ROUTE",
    active_period: [
      %{start: ~U[2025-09-25 12:11:00Z], end: ~U[2025-09-25 17:11:00Z]}
    ],
    recurrence_days: [],
    active_period_start: ~U[2025-09-25 12:11:00Z],
    active_period_end: ~U[2025-09-25 17:11:00Z],
    notification_period_end: ~U[2025-09-25 17:11:00Z],
    original_stop_selections: ["Alewife|place-alfcl", "Davis|place-davis"],
    original_route_selections: ["Red Line|Red"],
    original_direction_selections: ["Both|default"],
    duration_certainty: :ESTIMATED,
    severity: 1,
    severity_level: :INFO
  }

  @second_alert_params %{
    alert_id: "123",
    header_text: "new header text",
    description_text: "its snowing",
    effect_name: "Snow Route",
    effect: :DETOUR,
    effect_detail: "SNOW_ROUTE",
    active_period: [
      %{start: ~U[2025-09-25 12:11:00Z], end: ~U[2025-09-25 17:11:00Z]},
      %{start: ~U[2025-09-26 12:11:00Z], end: ~U[2025-09-26 17:11:00Z]}
    ],
    recurrence_days: ["thursday", "friday"],
    active_period_start: ~U[2025-09-25 12:11:00Z],
    active_period_end: ~U[2025-09-26 17:11:00Z],
    recurrence_start_time: ~T[08:11:00],
    recurrence_end_time: ~T[13:11:00],
    notification_period_start: ~U[2025-09-25 11:11:00Z],
    notification_period_end: ~U[2025-09-25 17:11:00Z],
    original_stop_selections: ["Wonderland|place-wondl", "Revere Beach|place-rbmnl"],
    original_route_selections: ["Blue Line|Blue"],
    original_trip_selections: [
      "2061 (10:58 AM from East Taunton)|Sept8Read-767871-2061",
      "1976 (11:43 AM from Fall River Depot)|Sept8Read-767952-1976"
    ],
    original_direction_selections: ["Both|default"],
    duration_certainty: :KNOWN,
    cause: :WEATHER,
    cause_detail: "SNOW",
    severity: 1,
    severity_level: :INFO,
    url: "http://example.com",
    image_url: "http://example.com/image.jpg",
    image_alternative_text: "example image",
    banner_text: "the banner text",
    plaintext_reminder_selections: "2024-04-30T12:04:00, 2024-04-30T12:14:00, 2024-04-30T12:24:00"
  }

  describe "alert_history/1" do
    test "returns empty list if alert not found" do
      assert AlertHistory.alert_history("0") == []
    end

    test "returns mapped alert versions" do
      user =
        insert(:user, %{
          first_name: "Herbert",
          last_name: "Pocket"
        })

      Alerts.create_or_update_alert(
        build(
          :alert_map,
          @first_alert_params
        ),
        user
      )

      :timer.sleep(1000)

      Alerts.create_or_update_alert(
        build(:alert_map, @second_alert_params),
        user,
        Alerts.get_by_alert_id("123")
      )

      :timer.sleep(1000)
      Alerts.close(Alerts.get_by_alert_id("123"), "closed", false, ~U[2025-09-26 16:14:00Z])

      [result_1, result_2, result_3] = AlertHistory.alert_history("123")

      assert %{
               alert_id: "123",
               version: 1,
               closed: false,
               last_modified_by: "Herbert Pocket",
               service_type: "Subway",
               effect_name: "Snow Route",
               effect: "DETOUR",
               effect_detail: "SNOW_ROUTE",
               affected_entities: "Routes: Red Line; Stops: Alewife, Davis; Direction: Both",
               recurrence: false,
               effect_start: "2025-09-25T08:11",
               effect_end: "later today",
               recurrence_days: "",
               recurrence_start_time: "",
               recurrence_end_time: "",
               notification_start: "",
               notification_end: "2025-09-25T13:11",
               duration_certainty: "ESTIMATED",
               cause: "UNKNOWN_CAUSE",
               cause_detail: "UNKNOWN_CAUSE",
               severity_code: 1,
               severity_level: "INFO",
               severity_name: "information",
               main_message: "old header text",
               supporting_information: "its snowing",
               url: "",
               image_url: "",
               image_alternative_text: "",
               set_as_website_banner: false,
               website_banner_text: "",
               reminders: ""
             } = result_1

      assert %{
               alert_id: "123",
               version: 2,
               closed: false,
               last_modified_by: "Herbert Pocket",
               service_type: "Subway",
               effect_name: "Snow Route",
               effect: "DETOUR",
               effect_detail: "SNOW_ROUTE",
               affected_entities:
                 "Routes: Blue Line; Stops: Wonderland, Revere Beach; Direction: Both; Trips: 2061 (10:58 AM from East Taunton), 1976 (11:43 AM from Fall River Depot)",
               recurrence: true,
               effect_start: "2025-09-25T08:11",
               effect_end: "2025-09-26T13:11",
               recurrence_days: "Thursday,Friday",
               recurrence_start_time: "8:11",
               recurrence_end_time: "13:11",
               notification_start: "2025-09-25T07:11",
               notification_end: "2025-09-25T13:11",
               duration_certainty: "KNOWN",
               cause: "WEATHER",
               cause_detail: "SNOW",
               severity_code: 1,
               severity_level: "INFO",
               severity_name: "information",
               main_message: "new header text",
               supporting_information: "its snowing",
               url: "http://example.com",
               image_url: "http://example.com/image.jpg",
               image_alternative_text: "example image",
               set_as_website_banner: true,
               website_banner_text: "the banner text",
               reminders: "2024-04-30T12:04:00, 2024-04-30T12:14:00, 2024-04-30T12:24:00"
             } = result_2

      assert %{
               alert_id: "123",
               version: 3,
               closed: true,
               last_modified_by: "closed",
               service_type: "Subway",
               effect_name: "Snow Route",
               effect: "DETOUR",
               effect_detail: "SNOW_ROUTE",
               affected_entities:
                 "Routes: Blue Line; Stops: Wonderland, Revere Beach; Direction: Both; Trips: 2061 (10:58 AM from East Taunton), 1976 (11:43 AM from Fall River Depot)",
               recurrence: true,
               effect_start: "2025-09-25T08:11",
               effect_end: "2025-09-26T12:14",
               recurrence_days: "Thursday,Friday",
               recurrence_start_time: "8:11",
               recurrence_end_time: "13:11",
               notification_start: "2025-09-25T07:11",
               notification_end: "2025-09-26T12:14",
               duration_certainty: "KNOWN",
               cause: "WEATHER",
               cause_detail: "SNOW",
               severity_code: 1,
               severity_level: "INFO",
               severity_name: "information",
               main_message: "new header text",
               supporting_information: "its snowing",
               url: "http://example.com",
               image_url: "http://example.com/image.jpg",
               image_alternative_text: "example image",
               set_as_website_banner: true,
               website_banner_text: "the banner text",
               reminders: "2024-04-30T12:04:00, 2024-04-30T12:14:00, 2024-04-30T12:24:00"
             } = result_3

      {:ok, last_modified_datetime_1, _} =
        DateTime.from_iso8601(result_1.last_modified_datetime <> "Z")

      {:ok, last_modified_datetime_2, _} =
        DateTime.from_iso8601(result_2.last_modified_datetime <> "Z")

      assert DateTime.compare(last_modified_datetime_2, last_modified_datetime_1) == :gt
    end
  end

  describe "build_history_csv/1" do
    test "returns correct csv" do
      user =
        insert(:user, %{
          first_name: "Herbert",
          last_name: "Pocket"
        })

      Alerts.create_or_update_alert(
        build(
          :alert_map,
          @first_alert_params
        ),
        user
      )

      Alerts.create_or_update_alert(
        build(:alert_map, @second_alert_params),
        user,
        Alerts.get_by_alert_id("123")
      )

      Alerts.close(Alerts.get_by_alert_id("123"), "closed", false, ~U[2025-09-27 16:33:00Z])

      [headers, v1, v2, v3] =
        "123" |> AlertHistory.alert_history() |> AlertHistory.build_history_csv()

      assert headers == AlertHistory.build_headers()

      MapSet.subset?(MapSet.new(v1), MapSet.new(["123", "1", "old header text", "ESTIMATED"]))
      MapSet.subset?(MapSet.new(v2), MapSet.new(["123", "2", "new header text", "KNOWN"]))

      MapSet.subset?(
        MapSet.new(v3),
        MapSet.new(["123", "3", "new header text", "KNOWN", "2025-09-27T12:33"])
      )
    end
  end
end
