defmodule AlertsUIWeb.CreateAlertLive.Helpers.EntityValidatorTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUIWeb.CreateAlertLive.Helpers.EntityValidator

  describe "get_obsolete_ids/2" do
    test "returns list of ids not in given list" do
      entities = [%{name: "Purple Route", id: "Purple"}]

      result =
        EntityValidator.get_obsolete_ids(["Pink", "Purple"], %{ok?: true, result: entities})

      assert result == ["Pink"]
    end

    test "returns list of ids not in given list when entities have trips" do
      entities = [%{trip: %{name: "Purple Route", id: "Purple"}}]

      result =
        EntityValidator.get_obsolete_ids(["Pink", "Purple"], %{ok?: true, result: entities})

      assert result == ["Pink"]
    end

    test "returns list of ids not in given list when id is not in list" do
      entities = [%{name: "Purple Route", id: "Purple"}]
      result = EntityValidator.get_obsolete_ids("Pink", %{ok?: true, result: entities})
      assert result == ["Pink"]
    end

    test "returns nil if AsyncResult has no arrived yet" do
      result = EntityValidator.get_obsolete_ids("Pink", %{ok?: false, result: nil})
      assert result == nil
    end
  end
end
