defmodule AlertsUiWeb.FormComponents.AlertDetailsTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.AlertDetails
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
      assert render_component(AlertDetails, @assigns) =~ ~s(id="details_form")
    end

    test "direction options are only populated once a route is chosen" do
      with_mock(StopsRepo, by_route: fn _route, _direction -> [] end) do
        {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

        refute view
               |> element("select#alert_details_direction")
               |> render() =~ "Both Directions"

        view
        |> element("form")
        |> render_change(%{"alert_details" => %{"route_ids" => ["1"]}})

        assert view
               |> element("select#alert_details_direction")
               |> render() =~ "Both Directions"
      end
    end
  end

  describe "save as draft" do
    test "save as draft on click" do
      {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

      view
      |> element("form")
      |> render_change(%{"alert_details" => %{"header_text" => "cool_bean"}})

      view
      |> element("#details_draft")
      |> render_click(%{})

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:save_as_draft,
                       %AlertDetails{
                         header_text: "cool_bean",
                         draft: true
                       }}}
    end
  end

  describe "save event" do
    test "given a valid changset, sends a :create_alert event" do
      with_mock(StopsRepo, by_route: fn _route, _direction -> [] end) do
        {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

        view
        |> element("form")
        |> render_change(%{
          "alert_details" => %{
            "header_text" => "Test header",
            "description_text" => "Test description",
            "route_ids" => ["1", "2"]
          }
        })

        view |> element("form") |> render_submit(%{})

        assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                        {:create_alert,
                         %AlertDetails{
                           header_text: "Test header",
                           description_text: "Test description"
                         }}}
      end
    end

    test "given an invalid changset, does not sends a :create_alert event" do
      {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

      view
      |> element("form")
      |> render_submit(%{"alert_details" => %{}})

      refute_receive {:__live_isolated_component_handle_info_received__, _pid, {:create_alert, _}}
    end
  end
end
