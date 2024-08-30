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

  describe "save as draft" do
    test "save as draft on click" do
      {:ok, view, _html} = live_isolated_component(Submit, @assigns)

      view
      |> element("#draft")
      |> render_click(%{})

      assert_receive {:__live_isolated_component_handle_info_received__, _pid, :save_as_draft}
    end
  end
end
