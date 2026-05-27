defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.SystemwideServiceSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUI.Alerts

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Systemwide", "Notice")

      assert render(view) =~ ~s(id="systemwide_service_view")
      assert render(view) =~ "Service types"
    end

    @tag :logged_in_user
    test "shows an error if no service type selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Systemwide", "Notice")

      view |> element("button#review", "Review and submit") |> render_click()

      assert render(view) =~ "Please fix the following errors:"
    end

    @tag :logged_in_user
    test "no error when service type is selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Systemwide", "Notice")

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"service_types" => ["3"]}})

      view |> element("button#review", "Review and submit") |> render_click()

      refute render(view) =~ "Select a service type"
    end

    @tag :logged_in_user
    test "renders correctly while editing", %{conn: conn} do
      alert_params =
        build(:alert_map, %{
          alert_id: "test-systemwide-edit",
          effect: :OTHER_EFFECT,
          effect_detail: "NOTICE",
          service_types: [1]
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))
      {:ok, view, _html} = live(conn, "/alerts/mono/edit/test-systemwide-edit")

      assert render(view) =~ ~s(value="1")
    end
  end
end
