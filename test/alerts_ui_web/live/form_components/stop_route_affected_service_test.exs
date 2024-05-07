defmodule AlertsUIWeb.FormComponents.StopRouteAffectedServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.StopRouteAffectedService
  alias AlertsUIWeb.Step
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @assigns %{
    id: "affected_service",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    route_type: 1,
    available_stops: [],
    available_routes: [%MBTAV3API.Routes.Route{sort_order: 1, id: "1"}],
    alert_data: %{},
    editing: false
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

    test "works correctly if editing" do
      {:ok, view, _html} =
        live_isolated_component(
          StopRouteAffectedService,
          @assigns
          |> Map.merge(%{
            editing: true,
            available_stops: [%Stop{id: "place-aqucl"}, %Stop{id: "place-andrw"}],
            available_routes: [%Route{id: "Blue", type: 1}, %Route{id: "Green", type: 1}],
            alert_data: %{
              stop_ids: ["place-aqucl"],
              route_ids: ["Blue"],
              route_type: 1
            }
          })
        )

      assert view |> render() =~ ~s(<option selected="selected" value="place-aqucl">)
      assert view |> render() =~ ~s(<option selected="selected" value="Blue">)
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
