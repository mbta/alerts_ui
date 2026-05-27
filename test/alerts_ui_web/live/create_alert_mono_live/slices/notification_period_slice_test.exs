defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.NotificationPeriodSliceTest do
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
      get_to_submission_page_refactor(view, "Subway", "Delay")
      assert render(view) =~ ~s(id="notification_period_view")
    end

    @tag :logged_in_user
    test "'when alert is closed' hidden unless pick option selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      # Default is :now — closed-placeholder should be visible
      assert render(view) =~ ~s(id="closed-placeholder")

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"notification_specifier" => "same_as_effect_period"}})

      refute render(view) =~ ~s(id="closed-placeholder")
    end

    @tag :logged_in_user
    test "displays error if start invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"notification_specifier" => "custom"}})

      # Empty string clears the field so the required validation fires
      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"notification_period_start" => ""}})

      assert render(view) =~ "Enter a valid date and/or time"
    end

    @tag :logged_in_user
    test "scheduled start time must be after current time", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "notification_specifier" => "custom",
          "active_period_start_specifier" => "custom",
          "active_period_start" => "2124-04-30T15:54:00",
          "notification_period_start" => "2020-04-29T10:54:00"
        }
      })

      # The apostrophe in the error message is HTML-encoded in the rendered output
      assert render(view) =~ "Notifications can"
      assert render(view) =~ "t be set in the past"
    end

    @tag :logged_in_user
    test "scheduled start time must be before active period start", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom",
          "active_period_start" => "2124-05-01T10:54:00",
          "notification_specifier" => "custom",
          "notification_period_start" => "2124-05-02T09:00:00"
        }
      })

      assert render(view) =~ "Notification period must start on or before"
    end

    @tag :logged_in_user
    test "notification period start defaults to current time", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      # When specifier is :now (default), notification_period_start is set to current time
      socket = :sys.get_state(view.pid).socket
      assert socket.assigns.form[:notification_period_start].value != nil
    end

    @tag :logged_in_user
    test "works if editing", %{conn: conn} do
      alert_params =
        build(:alert_map, %{
          alert_id: "notif-edit-1",
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY",
          notification_period_start: ~U[2024-04-30 11:54:00Z],
          primary_service_type: "1"
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      {:ok, view, _html} = live(conn, "/alerts/mono/edit/notif-edit-1")

      assert render(view) =~ "2024-04-30"
    end

    @tag :logged_in_user
    test "no validation errors when fields are valid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "notification_specifier" => "custom",
          "notification_period_start" => "2124-04-30T15:53:00"
        }
      })

      refute render(view) =~ "Enter a valid date"
      refute render(view) =~ "Notifications can't be set in the past"
    end
  end
end
