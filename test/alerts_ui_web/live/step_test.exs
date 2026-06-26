defmodule AlertsUIWeb.StepTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  doctest AlertsUIWeb.Step

  @route %Route{sort_order: 1, id: "1", name: "route_number_1"}
  @stop %Stop{id: "place-aqucl", name: "Aquarium"}

  describe "end-to-end" do
    @tag :logged_in_user
    test "form content does not persist after going back to mode-effect selection", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [@route] end]},
        {StopsRepo, [], [by_route: fn _route, _direction, _opts -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/legacy/new")

        # Start filling out form
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["1"], stop_ids: ["place-aqucl"]}
        })

        # Go back to mode-effect page
        view
        |> element("button#route_type_and_effect", "Select Alert Type")
        |> render_click()

        assert view |> element("#effect_buttons") |> has_element?()

        # Take different mode-effect approach
        get_to_submission_page(view, "Bus", "Detour")

        # Run validation
        open_review_modal(view)

        assert view |> element("#flash") |> render() =~ "Select route(s)"
      end
    end
  end
end
