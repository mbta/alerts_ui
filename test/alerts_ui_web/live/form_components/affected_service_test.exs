defmodule AlertsUiWeb.FormComponents.AffectedServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.AffectedService
  alias AlertsUIWeb.Step
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

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
    available_stops: [],
    alert_data: %{}
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

    test "only shows stop names once route is selected" do
      stops = [%Stop{id: "1", name: "cool stop name"}]

      with_mock(StopsRepo, by_route: fn _route, _direction -> stops end) do
        {:ok, view, _html} = live_isolated_component(AffectedService, @assigns)

        refute render(view) =~ "cool stop name"

        view
        |> element("form")
        |> render_change(%{
          "affected_service" => %{
            "route_ids" => ["1", "2"],
            "directions" => [0]
          }
        }) =~ "cool stop name"
      end
    end
  end
end
