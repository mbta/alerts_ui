defmodule AlertsUI.AlertBuilderTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.AlertBuilder
  alias AlertsUI.Alerts

  describe "build_alert/1" do
    test "builds alert from map" do
      existing_alert = insert(:alert, alert_id: "0")

      alert_data = %{
        route_type: 1,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay"
      }

      result = AlertBuilder.build_alert(alert_data)

      assert result == %{
               effect: :SIGNIFICANT_DELAYS,
               description_text: "ok",
               header_text: "hello",
               informed_entity: [%{route_type: 1}],
               effect_detail: "DELAY",
               draft: false
             }

      result |> Alerts.create_alert()
      [alert_1, alert_2] = Alerts.list_all()
      assert alert_1.alert_id == existing_alert.alert_id
      assert alert_2.alert_id |> String.to_integer() > alert_1.alert_id |> String.to_integer()
    end
  end
end
