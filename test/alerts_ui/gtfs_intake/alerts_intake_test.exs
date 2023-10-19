defmodule AlertsUI.GTFSIntake.AlertsIntakeTest do
  use ExUnit.Case
  alias AlertsUI.GTFSIntake.AlertsIntake

  describe "start_link/1" do
    test "can start" do
      start_supervised!(AlertsIntake)
    end
  end

  describe "handle_events/3" do
    setup do
      events = []

      {:ok, events: events}
    end

    test "returns noreply", %{events: events} do
      response = AlertsIntake.handle_events(events, nil, %{})

      assert response == {:noreply, [], %{}}
    end
  end
end
