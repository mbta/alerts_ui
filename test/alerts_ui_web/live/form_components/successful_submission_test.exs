defmodule AlertsUiWeb.FormComponents.SuccessfulSubmissionTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest
  import AlertsUI.Support.Factory

  alias AlertsUIWeb.FormComponents.SuccessfulSubmission
  alias AlertsUIWeb.Step

  @uuid Ecto.UUID.generate()

  @assigns %{
    id: "details",
    progress: %Step{name: "success", previous: nil, next: nil, label: "Success"},
    show_created_alert: false,
    alert_uuid: @uuid
  }

  describe "component" do
    test "renders" do
      assert render_component(SuccessfulSubmission, @assigns) =~ ~s(id="success_view")
    end
  end

  describe "ok event" do
    test "redirect on button click" do
      {:ok, view, _html} = live_isolated_component(SuccessfulSubmission, @assigns)

      view
      |> element("#success_button")
      |> render_click(%{})

      assert_redirect(view)
    end
  end

  describe "laboratory flags" do
    test "Alert info not show if show_created_alert flag is not set" do
      insert(:alert, %{id: @uuid, header_text: "alert header text"})
      {:ok, _view, html} = live_isolated_component(SuccessfulSubmission, @assigns)
      refute html =~ ~s(alert header text)
    end

    test "Alert info shown if show_created_alert flag is set" do
      insert(:alert, %{id: @uuid, header_text: "alert header text"})
      assigns = Map.put(@assigns, :show_created_alert, true)
      {:ok, _view, html} = live_isolated_component(SuccessfulSubmission, assigns)

      assert html =~ ~s(alert header text)
    end
  end
end
