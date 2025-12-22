defmodule AlertsUIWeb.FormComponents.DeliveryTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  use AlertsUIWeb, :live_view

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.{Delivery, RouteTypeAndEffect}
  alias AlertsUIWeb.Step

  @assigns %{
    id: "delivery",
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
          |> Map.put(:alert_data, %{header_text: "example_header_text", view_banner: true})
        )

      assert view
             |> element("div#banner_div")
             |> render() =~ ~s(example_header_text)
    end
  end

  @tag :logged_in_user
  test "banner text does not secretly get filled in when unselecting email box", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/alerts/new")

    send(
      view.pid,
      {:step_completed, %RouteTypeAndEffect{route_type: "bus", effect_name: "Detour"}}
    )

    view
    |> element("#details_form")
    |> render_change(%{
      "alert_details" => %{
        "header_text" => "header text"
      }
    })

    view
    |> element("#notification-toggle")
    |> render_change(%{
      "delivery" => %{
        "notification_toggle" => "false"
      }
    })

    view
    |> element("button#review", "Review and submit")
    |> render_click()

    refute view
           |> render() =~ ~s(Check box to show you understand)
  end

  test "renders correctly while editing" do
    alert_data = %{
      banner_text: "my banner text"
    }

    assigns = @assigns |> Map.merge(%{alert_data: alert_data, form_type: :editing})

    {:ok, view, _html} = live_isolated_component(Delivery, assigns)

    assert view
           |> element("div#banner_div")
           |> render() =~ ~s(id=\"banner-container\">)

    assert view
           |> element("div#banner_div")
           |> render() =~ ~s(my banner text)
  end
end
