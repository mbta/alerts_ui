defmodule AlertsUI.GTFSIntake.AlertsIntakeTest do
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.Alerts
  alias AlertsUI.GTFSIntake.AlertsIntake

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
          build(:alert_map, alert_id: "123", last_modified_timestamp: ~U[2023-10-20 18:45:38Z]),
          build(:alert_map, alert_id: "234", last_modified_timestamp: ~U[2023-10-20 18:45:38Z])
        ]
      ]

      {:ok, events: events}
    end

    test "returns noreply", %{events: events} do
      response = AlertsIntake.handle_events(events, nil, %{})

      assert response == {:noreply, [], %{}}
    end

    test "persists alerts to database", %{events: events} do
      AlertsIntake.handle_events(events, nil, %{})

      assert length(Alerts.list_all()) == 2
    end

    test "filters out alerts that are not more recent than the most recent version", %{
      events: events
    } do
      insert(:alert, alert_id: "123", last_modified_timestamp: ~U[2023-10-21 18:45:38Z])
      AlertsIntake.handle_events(events, nil, %{})
      [result_1, result_2] = Alerts.list_all()
      assert result_1.alert_id == "123"
      assert result_1.last_modified_timestamp == ~U[2023-10-21 18:45:38Z]
      assert result_2.alert_id == "234"
    end
  end
end
