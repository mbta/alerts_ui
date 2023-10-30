defmodule AlertsUI.AlertsTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  alias AlertsUI.Alerts
  alias AlertsUI.Models.Alert
  alias AlertsUI.Repo

  describe "create_alert/1" do
    test "stores valid alert" do
      alert = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
      }

      Alerts.create_alert(alert)
      actual_alerts = Alerts.list_all()
      assert length(actual_alerts) == 1
    end

    @tag :capture_log
    test "does not store invalid alert" do
      alert = %{
        description_text: "b",
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
      }

      Alerts.create_alert(alert)
      actual_alerts = Alerts.list_all()
      assert actual_alerts == []
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
      assert length(Alerts.list_all()) == 1
      Alerts.create_alert(alert)
      assert length(Alerts.list_all()) == 1
    end
  end

  describe "list_all_versions/1" do
    test "list versions of alerts given alert id" do
      alert1 = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
      }

      alert2 = %{
        alert_id: "123",
        header_text: "c",
        description_text: "d",
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
      }

      Alert.create_changeset(%Alert{}, alert1) |> Repo.insert()
      Alert.create_changeset(%Alert{}, alert2) |> Repo.insert()

      [result1, result2] = Alerts.list_all_versions("123")
      assert result1.alert_id == "123"
      assert result2.alert_id == "123"
    end

    test "list alerts given alert id" do
      alert1 = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
      }

      alert2 = %{
        alert_id: "123",
        header_text: "c",
        description_text: "d",
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
      }

      {:ok, created_alert} = Alert.create_changeset(%Alert{}, alert1) |> Repo.insert()
      Alert.create_changeset(%Alert{}, alert2) |> Repo.insert()

      [result1, result2] = Alerts.list_all_versions(created_alert)
      assert result1.alert_id == "123"
      assert result2.alert_id == "123"
    end
  end

  describe "list_all/0" do
    test "lists all alerts" do
      alert1 = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
      }

      alert2 = %{
        alert_id: "234",
        header_text: "c",
        description_text: "d",
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
      }

      Alert.create_changeset(%Alert{}, alert1) |> Repo.insert()
      Alert.create_changeset(%Alert{}, alert2) |> Repo.insert()

      [result1, result2] = Alerts.list_all()
      assert result1.alert_id == "123"
      assert result2.alert_id == "234"
    end
  end
end
