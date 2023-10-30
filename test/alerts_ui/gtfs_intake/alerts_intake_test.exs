defmodule AlertsUI.GTFSIntake.AlertsIntakeTest do
  use ExUnit.Case
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
    test "returns noreply" do
      response = AlertsIntake.handle_events([], nil, %{})

      assert response == {:noreply, [], %{}}
    end
  end
end
