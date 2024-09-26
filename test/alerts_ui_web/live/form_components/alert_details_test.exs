defmodule AlertsUIWeb.FormComponents.AlertDetailsTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.AlertDetails
  alias AlertsUIWeb.Step

  @assigns %{
    id: "details",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    route_type: 4,
    combination: :RDT,
    alert_data: %{}
  }

  describe "component" do
    test "renders" do
      assert render_component(AlertDetails, @assigns) =~ ~s(id="details_form")
    end

    test "gets causes correctly" do
      {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

      assert view
             |> render() =~ ~s(fog)
    end
  end

  describe "image url" do
    test "only shows preview if image has been entered" do
      {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

      refute view
             |> element("div#image-preview-div")
             |> render() =~ ~s(div id=\"image-information\")

      view
      |> element("form")
      |> render_change(%{
        "alert_details" => %{
          "image_url" => "https://example.com/image.jpg"
        }
      })

      assert view
             |> element("div#image-preview-div")
             |> render() =~ ~s(div id=\"image-information\")
    end
  end
end
