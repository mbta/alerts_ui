defmodule AlertsUI.AlertBuilderTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.AlertBuilder

  describe "build_alert/1" do
    test "builds alert from map" do
      insert(:alert, alert_id: "1")

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
               alert_id: "2",
               informed_entity: [%{route_type: 1}],
               effect_detail: "DELAY"
             }
    end
  end
end
