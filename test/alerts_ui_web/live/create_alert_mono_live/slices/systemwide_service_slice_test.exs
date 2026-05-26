defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.SystemwideSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  import Ecto.Changeset
  import Phoenix.LiveViewTest
  import Test.Support.Helpers
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.SystemwideSlice

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      get_to_submission_page(view, "Systemwide", "Delay")

      assert render(view) =~ ~s(id="systemwide-affected-service-form")
      assert render(view) =~ "Service types"
    end

    @tag :logged_in_user
    test "it shows an error if you didn't select a service type", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      get_to_submission_page(view, "Systemwide", "Delay")

      view |> render_click("#review button")

      assert render(view) =~ ~s(Select a service type)
    end

    @tag :logged_in_user
    test "doesn't show an error if you didn't select a service type", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      get_to_submission_page(view, "Systemwide", "Delay")

      view |> render_click("#service-type-bus")

      view |> render_click("#review button")

      assert render(view) =~ ~s(Select a service type)
    end

    @tag :logged_in_user
    test "renders correctly while editing", %{conn: conn} do
      alert_params =
        build(
          :alert_map,
          %{
            alert_id: "123",
            header_text: "example header text",
            effect: :OTHER_EFFECT,
            effect_detail: "STOP_CLOSURE",
            severity: 7,
            cause_detail: "unknown",
            service_types: [1]
          }
        )

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))
      {:ok, view, _html} = live(conn, "/alerts/edit?alert_id=123")

      assert render(view) =~ ~s( value="1" checked="checked" )
    end
  end
end
