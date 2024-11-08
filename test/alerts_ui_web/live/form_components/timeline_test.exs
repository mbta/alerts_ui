defmodule AlertsUIWeb.FormComponents.TimelineTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import LiveIsolatedComponent
  alias AlertsUIWeb.FormComponents.Timeline
  alias AlertsUIWeb.Step

  @steps [
    %Step{
      name: "step_one",
      previous: nil,
      next: "step_two",
      label: "First"
    },
    %Step{name: "step_three", previous: "step_two", next: "step_four", label: "Third"},
    %Step{
      name: "step_two",
      previous: "step_one",
      next: "step_three",
      label: "Second"
    },
    %Step{name: "step_four", previous: nil, next: nil, label: "Fourth"}
  ]
  @assigns %{
    id: "timeline",
    steps: @steps,
    progress: hd(@steps),
    editing: false
  }

  describe "previous_steps/3" do
    test "given a step, find names of previous steps" do
      [_, _, step_3, _] = @steps
      previous = Timeline.previous_steps(step_3, @steps)
      assert previous == ["step_two", "step_one"]
    end
  end

  describe "component" do
    test "renders" do
      {:ok, _view, html} = live_isolated_component(Timeline, @assigns)
      assert html =~ ~s(value=\"step_one\")
    end
  end
end
