defmodule AlertsUIWeb.FormComponents.SubmitTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest
  alias AlertsUIWeb.FormComponents.Submit
  alias AlertsUIWeb.Step

  @assigns %{
    id: "submit",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    alert_data: %{}
  }

  describe "save event" do
    test "sends a :create_alert event" do
      {:ok, view, _html} = live_isolated_component(Submit, @assigns)

      view |> element("#save") |> render_click(%{})

      assert_receive {:__live_isolated_component_handle_info_received__, _pid, :create_alert}
    end
  end

  describe "other navigation events" do
    @tag :logged_in_user
    test "back button returns to previous step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      # Use any combo to proceed to next page
      view
      |> element("#route_types_form button", "Bus")
      |> render_click()

      view
      |> element("#route_types_form button", "Delay")
      |> render_click()

      view
      |> element("#route_types_form")
      |> render_submit()

      render(view)

      view
      |> element("button#back")
      |> render_click()

      assert has_element?(view, "#route_types_form", "Service Type")
    end

    @tag :logged_in_user
    test "cancel button returns to alerts list page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      # Use any combo to proceed to next page
      view
      |> element("#route_types_form button", "Bus")
      |> render_click()

      view
      |> element("#route_types_form button", "Delay")
      |> render_click()

      view
      |> element("#route_types_form")
      |> render_submit()

      render(view)

      {:ok, new_view, _} =
        view
        |> element("button#cancel")
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(new_view, "article #alert-filter-form")
    end
  end
end
