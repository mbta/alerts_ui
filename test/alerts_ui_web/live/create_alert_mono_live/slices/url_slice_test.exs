defmodule AlertsUIWeb.CreateAlertLive.Slices.UrlSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      assert render(view) =~ ~s(id="route_view")
    end

    @tag :logged_in_user
    test "does not show forbidden effects", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      view
      |> element("#route-type-systemwide-button")
      |> render_click()

      refute render(view) =~ ~s(Summary)
    end

    @tag :logged_in_user
    test "Capitalizes effects correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      view
      |> element("#route-type-subway-button")
      |> render_click()

      assert render(view) =~ ~s(Station issue)
    end

    @tag :logged_in_user
    test "goes to next view when effect is selected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           by_route_type: fn _route_type, _ -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view
        |> element("#route-type-subway-button")
        |> render_click()

        {:ok, _details_view, details_html} =
          view
          |> element("#effect-name-station_issue-button")
          |> render_click()
          |> follow_redirect(conn)

        assert details_html =~ ~s(Alert details)
      end
    end
  end
end
