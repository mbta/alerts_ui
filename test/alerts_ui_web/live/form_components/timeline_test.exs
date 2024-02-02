defmodule AlertsUIWeb.FormComponents.TimelineTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import LiveIsolatedComponent
  alias AlertsUIWeb.FormComponents.Timeline
  alias AlertsUIWeb.Step

  @steps [
    %Step{
      name: "step one",
      previous: nil,
      next: "step two",
      label: "First"
    },
    %Step{name: "step three", previous: "step two", next: "step four", label: "Third"},
    %Step{
      name: "step two",
      previous: "step one",
      next: "step three",
      label: "Second"
    },
    %Step{name: "step four", previous: nil, next: nil, label: "Fourth"}
  ]
  @assigns %{
    id: "timeline",
    steps: @steps,
    progress: hd(@steps)
  }

  describe "previous_steps/3" do
    test "given a step, find names of previous steps" do
      [_, _, step_3, _] = @steps
      previous = Timeline.previous_steps(step_3, @steps)
      assert previous == ["step two", "step one"]
    end
  end

  describe "component" do
    test "renders" do
      {:ok, _view, html} = live_isolated_component(Timeline, @assigns)
      assert html =~ ~s(value=\"step one\")
    end
  end
end
