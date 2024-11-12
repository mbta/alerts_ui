defmodule AlertsUIWeb.FormComponents.SystemwideAffectedServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  use AlertsUIWeb, :live_view

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.{RouteTypeAndEffect, SystemwideAffectedService}
  alias AlertsUIWeb.Step
  alias Phoenix.LiveView

  @assigns %{
    id: "details",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    alert_data: %{route_type: nil, effect_name: "Suspension"},
    editing: false
  }

  describe "component" do
    test "renders" do
      rendered = render_component(SystemwideAffectedService, @assigns)

      assert rendered =~ ~s(id="systemwide-affected-service-form")
      assert rendered =~ "Service types"
    end

    test "it sends section_completed if no error in changeset" do
      {:ok, view, _html} = live_isolated_component(SystemwideAffectedService, @assigns)

      view
      |> element("form")
      |> render_change(%{"systemwide_affected_service" => %{"service_types" => ["2"]}})

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:section_completed, %SystemwideAffectedService{service_types: [2]}}}
    end

    @tag capture_log: true
    test "it sends add_errors if errors in changeset" do
      {:ok, view, _html} = live_isolated_component(SystemwideAffectedService, @assigns)

      view
      |> element("form")
      |> render_change(%{"systemwide_affected_service" => %{"service_types" => ["a"]}})

      refute_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:section_completed, _data}}

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:add_errors, _, _}}
    end

    test "renders while editing an existing alerts" do
      alert_data = Map.put(@assigns.alert_data, :service_types, [1])
      assigns = %{@assigns | alert_data: alert_data, editing: true}

      {:ok, view, _html} = live_isolated_component(SystemwideAffectedService, assigns)

      rendered_view = render(view)
      assert rendered_view =~ ~s( value="1" checked="checked" )
    end

    @tag :logged_in_user
    test "shows missing field error upon submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      send(
        view.pid,
        {:step_completed, %RouteTypeAndEffect{route_type: nil, effect_name: nil}}
      )

      send_update(view.pid, SystemwideAffectedService, id: "affected_service", submitted: true)

      assert view
             |> render() =~
               ~s(Select a service type)
    end
  end

  describe "handle_event validate" do
    test "converts string service types to integers" do
      assert {:noreply, socket} =
               SystemwideAffectedService.handle_event(
                 "validate",
                 %{"systemwide_affected_service" => %{"service_types" => [3]}},
                 %LiveView.Socket{}
               )

      assert %{assigns: %{systemwide_affected_service: %{"service_types" => [3]}}} = socket
    end
  end
end
