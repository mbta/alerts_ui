defmodule AlertsUIWeb.FormComponents.AccessServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

<<<<<<< HEAD
=======
  import LiveIsolatedComponent
>>>>>>> 7eef22f (add access affected service section)
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.AccessAffectedService
  alias AlertsUIWeb.Step
<<<<<<< HEAD
=======
  alias MBTAV3API.Facilities.Facility
>>>>>>> 7eef22f (add access affected service section)

  @assigns %{
    id: "details",
    progress: %Step{
      name: "affected-service",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
<<<<<<< HEAD
    alert_data: %{route_type: nil, effect_name: "Bike Issue", is_facility: true},
=======
    alert_data: %{route_type: nil, effect_name: "Bike Issue"},
    available_facilities: [%Facility{id: "Facility-3", long_name: "Example Facility"}],
>>>>>>> 7eef22f (add access affected service section)
    editing: false
  }

  describe "component" do
    test "renders" do
      rendered = render_component(AccessAffectedService, @assigns)

<<<<<<< HEAD
      assert rendered =~ "facilities"
=======
      assert rendered =~ ~s(id="access_service_view")
    end

    test "it sends section_completed if no error in changeset" do
      {:ok, view, _html} = live_isolated_component(AccessAffectedService, @assigns)

      view
      |> element("form")
      |> render_change(%{"access_affected_service" => %{"facility_ids" => ["Facility-3"]}})

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:section_completed, %AccessAffectedService{facility_ids: ["Facility-3"]}}}
    end

    test "renders while editing an existing alerts" do
      alert_data = Map.put(@assigns.alert_data, :facility_ids, ["Facility-3"])
      assigns = %{@assigns | alert_data: alert_data, editing: true}

      {:ok, view, _html} = live_isolated_component(AccessAffectedService, assigns)

      assert view
             |> element("select#access_affected_service_facility_ids")
             |> render() =~
               ~s(<option selected="selected" value="Facility-3">Example Facility</option>)
>>>>>>> 7eef22f (add access affected service section)
    end
  end
end
