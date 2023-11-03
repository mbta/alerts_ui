defmodule AlertsUI.AlertsTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.Alerts

  describe "create_alert/1" do
    test "stores valid alert" do
      before_alerts_length = Alerts.list_all() |> length

      alert = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
      }

      Alerts.create_alert(alert)
      assert length(Alerts.list_all()) - before_alerts_length == 1
    end

    @tag :capture_log
    test "does not store invalid alert" do
      before_alerts_length = Alerts.list_all() |> length

      alert = %{
        description_text: "b",
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
      }

      Alerts.create_alert(alert)
      assert length(Alerts.list_all()) - before_alerts_length == 0
    end

    test "only stores alerts with unique ids" do
      before_alerts_length = Alerts.list_all() |> length

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
      assert length(Alerts.list_all()) - before_alerts_length == 1
      Alerts.create_alert(alert)
      assert length(Alerts.list_all()) - before_alerts_length == 1
    end
  end

  describe "list_all_versions/1" do
    test "list versions of alerts given alert id" do
      insert(:alert, %{alert_id: "123"})
      insert(:alert, %{alert_id: "123"})

      [result1, result2] = Alerts.list_all_versions("123")
      assert result1.alert_id == "123"
      assert result2.alert_id == "123"
    end

    test "list alerts given alert id" do
      created_alert = insert(:alert, %{alert_id: "123", header_text: "a"})
      insert(:alert, %{alert_id: "123", header_text: "b"})

      [result1, result2] = Alerts.list_all_versions(created_alert)
      assert result1.alert_id == "123"
      assert result2.alert_id == "123"
      assert result1.header_text == "a"
      assert result2.header_text == "b"
    end
  end

  describe "list_all/0" do
    test "lists all alerts" do
      insert(:alert, %{alert_id: "123"})
      insert(:alert, %{alert_id: "234"})

      all_alerts = Alerts.list_all()

      assert Enum.find(all_alerts, &(&1.alert_id == "123"))
      assert Enum.find(all_alerts, &(&1.alert_id == "234"))
    end
  end
end
