defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.NotificationPeriodSliceTest do
  @moduledoc false
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import AlertsUI.Support.Factory
  import Test.Support.Helpers
  alias AlertsUI.Alerts

  defp create_test_alert(alert_id, opts \\ []) do
    start = Keyword.get(opts, :active_period_start, ~U[2024-05-10 14:30:54Z])

    ap =
      build(
        :active_period,
        Keyword.get(opts, :active_period_attrs, %{start: start})
      )

    base = %{
      alert_id: alert_id,
      active_period: [Map.from_struct(ap)],
      active_period_start: start,
      duration_certainty: Keyword.get(opts, :duration_certainty, :UNKNOWN),
      effect: Keyword.get(opts, :effect, :OTHER_EFFECT),
      effect_detail: Keyword.get(opts, :effect_detail, "DELAY"),
      informed_entity: [%{route_type: 3, activities: [:BOARD]}],
      reminder_times: [],
      severity: 4,
      primary_service_type: "3",
      description_text: nil
    }

    base =
      case Keyword.get(opts, :notification_period_start) do
        nil -> base
        nps -> Map.put(base, :notification_period_start, nps)
      end

    {:ok, _} = Alerts.create_or_update_alert(build(:alert_map, base), build(:user))
  end

  defp future_utc(offset_days) do
    DateTime.utc_now() |> DateTime.add(offset_days, :day) |> DateTime.truncate(:second)
  end

  defp eastern_now do
    DateTime.now!("America/New_York") |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)
  end

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      view = get_to_submission_page_refactor(conn, view, "Bus", "Delay")
      assert render(view) =~ ~s(id="notification_period_view")
    end

    @tag :logged_in_user
    test "'when alert is closed' hidden when same_as_effect_period selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      view = get_to_submission_page_refactor(conn, view, "Bus", "Delay")

      # Default specifier (:now) shows the "When alert is closed" placeholder
      assert render(view) =~ ~s(id="closed-placeholder")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"notification_specifier" => "same_as_effect_period"}
      })

      refute render(view) =~ ~s(id="closed-placeholder")
    end

    @tag :logged_in_user
    test "start date picker appears when start_of_service selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      view = get_to_submission_page_refactor(conn, view, "Bus", "Delay")

      # Default specifier (:now) does not show the date picker
      refute render(view) =~ ~s(phx-feedback-for="alert_data[notification_period_start_date]")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"notification_specifier" => "start_of_service"}
      })

      assert render(view) =~ ~s(phx-feedback-for="alert_data[notification_period_start_date]")
    end

    @tag :logged_in_user
    test "displays error if start invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      view = get_to_submission_page_refactor(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"notification_specifier" => "custom"}})

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"notification_period_start" => "a"}})

      assert render(view) =~ "Enter a valid date and time"
    end

    @tag :logged_in_user
    test "scheduled start time must not be in the past", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      view = get_to_submission_page_refactor(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "notification_specifier" => "custom",
          "notification_period_start" => "2024-04-29T10:54:00"
        }
      })

      assert render(view) =~ "Notifications can&#39;t be set in the past"
    end

    @tag :logged_in_user
    test "scheduled start time must be before the notification period end", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      view = get_to_submission_page_refactor(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom",
          "active_period_end_specifier" => "custom",
          "notification_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => "2040-05-01T10:54:00",
          "active_period_end" => "2040-05-02T10:54:00",
          "notification_period_start" => "2040-05-03T10:54:00"
        }
      })

      assert render(view) =~
               "Notification period must start on or before 05/02/2040"
    end

    @tag :logged_in_user
    test "minimum times on calendar set correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")

      now =
        DateTime.now!("America/New_York")
        |> DateTime.to_naive()
        |> NaiveDateTime.truncate(:second)

      view = get_to_submission_page_refactor(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "notification_specifier" => "custom"
        }
      })

      expected_datetime =
        now
        |> NaiveDateTime.to_iso8601()
        |> String.slice(0..-4//1)

      assert view |> element("#alert_data_notification_period_start") |> render() =~
               ~s(min="#{expected_datetime}")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "notification_specifier" => "start_of_service"
        }
      })

      expected_date =
        now
        |> NaiveDateTime.to_date()
        |> Date.to_iso8601()

      assert view |> element("#alert_data_notification_period_start_date") |> render() =~
               ~s(min="#{expected_date}")
    end

    @tag :logged_in_user
    test "maximum times on calendar set correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")

      view = get_to_submission_page_refactor(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "notification_specifier" => "custom",
          "active_period_end_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end" => ~N[2026-06-25 12:12:12]
        }
      })

      expected_datetime =
        ~N[2026-06-25 12:12:12]
        |> NaiveDateTime.to_iso8601()
        |> String.slice(0..-4//1)

      assert view |> element("#alert_data_notification_period_start") |> render() =~
               ~s(max="#{expected_datetime}")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "until_further_notice"
        }
      })

      assert view |> element("#alert_data_notification_period_start") |> render() =~
               ~s(max=\"\")
    end
  end

  describe "editing" do
    @tag :logged_in_user
    test "editing checks notification start time", %{conn: conn} do
      create_test_alert("np-edit-1")

      {:ok, view, _html} = live(conn, "/alerts/mono/edit/np-edit-1")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "notification_specifier" => "custom",
          "notification_period_start" => "2024-04-29T10:54:00"
        }
      })

      assert render(view) =~ "Notifications can&#39;t be set in the past"
    end

    @tag :logged_in_user
    test "notification after now but before a future effect start is valid (req 1)", %{conn: conn} do
      create_test_alert("np-future-start",
        active_period_start: future_utc(60),
        active_period_attrs: %{start: future_utc(60), end: future_utc(61)},
        notification_period_start: future_utc(1)
      )

      {:ok, view, _html} = live(conn, "/alerts/mono/edit/np-future-start")

      notification = eastern_now() |> NaiveDateTime.add(2, :day) |> NaiveDateTime.to_iso8601()

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "notification_specifier" => "custom",
          "notification_period_start" => notification
        }
      })

      html = render(view)
      refute html =~ "Notifications can&#39;t be set in the past"
      refute html =~ "Notification period must start on or before"
    end

    @tag :logged_in_user
    test "a saved past notification stays valid until modified (req 2)", %{conn: conn} do
      create_test_alert("np-past-notif", notification_period_start: ~U[2024-04-29 14:54:00Z])

      {:ok, view, _html} = live(conn, "/alerts/mono/edit/np-past-notif")

      # On load the existing past value is not flagged
      refute render(view) =~ "Notifications can&#39;t be set in the past"

      # Changing it to a different past value surfaces the error
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "notification_specifier" => "custom",
          "notification_period_start" => "2024-04-28T10:54:00"
        }
      })

      assert render(view) =~ "Notifications can&#39;t be set in the past"
    end

    @tag :logged_in_user
    test "minimum times on calendar set to nil", %{conn: conn} do
      create_test_alert("np-edit-1")

      {:ok, view, _html} = live(conn, "/alerts/mono/edit/np-edit-1")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "notification_specifier" => "custom"
        }
      })

      assert view |> element("#alert_data_notification_period_start") |> render() =~
               ~s(min="")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "notification_specifier" => "start_of_service"
        }
      })

      assert view |> element("#alert_data_notification_period_start_date") |> render() =~
               ~s(min="")
    end
  end

  describe "duplicating" do
    @tag :logged_in_user
    test "duplicating DOES check start time", %{conn: conn} do
      create_test_alert("np-dup-1")

      {:ok, view, _html} = live(conn, "/alerts/mono/duplicate/np-dup-1")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "notification_specifier" => "custom",
          "notification_period_start" => "2024-04-29T10:54:00"
        }
      })

      assert render(view) =~ "Notifications can&#39;t be set in the past"
    end
  end
end
