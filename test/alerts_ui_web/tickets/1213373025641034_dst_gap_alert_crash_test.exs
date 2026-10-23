defmodule AlertsUIWeb.Tickets.DstGapAlertCrashTest do
  @moduledoc """
  Regression test for Asana ticket 1213373025641034 —
  "🐛 App crashes when creating an alert with a datetime during the non-existent DST hour"
  https://app.asana.com/0/1167196461144361/1213373025641034

  ## Bug

  When a user entered a datetime that falls within the non-existent Daylight
  Saving Time "spring forward" gap (e.g. 2:30 AM on March 8, 2026, which does
  not exist in the America/New_York timezone), the application either:

  * Crashed the LiveView (for one-time alerts) because subsequent validators
    called `localize/1` on the invalid datetime, which internally calls
    `DateTime.from_naive/2` and gets `{:gap, _, _}` rather than `{:ok, _}`.
  * Crashed the entire application and required a manual DB fix (for Issue 2 —
    the 24-hours-after-DST scenario, addressed separately in another ticket).

  ## Fix (commit 645d587b)

  `validate_not_dst_gap/1` was moved to run **before** `validate_end_after_start/1`
  and `validate_start_is_after_now/1` in the validation pipeline. Those two
  validators call `localize/1` on `active_period_start` — if the DST error is
  already recorded before they run, they now skip safely (checking
  `Keyword.get_values(changeset.errors, :active_period_start) == []`).

  ## Acceptance criteria (ticket)

  1. When effect start or end falls within the non-existent DST hour, a form
     validation error appears with the exact message:
     "Effect periods cannot start or end during a skipped daylight savings time hour"
  2. The form does NOT crash — it shows the error and remains usable.
  3. This applies to both one-time (start) and one-time (end) datetime fields.
  4. Recurring alerts are also covered (the `validate_not_dst_gap` validator
     runs on `active_period_start` regardless of timing type).

  ## Test approach

  These tests drive the LiveView form at `/alerts/new` to verify that:
  - The exact error message appears for DST gap inputs on start, end, and both.
  - No other errors (crash indicators) appear alongside the DST error.
  - Validator ordering is pinned: entering a DST time AND simultaneously
    triggering `validate_end_after_start` (by also setting the end earlier than
    start) does not crash — DST error appears first, ordering is safe.
  - Valid times just before (1:59 AM) and just after (3:00 AM) the gap do NOT
    produce a DST error.
  """

  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase

  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  # 2026 DST date: March 8, 2026. Clocks spring forward 2:00 AM → 3:00 AM ET.
  # Any time between 02:00:00 and 02:59:59 does not exist in America/New_York.
  @dst_gap_start ~N[2026-03-08 02:00:00]
  @dst_gap_mid ~N[2026-03-08 02:30:00]
  @dst_gap_end ~N[2026-03-08 02:59:59]
  @before_gap ~N[2026-03-08 01:59:00]
  @after_gap ~N[2026-03-08 03:00:00]

  @dst_error "Effect periods cannot start or end during a skipped daylight savings time hour"

  describe "DST gap validation — one-time alerts (ticket 1213373025641034)" do
    @tag :logged_in_user
    test "shows exact DST error when effect start is in the 2026 DST gap", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      # Set start specifier to custom to expose the datetime field
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"active_period_start_specifier" => "custom"}
      })

      # Enter a time in the DST gap
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"active_period_start" => NaiveDateTime.to_iso8601(@dst_gap_mid)}
      })

      html = render(view)

      assert html =~ @dst_error,
             "Expected DST gap validation error for start = #{@dst_gap_mid}"

      # The page must still be alive (no crash = form continues to render)
      assert html =~ "Effect period"
    end

    @tag :logged_in_user
    test "shows exact DST error when effect end is in the 2026 DST gap", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      # Set both specifiers to custom
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom",
          "active_period_end_specifier" => "custom"
        }
      })

      # Set start to a valid time before the gap
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"active_period_start" => NaiveDateTime.to_iso8601(@before_gap)}
      })

      # Set end to a time inside the DST gap
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"active_period_end" => NaiveDateTime.to_iso8601(@dst_gap_mid)}
      })

      html = render(view)

      assert html =~ @dst_error,
             "Expected DST gap validation error for end = #{@dst_gap_mid}"

      assert html =~ "Effect period"
    end

    @tag :logged_in_user
    test "DST error shown at both the start and end of the gap hour (boundary check)", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"active_period_start_specifier" => "custom"}
      })

      # 2:00 AM exactly — should error
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"active_period_start" => NaiveDateTime.to_iso8601(@dst_gap_start)}
      })

      assert render(view) =~ @dst_error, "2:00 AM should be in DST gap"

      # 2:59 PM — should error
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"active_period_start" => NaiveDateTime.to_iso8601(@dst_gap_end)}
      })

      assert render(view) =~ @dst_error, "2:59 AM should be in DST gap"
    end

    @tag :logged_in_user
    test "no DST error for valid times just before and just after the gap", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"active_period_start_specifier" => "custom"}
      })

      # 1:59 AM — just before gap, should NOT trigger DST error
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"active_period_start" => NaiveDateTime.to_iso8601(@before_gap)}
      })

      refute render(view) =~ @dst_error, "1:59 AM is before the gap; should not error"

      # 3:00 AM — just after gap, should NOT trigger DST error
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"active_period_start" => NaiveDateTime.to_iso8601(@after_gap)}
      })

      refute render(view) =~ @dst_error, "3:00 AM is after the gap; should not error"
    end

    @tag :logged_in_user
    test "validator ordering: DST start error does not cause crash when end-before-start also applies",
         %{conn: conn} do
      # This is the crash scenario from the bug: when `active_period_start` is
      # in the DST gap, `validate_end_after_start` would call `localize/1` on
      # the gap datetime, crashing the LiveView. The fix runs `validate_not_dst_gap`
      # first so errors on `active_period_start` are recorded before the
      # localise-dependent validators skip them.
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom",
          "active_period_end_specifier" => "custom"
        }
      })

      # Deliberately put start AFTER end AND in the DST gap — both validators
      # would fire. Without the fix, localize() on the DST start crashes.
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => NaiveDateTime.to_iso8601(@dst_gap_mid),
          "active_period_end" => "2026-03-08T01:00:00"
        }
      })

      html = render(view)

      # The LiveView must still be alive (no crash)
      assert html =~ "Effect period", "LiveView should still be rendering the form"

      # At minimum the DST error must appear
      assert html =~ @dst_error,
             "DST gap error must be shown even when end-before-start also applies"
    end
  end
end
