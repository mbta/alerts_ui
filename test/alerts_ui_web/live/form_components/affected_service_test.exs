defmodule AlertsUiWeb.FormComponents.AffectedServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.AffectedService
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
    available_routes: [],
    available_stops: []
  }

  describe "component" do
    test "renders" do
      assert render_component(AffectedService, @assigns) =~ ~s(id="service_form")
    end

    test "direction options are only populated once a route is chosen" do
      with_mock(StopsRepo, by_route: fn _route, _direction -> [] end) do
        {:ok, view, _html} = live_isolated_component(AffectedService, @assigns)

        refute view
               |> element("select#affected_service_direction")
               |> render() =~ "Both Directions"

        view
        |> element("form")
        |> render_change(%{"affected_service" => %{"route_ids" => ["1"]}})

        assert view
               |> element("select#affected_service_direction")
               |> render() =~ "Both Directions"
      end
    end
  end

  # describe "save event" do
  #   test "given a valid changset, sends a :create_alert event" do
  #     with_mock(StopsRepo, by_route: fn _route, _direction -> [] end) do
  #       {:ok, view, _html} = live_isolated_component(AffectedService, @assigns)

  #       view
  #       |> element("form")
  #       |> render_change(%{
  #         "affected_service" => %{
  #           "route_ids" => ["1", "2"]
  #         }
  #       })

  #       view
  #       |> element("form")
  #       |> render_click(:save)

  #       assert_receive {:__live_isolated_component_handle_info_received__, _pid,
  #                       {:section_completed,
  #                        %AffectedService{
  #                          route_ids: ["1", "2"]
  #                        }}}
  #     end
  #   end
  # end
end
