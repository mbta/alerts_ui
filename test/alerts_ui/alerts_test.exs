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

  describe "get_most_recent_version/1" do
    test "gives back most recent version given alert id" do
      insert(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-12 00:01:00Z]})
      insert(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-13 00:01:00Z]})
      result = Alerts.get_most_recent_version("123")
      assert result.last_modified_timestamp == ~U[2023-10-13 00:01:00Z]
    end
  end

  describe "is_most_recent_version?/1" do
    test "returns true if no other alert with same alert_id is stored" do
      new_alert = build(:alert, %{alert_id: "123"})
      assert Alerts.is_most_recent_version?(new_alert) == true
    end

    test "returns true if new alert is more recent than stored versions with same alert_id" do
      insert(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-12 00:01:00Z]})
      insert(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-13 00:01:00Z]})

      new_alert =
        build(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-14 00:01:00Z]})

      assert Alerts.is_most_recent_version?(new_alert) == true
    end

    test "returns false if new alert is not than stored versions with same alert_id" do
      insert(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-12 00:01:00Z]})
      insert(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-14 00:01:00Z]})

      new_alert =
        build(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-13 00:01:00Z]})

      assert Alerts.is_most_recent_version?(new_alert) == false
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
