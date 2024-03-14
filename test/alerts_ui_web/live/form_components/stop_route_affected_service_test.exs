defmodule AlertsUiWeb.FormComponents.StopRouteAffectedServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.StopRouteAffectedService
  alias AlertsUIWeb.Step
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  @assigns %{
    id: "details",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    route_type: 1,
    available_stops: [],
    available_routes: [],
    alert_data: %{}
  }

  describe "component" do
    test "renders" do
      assert render_component(StopRouteAffectedService, @assigns) =~ ~s(id="service_form")
    end

    test "route options are only populated once a stop is chosen" do
      with_mock(StopsRepo, by_route: fn _route, _direction -> [] end) do
        {:ok, view, _html} =
          live_isolated_component(StopRouteAffectedService, %{
            @assigns
            | alert_data: %{route_type: 3, effect_name: "Delay"}
          })

        refute view
               |> render() =~ "Route(s)"

        view
        |> element("form")
        |> render_change(%{"stop_route_affected_service" => %{"stop_ids" => ["1"]}})

        assert view
               |> render() =~ "Route(s)"
      end
    end

    test "it sends section_completed if no error in changeset" do
      with_mock(StopsRepo, by_route: fn _route, _direction -> [] end) do
        {:ok, view, _html} =
          live_isolated_component(StopRouteAffectedService, %{
            @assigns
            | alert_data: %{route_type: 3, effect_name: "Delay"}
          })

        view
        |> element("form")
        |> render_change(%{
          "stop_route_affected_service" => %{"stop_ids" => ["1"], "route_ids" => ["1"]}
        })

        assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                        {:section_completed,
                         %StopRouteAffectedService{
                           stop_ids: ["1"],
                           route_ids: ["1"]
                         }}}
      end
    end
  end
end
