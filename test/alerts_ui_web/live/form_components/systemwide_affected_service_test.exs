defmodule AlertsUIWeb.FormComponents.SystemwideAffectedServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.SystemwideAffectedService
  alias AlertsUIWeb.Step
  alias Phoenix.LiveView

  @assigns %{
    id: "details",
    progress: %Step{
      name: "affected-service",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    alert_data: %{route_type: nil, effect_name: "Suspension"}
  }

  describe "component" do
    test "renders" do
      rendered = render_component(SystemwideAffectedService, @assigns)

      assert rendered =~ ~s(id="systemwide-affected-service-form")
      assert rendered =~ "Service Type(s)"
    end

    test "it sends section_completed if no error in changeset" do
      {:ok, view, _html} = live_isolated_component(SystemwideAffectedService, @assigns)

      view
      |> element("form")
      |> render_change(%{"systemwide_affected_service" => %{"service_types" => ["3"]}})

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:section_completed, %SystemwideAffectedService{service_types: [3]}}}
    end
  end

  describe "handle_event validate" do
    test "converts string service types to integers" do
      assert {:noreply, socket} =
               SystemwideAffectedService.handle_event(
                 "validate",
                 %{"systemwide_affected_service" => %{"service_types" => ["3"]}},
                 %LiveView.Socket{}
               )

      assert %{assigns: %{systemwide_affected_service: %{"service_types" => [3]}}} = socket
    end
  end
end
