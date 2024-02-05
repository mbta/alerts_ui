defmodule AlertsUiWeb.FormComponents.AlertDetailsTest do
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
    alert_data: %{route_type: 1}
  }

  describe "component" do
    test "renders" do
      assert render_component(AlertDetails, @assigns) =~ ~s(id="details_form")
    end
  end

  describe "save event" do
    test " given a valid changset, sends a :create_alert event" do
      {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

      view
      |> element("form")
      |> render_submit(%{
        "alert_details" => %{
          "route_ids" => ["1", "2"],
          "header_text" => "Test header",
          "description_text" => "Test description"
        }
      })

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:create_alert,
                       %AlertDetails{
                         route_ids: ["1", "2"],
                         header_text: "Test header",
                         description_text: "Test description"
                       }}}
    end

    test " given an invalid changset, does not sends a :create_alert event" do
      {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

      view
      |> element("form")
      |> render_submit(%{"alert_details" => %{}})

      refute_receive {:__live_isolated_component_handle_info_received__, _pid, {:create_alert, _}}
    end
  end
end
