defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.UrlSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import AlertsUI.Support.Factory
  import Ecto.Changeset
  import Mock
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.UrlSlice

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")

      assert render(view) =~ ~s(id="route_view")
    end

      @tag :logged_in_user
      test "does not show forbidden effects", %{ conn: conn } do
          {:ok, view, _html} = live(conn, "/alerts/mono/new")

          view
          |> element("#route-type-systemwide-button")
          |> render_click()

          refute render(view) =~ ~s(Summary)
      end

      @tag :logged_in_user
      test "goes to next view when effect is selected", %{ conn: conn } do
          {:ok, view, _html} = live(conn, "/alerts/mono/new")

          view
          |> element("#route-type-subway-button")
          |> render_click()

          view
          |> element("#effect-name-station_issue-button")
          |> render_click()

          assert render(view) =~ ~s(Alert details)
      end
  end
end
