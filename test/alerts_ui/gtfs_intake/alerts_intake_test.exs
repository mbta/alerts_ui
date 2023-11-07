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
      [result_1, result_2] = Alerts.list_all() |> Enum.sort_by(& &1.alert_id)
      assert result_1.alert_id == "123"
      assert result_1.last_modified_timestamp == ~U[2023-10-21 18:45:38Z]
      assert result_1.header_text == "new"
      assert result_2.alert_id == "234"
      assert length(Alerts.list_all()) - before_alerts_length == 1
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
      [result_1, result_2] = Alerts.list_all() |> Enum.sort_by(& &1.alert_id)
      assert result_1.alert_id == "123"
      assert result_1.last_modified_timestamp == ~U[2023-10-21 18:45:38Z]
      assert result_1.header_text == "original"
      assert result_2.alert_id == "234"
      assert length(Alerts.list_all()) - before_alerts_length == 1
    end
  end
end
