defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.SelectionsTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AlertsUIWeb.CreateAlertMonoLive.Helpers.Selections
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.AffectedServiceSlice

  describe "selections_loading?/1" do
    test "returns true for a Selections struct with loading: true" do
      assert Selections.selections_loading?(%AffectedServiceSlice.Selections{loading: true}) ==
               true
    end

    test "returns false for a Selections struct with loading: false" do
      assert Selections.selections_loading?(%AffectedServiceSlice.Selections{loading: false}) ==
               false
    end

    test "returns false for nil" do
      assert Selections.selections_loading?(nil) == false
    end

    test "returns false for an arbitrary value" do
      assert Selections.selections_loading?("anything") == false
    end
  end
end
