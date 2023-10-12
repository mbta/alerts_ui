defmodule AlertsUI.GTFSIntake.AlertsIntakeTest do
  use ExUnit.Case
  alias AlertsUI.GTFSIntake.AlertsIntake

  @all_alerts []

  describe "start_link/1" do
    test "can start" do
      start_supervised!(AlertsIntake)
    end
  end

  describe "handle_events/3" do
    setup do
      events = [@all_alerts]

      {:ok, events: events}
    end

    test "returns noreply", %{events: events} do
      response = AlertsIntake.handle_events(events, nil, %{})

      assert response == {:noreply, [], %{}}
    end

    test "handles missing trips", %{events: events} do
      response = AlertsIntake.handle_events(events, nil, %{})

      assert response == {:noreply, [], %{}}
    end

    test "trips with missing data", %{events: events} do
      response = AlertsIntake.handle_events(events, nil, %{})

      assert response == {:noreply, [], %{}}
    end
  end

  describe "backend implementation" do
    test "handles reference info calls that come in after a timeout" do
      state = %{}

      response = AlertsIntake.handle_info({make_ref(), %{}}, state)

      assert response == {:noreply, [], state}
    end
  end
end
