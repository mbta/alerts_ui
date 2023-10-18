defmodule AlertsUI.AlertsTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  alias AlertsUI.Alerts

  describe "create_alert/1" do
    test "stores valid alert" do
      alert = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
      }

      Alerts.create_alert(alert)
      actual_alerts = Alerts.list_all_alerts()
      assert length(actual_alerts) == 1
    end

    test "only stores alerts with unique ids" do
      alert = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        informed_entity: [
          %{
            route_id: "1",
            trip: %{trip_id: "2", start_time: %{relative_day: 1, time: ~T[01:01:01]}}
          }
        ]
      }

      Alerts.create_alert(alert)
      assert length(Alerts.list_all_alerts()) == 1
      Alerts.create_alert(alert)
      assert length(Alerts.list_all_alerts()) == 1
    end
  end
end
