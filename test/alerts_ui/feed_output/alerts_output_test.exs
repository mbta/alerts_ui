defmodule AlertsUI.FeedOutput.AlertsOutputTest do
  use AlertsUI.DataCase, async: true
  alias AlertsUI.FeedOutput.AlertsOutput

  describe "start_link/1" do
    test "can start" do
      start_supervised!(AlertsOutput)
    end
  end

  describe "handle_info/2" do
    test "returns noreply" do
      response = AlertsOutput.handle_info(:output, %{})
      assert response == {:noreply, %{}}
    end
  end
end
