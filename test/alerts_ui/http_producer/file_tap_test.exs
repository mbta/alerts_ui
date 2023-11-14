defmodule AlertsUI.HttpProducer.FileTapTest do
  use AlertsUI.DataCase, async: true

  alias AlertsUI.HttpProducer.FileTap

  describe "start_link/1" do
    test "can start the application" do
      assert {:ok, _pid} = FileTap.start_link([])
    end
  end

  describe "init/1" do
    test "sets up the data source" do
      assert {:producer, state} = FileTap.init([])
      assert %AlertsUI.HttpProducer.FileTap.State{enabled?: false, demand: 0, bodies: %{}} = state
    end
  end
end
