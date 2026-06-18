defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.UrlSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")

      assert render(view) =~ ~s(id="route_view")
    end

    @tag :logged_in_user
    test "does not show forbidden effects", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")

      view
      |> element("#route-type-systemwide-button")
      |> render_click()

      refute render(view) =~ ~s(Summary)
    end

    @tag :logged_in_user
    test "Capitalizes effects correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")

      view
      |> element("#route-type-subway-button")
      |> render_click()

      assert render(view) =~ ~s(Station issue)
    end

    @tag :logged_in_user
    test "goes to next view when effect is selected", %{conn: conn} do
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

  describe "resetting" do
    @tag :logged_in_user
    test "changes to the form should be removed when restarting", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")

      view = get_to_submission_page_refactor(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "start_of_service"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_date" => "2000-01-01"
        }
      })

      assert render(view) =~ ~s(Effect can&#39;t start in the past)

      view
      |> element("button", "Select Alert Type")
      |> render_click()

      refute render(view) =~ ~s(Effect can&#39;t start in the past)

      view = get_to_submission_page_refactor(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "end_of_service"
        }
      })

      # It's not there because everything reset
      refute render(view) =~ ~s(Effect can&#39;t start in the past)
    end
  end
end
