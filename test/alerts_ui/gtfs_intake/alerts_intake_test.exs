defmodule AlertsUI.GTFSIntake.AlertsIntakeTest do
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.Alerts
  alias AlertsUI.GTFSIntake.AlertsIntake
  alias AlertsUI.Models.Alert

  describe "start_link/1" do
    test "can start" do
      start_supervised!(AlertsIntake)
    end
  end

  describe "handle_info/2" do
    test "returns noreply" do
      response = AlertsIntake.handle_info({make_ref(), :hello}, %{})

      assert response == {:noreply, [], %{}}
    end
  end

  describe "handle_events/3" do
    setup do
      events = [
        [
          build(:alert_map, alert_id: "123", last_modified_timestamp: ~U[2023-10-19 18:45:38Z]),
          build(:alert_map, alert_id: "234", last_modified_timestamp: ~U[2023-10-20 18:45:38Z])
        ]
      ]

      {:ok, events: events}
    end

    test "returns noreply", %{events: events} do
      response = AlertsIntake.handle_events(events, nil, %{})

      assert response == {:noreply, [], %{}}
    end

    test "creates alerts if there's no previous versions" do
      events =
        [
          build(:alert_map, alert_id: "123", last_modified_timestamp: ~U[2023-10-19 18:45:38Z]),
          build(:alert_map, alert_id: "234", last_modified_timestamp: ~U[2023-10-20 18:45:38Z])
        ]

      before_alerts_length = Alerts.list_all() |> length
      AlertsIntake.handle_events(events, nil, %{})

      assert length(Alerts.list_all()) - before_alerts_length == 2
    end

    test "updates alert if incoming version is most recent" do
      events = [
        build(:alert_map,
          alert_id: "123",
          last_modified_timestamp: ~U[2023-10-21 18:45:38Z],
          header_text: "new"
        ),
        build(:alert_map, alert_id: "234", last_modified_timestamp: ~U[2023-10-20 18:45:38Z])
      ]

      insert(:alert,
        alert_id: "123",
        last_modified_timestamp: ~U[2023-10-19 18:45:38Z],
        header_text: "old"
      )

      before_alerts_length = Alerts.list_all() |> length

      AlertsIntake.handle_events(events, nil, %{})

      all_alerts = Alerts.list_all()
      assert length(all_alerts) - before_alerts_length == 1

      assert result_1 = Enum.find(all_alerts, &(&1.alert_id == "123"))
      assert result_1.last_modified_timestamp == ~U[2023-10-21 18:45:38Z]
      assert result_1.header_text == "new"
      assert Enum.find(all_alerts, &(&1.alert_id == "234"))
    end

    test "does nothing if incoming version is not more recent" do
      events = [
        build(:alert_map,
          alert_id: "123",
          last_modified_timestamp: ~U[2023-10-19 18:45:38Z],
          header_text: "incoming"
        ),
        build(:alert_map, alert_id: "234", last_modified_timestamp: ~U[2023-10-20 18:45:38Z])
      ]

      insert(:alert,
        alert_id: "123",
        last_modified_timestamp: ~U[2023-10-21 18:45:38Z],
        header_text: "original"
      )

      before_alerts_length = Alerts.list_all() |> length

      AlertsIntake.handle_events(events, nil, %{})

      all_alerts = Alerts.list_all()

      assert length(all_alerts) - before_alerts_length == 1
      assert result_1 = Enum.find(all_alerts, &(&1.alert_id == "123"))
      assert result_1.last_modified_timestamp == ~U[2023-10-21 18:45:38Z]
      assert result_1.header_text == "original"
      assert Enum.find(all_alerts, &(&1.alert_id == "234"))
    end

    test "closes alerts that aren't in the feed" do
      events = [
        build(:alert_map, alert_id: "123"),
        build(:alert_map, alert_id: "234")
      ]

      insert(:alert, alert_id: "456")
      AlertsIntake.handle_events(events, nil, %{})
      updated_alert = Repo.get_by(Alert, alert_id: "456")
      assert !is_nil(updated_alert.closed_timestamp)
    end
  end
end
