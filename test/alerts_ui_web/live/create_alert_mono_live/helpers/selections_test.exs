defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.SelectionsTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.AsyncResult
  alias AlertsUIWeb.CreateAlertMonoLive.Helpers.Selections

  describe "selections_loading?/1" do
    test "returns true when AsyncResult loading is true" do
      assert Selections.selections_loading?(%AsyncResult{loading: true}) == true
    end

    test "returns false when AsyncResult loading is false" do
      assert Selections.selections_loading?(%AsyncResult{loading: false}) == false
    end

    test "returns false when AsyncResult is ok with a result" do
      assert Selections.selections_loading?(%AsyncResult{ok?: true, result: %{}}) == false
    end

    test "returns false for nil" do
      assert Selections.selections_loading?(nil) == false
    end

    test "returns false for an arbitrary value" do
      assert Selections.selections_loading?("anything") == false
    end
  end

  describe "assign_unwrapped_selections/2" do
    test "assigns the default when AsyncResult is loading with [:selections]" do
      assigns =
        Selections.assign_unwrapped_selections(
          assigns_with(%AsyncResult{loading: [:selections]}),
          %{default: true}
        )

      assert assigns.selections == %{default: true}
    end

    test "unwraps the result when AsyncResult is ok" do
      result = %{routes: ["1", "2"]}

      assigns =
        Selections.assign_unwrapped_selections(
          assigns_with(%AsyncResult{ok?: true, result: result})
        )

      assert assigns.selections == result
    end

    test "raises when AsyncResult is not ok" do
      assert_raise RuntimeError, "oops", fn ->
        Selections.assign_unwrapped_selections(assigns_with(%AsyncResult{ok?: false}))
      end
    end

    test "assigns the default when selections is nil" do
      assigns =
        Selections.assign_unwrapped_selections(assigns_with(nil), %{from_default: true})

      assert assigns.selections == %{from_default: true}
    end

    test "defaults to empty map when no default is provided and selections is nil" do
      assigns = Selections.assign_unwrapped_selections(assigns_with(nil))

      assert assigns.selections == %{}
    end

    test "leaves assigns unchanged when selections is already a plain value" do
      already_unwrapped = %{routes: ["1"]}

      assigns =
        Selections.assign_unwrapped_selections(assigns_with(already_unwrapped))

      assert assigns.selections == already_unwrapped
    end
  end

  defp assigns_with(selections) do
    %{selections: selections, __changed__: %{}}
  end
end
