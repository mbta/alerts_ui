defmodule AlertsUIWeb.FormComponents.DeliveryTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  use AlertsUIWeb, :live_view

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.Delivery
  alias AlertsUIWeb.Step

  @assigns %{
    id: "delivery",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    route_type: 1
  }

  describe "component" do
    test "renders" do
      assert render_component(Delivery, @assigns) =~ ~s(id="delivery_form")
    end

    test "banner text is hidden if checkbox is not checked" do
      {:ok, view, _html} = live_isolated_component(Delivery, @assigns)

      refute view
             |> element("div#banner_div")
             |> render() =~ ~s(id=\"banner-container\")

      view
      |> element("form")
      |> render_change(%{
        "delivery" => %{
          "view_banner" => "true"
        }
      })

      assert view
             |> element("div#banner_div")
             |> render() =~ ~s(id=\"banner-container\">)
    end

    test "banner text syncs with header text" do
      {:ok, view, _html} =
        live_isolated_component(
          Delivery,
          @assigns
          |> Map.merge(%{header_text: "example_header_text", view_banner: true})
        )

      assert view
             |> element("div#banner_div")
             |> render() =~ ~s(example_header_text)
    end

    test "editing works" do
      {:ok, view, _html} =
        live_isolated_component(
          Delivery,
          @assigns
          |> Map.merge(%{
            banner_text: "example_banner_text",
            view_banner: true,
            banner_sync_toggle: false
          })
        )

      assert view
             |> element("div#banner_div")
             |> render() =~ ~s(example_banner_text)
    end
  end
end
