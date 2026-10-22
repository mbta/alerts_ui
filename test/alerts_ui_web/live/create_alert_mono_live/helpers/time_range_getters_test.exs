defmodule AlertsUIWeb.CreateAlertLive.Helpers.TimeRangeGettersTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use AlertsUIWeb.ConnCase

  alias AlertsUIWeb.FormComponents.Helpers.TimeRangeGetters

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
    # The function returns a DateTime (timezone-aware, via DTHelpers.round_up_to_gap!/3).
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
