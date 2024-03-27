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

  describe "save as draft" do
    test "save as draft on click" do
      {:ok, view, _html} = live_isolated_component(RouteTypeAndEffect, @assigns)

      view
      |> element("#draft")
      |> render_click(%{
        "route_type" => "Bus"
      })

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:save_as_draft,
                       %RouteTypeAndEffect{
                         route_type: 3
                       }}}
    end
  end

  describe "save event" do
    test " given a valid changset, sends a :create_alert event" do
      assigns =
        @assigns
        |> Map.put(:effect_name, "Detour")
        |> Map.put(:route_type, "Bus")

      {:ok, view, _html} = live_isolated_component(RouteTypeAndEffect, assigns)

      view
      |> element("form")
      |> render_submit(%{"route_type" => "Bus"})

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:step_completed,
                       %RouteTypeAndEffect{
                         route_type: 3,
                         effect_name: "Detour"
                       }}}
    end

    test " given an invalid changset, does not sends a :create_alert event" do
      {:ok, view, _html} = live_isolated_component(RouteTypeAndEffect, @assigns)

      view
      |> element("form")
      |> render_submit(%{"alert_details" => %{}})

      refute_receive {:__live_isolated_component_handle_info_received__, _pid, {:create_alert, _}}
    end
  end
end
