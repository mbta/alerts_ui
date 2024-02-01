defmodule AlertsUIWeb.FormComponents.TimelineTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
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

  describe "previous_steps/3" do
    test "given a step, find names of previous steps" do
      [_, _, step_3, _] = @steps
      previous = Timeline.previous_steps(step_3, @steps)
      assert previous == ["step two", "step one"]
    end
  end
end
