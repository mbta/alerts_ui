defmodule AlertsUIWeb.FormComponents.RouteTypeAndEffectTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.RouteTypeAndEffect
  alias AlertsUIWeb.Step

  @assigns %{
    id: "route_type_and_effect",
    progress: %Step{
      name: "route_type_and_effect",
      previous: "nil",
      next: "alert_details",
      label: "Route Type And Effect"
    },
    alert_data: %{}
  }

  describe "component" do
    test "renders" do
      assert render_component(RouteTypeAndEffect, @assigns) =~ ~s(id="route_types_form")
    end
  end

  describe "complete_step event" do
    test "given a valid changset, goes to next step" do
      assigns =
        @assigns
        |> Map.put(:selected_effect, "Detour")
        |> Map.put(:selected_route_type, "Bus")

      {:ok, view, _html} = live_isolated_component(RouteTypeAndEffect, assigns)

      view
      |> element("form")
      |> render_submit(%{})

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:step_completed,
                       %RouteTypeAndEffect{
                         route_type: 3,
                         effect_name: "Detour"
                       }}}
    end

    test "given an invalid changset, does not sends a :step_completed event" do
      {:ok, view, _html} = live_isolated_component(RouteTypeAndEffect, @assigns)

      view
      |> element("form")
      |> render_submit(%{"alert_details" => %{}})

      refute_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:step_completed, _}}
    end
  end
end
