defmodule AlertsUI.GTFSIntake.GTFSSupervisorTest do
  use ExUnit.Case, async: true

  alias AlertsUI.GTFSIntake.GTFSSupervisor

  @opts [
    alert_api_url: "http://example.com/realtime_alert_things.json"
  ]

  describe "start_link/1" do
    test "can start the application" do
      assert {:ok, _pid} = GTFSSupervisor.start_link(@opts)
    end
  end

  describe "init/1" do
    test "sets up the data source and consumer" do
      assert {:ok, {_sup_flags, children}} = GTFSSupervisor.init(@opts)

      assert length(children) == 2
    end
  end
end
