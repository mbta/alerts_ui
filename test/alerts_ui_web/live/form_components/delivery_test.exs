defmodule AlertsUIWeb.FormComponents.DeliveryTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.Delivery
  alias AlertsUIWeb.Step
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  @assigns %{
    id: "delivery",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    route_type: 1,
    alert_data: %{header_text: "example_header_text"}
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
      {:ok, view, _html} = live_isolated_component(Delivery, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "delivery" => %{
          "view_banner" => "true"
        }
      })

      assert view
             |> element("div#banner_div")
             |> render() =~ ~s(example_header_text)
    end
  end

  describe "save event" do
    test "given a valid changset, sends a :create_alert event" do
      with_mock(StopsRepo, by_route: fn _route, _direction -> [] end) do
        {:ok, view, _html} = live_isolated_component(Delivery, @assigns)

        view
        |> element("form")
        |> render_change(%{
          "delivery" => %{
            "banner_text" => "example"
          }
        })

        view |> element("form") |> render_submit(%{})

        assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                        {:create_alert,
                         %Delivery{
                           banner_text: "example"
                         }}}
      end
    end
  end
end
