defmodule AlertsUI.HttpProducer.FileTapTest do
  use AlertsUI.DataCase, async: true

  alias AlertsUI.HttpProducer.FileTap
  alias AlertsUI.HttpProducer.FileTap.State

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

  describe "handle_cast/2" do
    test "returns no_reply" do
      state = struct!(State, enabled?: true)

      assert {:noreply, [], _state} =
               FileTap.handle_cast(
                 {:log_body, "", "http://example.com", DateTime.utc_now()},
                 state
               )
    end
  end
end
