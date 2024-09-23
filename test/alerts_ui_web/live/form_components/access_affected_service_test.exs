defmodule AlertsUIWeb.FormComponents.AccessAffectedServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  use AlertsUIWeb, :live_view
  import Mock

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.{AccessAffectedService, RouteTypeAndEffect}
  alias AlertsUIWeb.Step
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo

  @assigns %{
    id: "details",
    progress: %Step{
      name: "affected-service",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    alert_data: %{route_type: nil, effect_name: "Bike Issue"},
    available_facilities: [%Facility{id: "Facility-3", long_name: "Example Facility"}],
    editing: false
  }

  describe "component" do
    test "renders" do
      rendered = render_component(AccessAffectedService, @assigns)

      assert rendered =~ ~s(id="access_service_view")
    end

    test "it sends section_completed if no error in changeset" do
      {:ok, view, _html} = live_isolated_component(AccessAffectedService, @assigns)

      view
      |> element("form")
      |> render_change(%{"access_affected_service" => %{"facility_id" => "Facility-3"}})

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:section_completed, %AccessAffectedService{facility_id: "Facility-3"}}}
    end

    test "renders while editing an existing alerts" do
      :BIKE_ISSUE

      alert_data = %AlertsUIWeb.FormComponents.Helpers.AlertData{
        facility_id: "Facility-3",
        effect_name: "Bike Issue"
      }

      assigns = @assigns |> Map.merge(%{alert_data: alert_data, editing: true})

      {:ok, view, _html} = live_isolated_component(AccessAffectedService, assigns)

      assert view
             |> element("select#access_affected_service_facility_id")
             |> render() =~
               ~s(<option selected="selected" value="Facility-3">Example Facility</option>)
    end

    @tag :logged_in_user
    test "shows missing field error upon submission", %{conn: conn} do
      with_mocks([
        {RoutePatternsRepo, [], [included_stops_by_route_id: fn _route_id, _direction -> [] end]},
        {FacilitiesRepo, [], get_by_type: fn _types, _opts -> [] end}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        send(
          view.pid,
          {:step_completed, %RouteTypeAndEffect{route_type: nil, effect_name: "Parking Issue"}}
        )

        refute view
               |> render() =~
                 ~s(text-text-error)

        send_update(view.pid, AccessAffectedService, id: "affected_service", submitted: true)

        assert view
               |> render() =~
                 ~s(text-text-error)
      end
    end
  end
end
