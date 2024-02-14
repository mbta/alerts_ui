defmodule AlertsUiWeb.FormComponents.SuccessfulSubmissionTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.SuccessfulSubmission
  alias AlertsUIWeb.Step

  @assigns %{
    id: "details",
    progress: %Step{name: "success", previous: nil, next: nil, label: "Success"}
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
end
