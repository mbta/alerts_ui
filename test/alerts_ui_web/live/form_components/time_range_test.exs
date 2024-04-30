defmodule AlertsUIWeb.FormComponents.TimeRangeTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest
  alias AlertsUIWeb.FormComponents.TimeRange
  alias AlertsUIWeb.Step

  @assigns %{
    id: "time_range",
    progress: %Step{
      name: "time_range",
      previous: "route_type_and_effect",
      next: "success",
      label: "Time Range"
    },
    alert_data: %{}
  }

  describe "component" do
    test "renders" do
      assert render_component(TimeRange, @assigns) =~ ~s(id="time_range_form")
    end
  end
end
