defmodule AlertsUIWeb.CreateAlertLive.Slices.TimelineSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import Test.Support.Helpers
  import AlertsUI.Support.Factory
  alias AlertsUI.Alerts
  import Mock
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  @bus_route %Route{
    direction_names: %{1 => "Inbound", 0 => "Outbound"},
    sort_order: 3,
    id: "746",
    type: 3,
    name: "SLW"
  }

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      # first page
      assert render(view) =~ ~s(Alert type)
      assert view |> element("#route_type_and_effect") |> render =~ ~s(text-text-primary)
      assert view |> element("#details") |> render =~ ~s(text-text-secondary)

      # navigate to second page
      view = get_to_submission_page(conn, view, "Bus", "Schedule change")
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
    test "can go back when editing", %{conn: conn} do
      params =
        build(:alert_map, %{
          alert_id: "tl-edit",
          effect_detail: "DELAY",
          primary_service_type: "3"
        })

      {:ok, _} = Alerts.create_or_update_alert(params, build(:user))

      with_mocks([
        {RoutesRepo, [], [by_type: fn _ -> [@bus_route] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [] end, get_parent: fn _ -> nil end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/tl-edit")
        assert render(view) =~ ~s(Bus • Delay)

        # can click timeline to go back to first page
        view |> element("#route_type_and_effect") |> render_click
        assert render(view) =~ ~s(Alert type)
      end
    end

    @tag :logged_in_user
    test "can go back when duplicating", %{conn: conn} do
      params =
        build(:alert_map, %{alert_id: "tl-dup", effect_detail: "DELAY", primary_service_type: "3"})

      {:ok, _} = Alerts.create_or_update_alert(params, build(:user))

      with_mocks([
        {RoutesRepo, [], [by_type: fn _ -> [@bus_route] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [] end, get_parent: fn _ -> nil end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/duplicate/tl-dup")
        assert render(view) =~ ~s(Bus • Delay)

        # can click timeline to go back to first page
        view |> element("#route_type_and_effect") |> render_click
        assert render(view) =~ ~s(Alert type)
      end
    end

    @tag :logged_in_user
    test "can go to Alert Details from Select Alert Type on editing and duplicating", %{
      conn: conn
    } do
      params =
        build(:alert_map, %{
          alert_id: "tl-edit",
          effect_detail: "DELAY",
          primary_service_type: "3"
        })

      {:ok, _} = Alerts.create_or_update_alert(params, build(:user))

      with_mocks([
        {RoutesRepo, [], [by_type: fn _ -> [@bus_route] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [] end, get_parent: fn _ -> nil end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/tl-edit")
        assert render(view) =~ ~s(Bus • Delay)

        # go back to first page
        view |> element("#route_type_and_effect") |> render_click
        assert render(view) =~ ~s(Alert type)

        # click a different mode
        view
        |> element("#route-type-ferry-button")
        |> render_click()

        # go back to second page
        assert view |> element("#details") |> render =~ ~s(hover:underline)
        view |> element("#details") |> render_click
        assert render(view) =~ ~s(Bus • Delay)
        assert view |> element("#details") |> render =~ ~s(text-text-primary)
      end
    end

    @tag :logged_in_user
    test "cannot go to Alert Details from Select Alert Type on create", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/alerts/new")

      # navigate to second page
      view = get_to_submission_page(conn, view, "Bus", "Schedule change")

      # click timeline to go back to first page
      view |> element("#route_type_and_effect") |> render_click
      assert render(view) =~ ~s(Alert type)

      # the details button should be disabled
      assert view |> element("#route_type_and_effect") |> render =~ ~s(text-text-primary)
      assert view |> has_element?("#details[disabled]")
      refute view |> element("#details") |> render =~ ~s(hover:underline)
    end
  end
end
