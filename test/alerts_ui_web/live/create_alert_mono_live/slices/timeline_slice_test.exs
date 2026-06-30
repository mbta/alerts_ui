defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.TimelineSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import Test.Support.Helpers
  import AlertsUI.Support.Factory
  alias AlertsUI.Alerts

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      # first page
      assert render(view) =~ ~s(Alert type)
      assert view |> element("#route_type_and_effect") |> render =~ ~s(text-text-primary)
      assert view |> element("#details") |> render =~ ~s(text-text-secondary)

      # navigate to second page
      view = get_to_submission_page_refactor(conn, view, "Bus", "Schedule change")
      refute render(view) =~ ~s(Alert type)
      assert view |> element("#route_type_and_effect") |> render =~ ~s(hover:underline)
      assert view |> element("#details") |> render =~ ~s(text-text-primary)

      # # click timeline to go back to first page
      view |> element("#route_type_and_effect") |> render_click
      assert render(view) =~ ~s(Alert type)
      assert view |> element("#route_type_and_effect") |> render =~ ~s(text-text-primary)
      assert view |> element("#details") |> render =~ ~s(text-text-secondary)
    end

    @tag :logged_in_user
    test "can't go back when editing", %{conn: conn} do
      params = build(:alert_map, %{alert_id: "tl-edit"})
      {:ok, _} = Alerts.create_or_update_alert(params, build(:user))

      {:ok, view, _html} = live(conn, "/alerts/edit/tl-edit")

      # can't click timeline to go back to first page
      assert has_element?(view, "#route_type_and_effect[disabled]")
    end

    @tag :logged_in_user
    test "can't go back when duplicating", %{conn: conn} do
      params = build(:alert_map, %{alert_id: "tl-dup"})
      {:ok, _} = Alerts.create_or_update_alert(params, build(:user))

      {:ok, view, _html} = live(conn, "/alerts/duplicate/tl-dup")

      # can't click timeline to go back to first page
      assert has_element?(view, "#route_type_and_effect[disabled]")
    end
  end
end
