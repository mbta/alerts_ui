defmodule AlertsUIWeb.FormComponents.AlertDetailsTest do
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
    alert_data: %{}
  }

  describe "component" do
    test "renders" do
      assert render_component(AlertDetails, @assigns) =~ ~s(id="details_form")
    end
  end

  describe "image url" do
    test "only shows preview if image has been entered" do
      with_mock(StopsRepo, by_route: fn _route, _direction -> [] end) do
        {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

        refute view
               |> element("div#image-preview-div")
               |> render() =~ ~s(div id=\"image-information\")

        view
        |> element("form")
        |> render_change(%{
          "alert_details" => %{
            "header_text" => "hello",
            "image_url" => "https://example.com/image.jpg"
          }
        })

        assert view
               |> element("div#image-preview-div")
               |> render() =~ ~s(div id=\"image-information\")
      end
    end
  end
end
