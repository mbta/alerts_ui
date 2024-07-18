defmodule AlertsUIWeb.FormComponents.AccessServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.AccessAffectedService
  alias AlertsUIWeb.Step

  @assigns %{
    id: "details",
    progress: %Step{
      name: "affected-service",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    alert_data: %{route_type: nil, effect_name: "Bike Issue", is_facility: true},
    editing: false
  }

  describe "component" do
    test "renders" do
      rendered = render_component(AccessAffectedService, @assigns)

      assert rendered =~ "facilities"
    end
  end
end
