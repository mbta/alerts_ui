defmodule AlertsUIWeb.AlertHistoryTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory

  alias AlertsUI.{AlertHistory, Alerts}

  describe "alert_history/1" do
    test "returns mapped alert versions" do
      user =
        insert(:user, %{
          first_name: "Herbert",
          last_name: "Pocket"
        })

      original_alert_map =
        build(
          :alert_map,
          %{
            alert_id: "123",
            header_text: "old header text",
            description_text: "its snowing",
            user: user,
            effect_name: "Snow Route",
            effect: :DETOUR,
            effect_detail: "SNOW_ROUTE",
            active_period: [
              %{start: ~U[2025-09-25 12:11:00Z], end: ~U[2025-09-25 17:11:00Z]}
            ],
            active_period_start: ~U[2025-09-25 12:11:00Z],
            active_period_end: ~U[2025-09-25 17:11:00Z],
            notification_period_end: ~U[2025-09-25 17:11:00Z],
            duration_certainty: :ESTIMATED,
            severity: 1,
            severity_level: :INFO
          }
        )

      new_params_one =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "old header text",
          description_text: "its snowing",
          user: user,
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
          notification_period_start: ~U[2025-09-25 11:11:00Z],
          notification_period_end: ~U[2025-09-25 17:11:00Z],
          duration_certainty: :KNOWN,
          severity: 1,
          severity_level: :INFO,
          url: "http://example.com",
          image_url: "http://example.com/image.jpg",
          image_alternative_text: "example image",
          banner_text: "the banner text"
        })

      Alerts.create_or_update_alert(original_alert_map, user)

      Alerts.create_or_update_alert(new_params_one, user, Alerts.get_by_alert_id("123"))

      Alerts.close(Alerts.get_by_alert_id("123"), "closed", ~U[2025-09-26 16:14:00Z])

      [result_1, result_2, result_3] = AlertHistory.alert_history("123")

      assert %{
               alert_id: "123",
               version: 1,
               closed: false,
               last_modified_by: "Herbert Pocket",
               service_type: nil,
               effect_name: "Snow Route",
               effect: "DETOUR",
               effect_detail: "SNOW_ROUTE",
               affected_entities: nil,
               recurrence: false,
               effect_start: "2025-09-25T08:11",
               effect_end: "later today",
               recurrence_days: "",
               recurrence_start_time: "",
               recurrence_end_time: "",
               notification_start: "",
               notification_end: "2025-09-25T13:11",
               duration_certainty: "ESTIMATED",
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
               reminders: nil
             } = result_1

      assert %{
               alert_id: "123",
               version: 2,
               closed: false,
               last_modified_by: "Herbert Pocket",
               service_type: nil,
               effect_name: "Snow Route",
               effect: "DETOUR",
               effect_detail: "SNOW_ROUTE",
               affected_entities: nil,
               recurrence: true,
               effect_start: "2025-09-25T08:11",
               effect_end: "2025-09-26T13:11",
               recurrence_days: "Thursday, Friday",
               recurrence_start_time: "8:11",
               recurrence_end_time: "13:11",
               notification_start: "2025-09-25T07:11",
               notification_end: "2025-09-25T13:11",
               duration_certainty: "KNOWN",
               severity_code: 1,
               severity_level: "INFO",
               severity_name: "information",
               main_message: "old header text",
               supporting_information: "its snowing",
               url: "http://example.com",
               image_url: "http://example.com/image.jpg",
               image_alternative_text: "example image",
               set_as_website_banner: true,
               website_banner_text: "the banner text",
               reminders: nil
             } = result_2

      assert %{
               alert_id: "123",
               version: 3,
               closed: true,
               last_modified_by: "closed",
               service_type: nil,
               effect_name: "Snow Route",
               effect: "DETOUR",
               effect_detail: "SNOW_ROUTE",
               affected_entities: nil,
               recurrence: true,
               effect_start: "2025-09-25T08:11",
               effect_end: "2025-09-26T12:14",
               recurrence_days: "Thursday, Friday",
               recurrence_start_time: "8:11",
               recurrence_end_time: "12:14",
               notification_start: "2025-09-25T07:11",
               notification_end: "2025-09-26T12:14",
               duration_certainty: "KNOWN",
               severity_code: 1,
               severity_level: "INFO",
               severity_name: "information",
               main_message: "old header text",
               supporting_information: "its snowing",
               url: "http://example.com",
               image_url: "http://example.com/image.jpg",
               image_alternative_text: "example image",
               set_as_website_banner: true,
               website_banner_text: "the banner text",
               reminders: nil
             } = result_3
    end
  end
end
