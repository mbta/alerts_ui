defmodule AlertsUIWeb.CreateAlertMonoLive.SubmitSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Cancel button" do
    @tag :logged_in_user
    test "navigates away from the mono flow when clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new/bus/delay")

      assert has_element?(view, "#cancel")

      view |> element("#cancel") |> render_click()

      assert_redirect(view, "/alerts?")
    end
  end
end
