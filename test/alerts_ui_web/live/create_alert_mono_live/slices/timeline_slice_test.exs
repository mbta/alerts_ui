defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.TimelineSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      # first page
      assert render(view) =~ ~s(Alert type)
      assert view |> element("#route_type_and_effect") |> render =~ ~s(text-text-primary)
      assert view |> element("#details") |> render =~ ~s(text-text-secondary)

      # navigate to second page
      get_to_submission_page_refactor(view, "Bus", "Schedule change")
      refute render(view) =~ ~s(Alert type)
      assert view |> element("#route_type_and_effect") |> render =~ ~s(hover:underline)
      assert view |> element("#details") |> render =~ ~s(text-text-primary)

      # # click timeline to go back to first page
      view |> element("#route_type_and_effect") |> render_click
      assert render(view) =~ ~s(Alert type)
      assert view |> element("#route_type_and_effect") |> render =~ ~s(text-text-primary)
      assert view |> element("#details") |> render =~ ~s(text-text-secondary)
    end
  end
end
