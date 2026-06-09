defmodule AlertsUIWeb.Tickets.FormCrashDeletingTimeValueTest do
  @moduledoc """
  Regression test for Asana ticket 1213275668858461
  "🐛 Form crashes after deleting time value"
  https://app.asana.com/0/1167196461144361/1213275668858461

  Two bugs involving deleting the minutes component of a time input:

  Issue 1: Create a recurring alert, set effect start to Custom with any time,
  then delete/clear the time value → the form crashed with a FunctionClauseError
  in string_to_time_helper (called Time.from_iso8601!("" <> ":00") which threw
  on empty string).

  Issue 2: Create a one-time alert, set effect start to Custom, delete the time,
  then switch to recurring → the form crashed with the same cause when
  get_recurring_start_datetime attempted to parse the now-empty time field.

  Fix: `string_to_time_helper/1` in TimeRangeGetters now uses a safe case that
  returns nil on error; `get_recurring_start_datetime/2` and
  `get_recurring_end_datetime/2` gained guard clauses to short-circuit when
  either date or time is an empty string.

  Tests:
    * TimeRangeGetters.get_recurring_start_datetime/2 returns "" for empty time
    * TimeRangeGetters.get_recurring_end_datetime/2 returns "" for empty time
    * LiveView form survives render_change with active_period_start_time = ""
      (Issue 1: recurring, custom start time, then clear it)
    * LiveView form survives render_change with cleared one-time start then
      switch to recurring (Issue 2)
  """

  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase

  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUIWeb.FormComponents.Helpers.TimeRangeGetters

  # ---------------------------------------------------------------------------
  # Unit tests: TimeRangeGetters helpers
  # ---------------------------------------------------------------------------

  describe "TimeRangeGetters — empty time guard clauses (ticket 1213275668858461)" do
    test "get_recurring_start_datetime/2 returns empty string when time is empty string" do
      # Before the fix, this would call string_to_time_helper("") which called
      # Time.from_iso8601!("" <> ":00") and raised FunctionClauseError.
      result = TimeRangeGetters.get_recurring_start_datetime("2026-03-01", "")

      assert result == "",
             "expected empty string when time is \"\", got: #{inspect(result)}"
    end

    test "get_recurring_start_datetime/2 returns empty string when date is empty string" do
      result = TimeRangeGetters.get_recurring_start_datetime("", "08:30")

      assert result == "",
             "expected empty string when date is \"\", got: #{inspect(result)}"
    end

    test "get_recurring_start_datetime/2 returns empty string when both date and time are empty" do
      result = TimeRangeGetters.get_recurring_start_datetime("", "")
      assert result == ""
    end

    test "get_recurring_end_datetime/2 returns empty string when time is empty string" do
      # Before the fix (9ed1487b), get_recurring_end_datetime(date, "") was missing the
      # guard and would fall through to string_to_time_helper(""), crashing.
      result = TimeRangeGetters.get_recurring_end_datetime("2026-03-01", "")

      assert result == "",
             "expected empty string when end time is \"\", got: #{inspect(result)}"
    end

    test "get_recurring_end_datetime/2 returns empty string when date is empty string" do
      result = TimeRangeGetters.get_recurring_end_datetime("", "20:00")
      assert result == ""
    end

    test "get_recurring_start_datetime/2 still works correctly for a valid date and time" do
      # Sanity: the happy path must still work after the fix.
      # The function returns a DateTime (timezone-aware, via DTHelpers.new_round_up_to_gap!/3).
      result = TimeRangeGetters.get_recurring_start_datetime("2026-03-01", "08:30")

      # Accept either DateTime or NaiveDateTime — the key is it resolves to a time struct
      assert match?(%DateTime{}, result) or match?(%NaiveDateTime{}, result),
             "expected a DateTime or NaiveDateTime for valid inputs, got: #{inspect(result)}"

      assert Map.get(result, :year) == 2026
      assert Map.get(result, :month) == 3
      assert Map.get(result, :day) == 1
      assert Map.get(result, :hour) == 8
      assert Map.get(result, :minute) == 30
    end
  end

  # ---------------------------------------------------------------------------
  # Integration tests: LiveView form does not crash
  # ---------------------------------------------------------------------------

  describe "mono alert form — form survives deleting time value (ticket 1213275668858461)" do
    @tag :logged_in_user
    test "Issue 1: recurring alert, clear custom start time → form must not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")

      # Navigate to the Alert Details step: Subway / Delay
      get_to_submission_page_refactor(view, "Subway", "Delay")

      # Switch to recurring timing
      view
      |> element("form")
      |> render_change(%{
        "_target" => ["alert_data", "alert_timing"],
        "alert_data" => %{"alert_timing" => "recurring"}
      })

      # Set start time specifier to custom (reveals the time input)
      view
      |> element("form")
      |> render_change(%{
        "_target" => ["alert_data", "active_period_start_time_specifier"],
        "alert_data" => %{
          "alert_timing" => "recurring",
          "active_period_start_time_specifier" => "custom"
        }
      })

      # Now clear the time value (simulates the user deleting the minutes component).
      # Before the fix, this caused a FunctionClauseError crash in the LiveView.
      html =
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "active_period_start_time"],
          "alert_data" => %{
            "alert_timing" => "recurring",
            "active_period_start_time_specifier" => "custom",
            "active_period_start_time" => ""
          }
        })

      # If render_change raised, the test would already have failed.
      # The form must still contain alert_data fields (not crashed/replaced with an error page).
      # render_change returns the partial form HTML; layout flash elements are not included.
      assert html =~ "alert_data",
             "form should still be rendered after clearing start time; got: #{String.slice(html, 0, 200)}"

      refute html =~ "Internal Server Error",
             "form must not show a server error response after clearing start time"

      # Also verify the time range section is still present (form hasn't collapsed)
      assert html =~ "time_range" or html =~ "active_period",
             "time range section should still be rendered in the form"
    end

    @tag :logged_in_user
    test "Issue 2: one-time alert, clear custom start, switch to recurring → form must not crash",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")

      get_to_submission_page_refactor(view, "Subway", "Delay")

      # Set one-time start specifier to custom (reveals the datetime-local input)
      view
      |> element("form")
      |> render_change(%{
        "_target" => ["alert_data", "active_period_start_specifier"],
        "alert_data" => %{
          "alert_timing" => "one-time",
          "active_period_start_specifier" => "custom"
        }
      })

      # Clear the one-time start datetime (simulates deleting the time portion)
      view
      |> element("form")
      |> render_change(%{
        "_target" => ["alert_data", "active_period_start"],
        "alert_data" => %{
          "alert_timing" => "one-time",
          "active_period_start_specifier" => "custom",
          "active_period_start" => ""
        }
      })

      # Switch to recurring — before the fix, this caused the crash
      html =
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "alert_timing"],
          "alert_data" => %{
            "alert_timing" => "recurring",
            "active_period_start_specifier" => "custom",
            "active_period_start" => ""
          }
        })

      assert html =~ "alert_data",
             "form should still be rendered after clearing one-time start then switching to recurring"

      refute html =~ "Internal Server Error",
             "form must not show a server error response after the timing switch"

      assert html =~ "time_range" or html =~ "active_period",
             "time range section should still be rendered in the form"
    end
  end
end
