defmodule AlertsUIWeb.FormComponents.StopRouteAffectedServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.StopRouteAffectedService
  alias AlertsUIWeb.Step
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop
  alias Phoenix.LiveView.AsyncResult

  @assigns %{
    id: "affected_service",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    route_type: 1,
    alert_data: %{},
    editing: false,
    effect_name: "Delay"
  }

  @route %Route{sort_order: 1, id: "Blue", name: "route_number_1"}
  @stop %Stop{id: "place-aqucl"}

  describe "component" do
    test "renders" do
      assert render_component(StopRouteAffectedService, @assigns) =~ ~s(id="service_form")
    end

    test "route options are disabled until a stop is chosen" do
      {:ok, view, _html} =
        live_isolated_component(StopRouteAffectedService, %{
          @assigns
          | alert_data: %{route_type: 1}
        })

      view
      |> live_assign(%{
        available_stops: %AsyncResult{
          ok?: true,
          loading: false,
          failed: false,
          result: [@stop]
        }
      })

      assert view
             |> render() =~ ~s(multiple=\"multiple\" disabled=\"disabled\")

      view
      |> live_assign(%{
        available_stops: %AsyncResult{
          ok?: true,
          loading: false,
          failed: false,
          result: [@route]
        }
      })

      view
      |> element("form")
      |> render_change(%{"stop_route_affected_service" => %{"stop_ids" => ["Blue"]}})

      refute view
             |> render() =~ ~s(multiple=\"multiple\" disabled=\"disabled\")

      view
      |> live_assign(%{
        available_routes: %AsyncResult{
          ok?: true,
          loading: false,
          failed: false,
          result: [@route]
        }
      })

      assert view
             |> render() =~ ~s(route_number_1)
    end

    test "search works" do
      with_mocks([
        {RoutesRepo, [], [by_stop: fn _route_id -> [@route] end]},
        {StopsRepo, [], [by_route_type: fn _route_type -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            @assigns
          )

        assert view |> render_async() =~ ~s(<option value="place-aqucl">)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["stop_route_affected_service", "stop_ids"],
          "stop_route_affected_service" => %{"stop_ids" => ["place-aqucl"]}
        })

        assert view |> render_async() =~ ~s(<option selected="selected" value="Blue">)

        view
        |> element("form")
        |> render_change(%{
          "stop_route_affected_service" => %{
            "route_ids" => [],
            "stop_ids_filter" => "x",
            "route_ids_filter" => "x"
          }
        })

        refute view |> render_async() =~ ~s(<option value="place-aqucl">)
        refute view |> render_async() =~ ~s(<option selected="selected" value="Blue">)
      end
    end

    test "works correctly if editing" do
      with_mocks([
        {RoutesRepo, [], [by_stop: fn _route_id -> [@route] end]},
        {StopsRepo, [], [by_route_type: fn _route_type -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            @assigns
            |> Map.merge(%{
              editing: true,
              effect_name: "DELAY",
              alert_data: %{
                stop_ids: ["place-aqucl"],
                route_ids: ["Blue"],
                route_type: 1
              }
            })
          )

        assert view |> render_async() =~ ~s(<option selected="selected" value="place-aqucl">)
        assert view |> render_async() =~ ~s(<option selected="selected" value="Blue">)
      end
    end

    test "it sends section_completed if no error in changeset" do
      {:ok, view, _html} =
        live_isolated_component(StopRouteAffectedService, %{
          @assigns
          | alert_data: %{route_type: 3}
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
