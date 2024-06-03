defmodule AlertsUI.TimeframeTextTest do
  @moduledoc false
  use AlertsUI.DataCase
  alias AlertsUI.TimeframeText

  describe "timeframe_text/1" do
    test "Starts now, ends same calendar day" do
      now = format_datetime(~D[2024-02-25], ~T[22:00:00])
      start = now
      ending = format_datetime(~D[2024-02-25], ~T[23:59:00])

      assert TimeframeText.timeframe_text(start, ending, now) == nil
    end

    test "Starts now, ends next calendar day (before End of Service)" do
      now = format_datetime(~D[2024-02-25], ~T[22:00:00])
      start = now
      ending = format_datetime(~D[2024-02-26], ~T[01:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == nil
    end

    test "Starts now, ends next calendar day (between End of Service and Start of Service)" do
      now = format_datetime(~D[2024-02-25], ~T[22:00:00])
      start = now
      ending = format_datetime(~D[2024-02-26], ~T[03:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == nil
    end

    test "Starts now, ends next calendar day (after Start of Service)" do
      now = format_datetime(~D[2024-02-25], ~T[22:00:00])
      start = now
      ending = format_datetime(~D[2024-02-26], ~T[05:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == nil
    end

    test "Starts now, ends 2-6 calendar days later" do
      now = format_datetime(~D[2024-02-25], ~T[22:00:00])
      start = now
      ending = format_datetime(~D[2024-02-27], ~T[01:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == nil
    end

    test "Starts later today, ends same calendar day" do
      now = format_datetime(~D[2024-02-25], ~T[22:00:00])
      start = format_datetime(~D[2024-02-25], ~T[23:00:00])
      ending = format_datetime(~D[2024-02-25], ~T[23:59:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Later today"
    end

    test "Starts later today, ends next calendar day (before End of Service)" do
      now = format_datetime(~D[2024-02-25], ~T[22:00:00])
      start = format_datetime(~D[2024-02-25], ~T[23:00:00])
      ending = format_datetime(~D[2024-02-26], ~T[01:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Starting later today"
    end

    test "Starts later today, ends next calendar day (between End of Service and Start of Service)" do
      now = format_datetime(~D[2024-02-25], ~T[22:00:00])
      start = format_datetime(~D[2024-02-25], ~T[23:00:00])
      ending = format_datetime(~D[2024-02-26], ~T[03:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Starting later today"
    end

    test "Starts later today, ends next calendar day (after Start of Service)" do
      now = format_datetime(~D[2024-02-25], ~T[22:00:00])
      start = format_datetime(~D[2024-02-25], ~T[23:00:00])
      ending = format_datetime(~D[2024-02-26], ~T[05:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Starting later today"
    end

    test "Starts tomorrow, ends same calendar day (before End of Service)" do
      now = format_datetime(~D[2024-02-25], ~T[22:00:00])
      start = format_datetime(~D[2024-02-26], ~T[00:00:00])
      ending = format_datetime(~D[2024-02-26], ~T[01:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Tomorrow"
    end

    test "Starts tomorrow, ends same calendar day (between End of Service and Start of Service)" do
      now = format_datetime(~D[2024-02-25], ~T[22:00:00])
      start = format_datetime(~D[2024-02-26], ~T[00:00:00])
      ending = format_datetime(~D[2024-02-26], ~T[03:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Tomorrow"
    end

    test "Starts tomorrow, ends same calendar day (after Start of Service)" do
      now = format_datetime(~D[2024-02-25], ~T[22:00:00])
      start = format_datetime(~D[2024-02-26], ~T[00:00:00])
      ending = format_datetime(~D[2024-02-26], ~T[05:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Tomorrow"
    end

    test "Starts tomorrow, ends 2-6 calendar days later" do
      # ends before start of service 2 days from now
      now = format_datetime(~D[2024-02-25], ~T[22:00:00])
      start = format_datetime(~D[2024-02-26], ~T[00:00:00])
      ending = format_datetime(~D[2024-02-27], ~T[01:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Tomorrow"
    end

    test "Starts now (before End of Service), ends same calendar day" do
      now = format_datetime(~D[2024-02-26], ~T[00:00:00])
      start = now
      ending = format_datetime(~D[2024-02-26], ~T[01:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == nil
    end

    test "Starts now (before End of Service), ends same calendar day (between End of Service and Start of Service)" do
      now = format_datetime(~D[2024-02-26], ~T[00:00:00])
      start = now
      ending = format_datetime(~D[2024-02-26], ~T[03:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == nil
    end

    test "Starts now (before End of Service), ends same calendar day (after Start of Service)" do
      now = format_datetime(~D[2024-02-26], ~T[00:00:00])
      start = now
      ending = format_datetime(~D[2024-02-26], ~T[05:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == nil
    end

    test "Starts now (before End of Service), ends next calendar day (before End of Service)" do
      now = format_datetime(~D[2024-02-26], ~T[00:00:00])
      start = now
      ending = format_datetime(~D[2024-02-27], ~T[01:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == nil
    end

    test "Starts later today (between End of Service and Start of Service), ends same calendar day (between End of Service and Start of Service)" do
      now = format_datetime(~D[2024-02-26], ~T[00:00:00])
      start = format_datetime(~D[2024-02-26], ~T[03:00:00])
      ending = format_datetime(~D[2024-02-26], ~T[04:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Later today"
    end

    test "Starts later today (between End of Service and Start of Service), ends same calendar day (after Start of Service)" do
      now = format_datetime(~D[2024-02-26], ~T[00:00:00])
      start = format_datetime(~D[2024-02-26], ~T[03:00:00])
      ending = format_datetime(~D[2024-02-26], ~T[05:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Later today"
    end

    test "Starts later today (between End of Service and Start of Service), ends next calendar day (before End of Service)" do
      now = format_datetime(~D[2024-02-26], ~T[00:00:00])
      start = format_datetime(~D[2024-02-26], ~T[03:00:00])
      ending = format_datetime(~D[2024-02-27], ~T[01:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Starting later today"
    end

    test "Starts later today, ends next calendar day (at End of Service)" do
      now = format_datetime(~D[2024-02-26], ~T[22:00:00])
      start = format_datetime(~D[2024-02-26], ~T[23:00:00])
      ending = format_datetime(~D[2024-02-27], ~T[02:30:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Starting later today"
    end

    test "Starts tomorrow, ends same calendar day (at End of Service) " do
      now = format_datetime(~D[2024-02-26], ~T[22:00:00])
      start = format_datetime(~D[2024-02-27], ~T[01:00:00])
      ending = format_datetime(~D[2024-02-27], ~T[02:30:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Tomorrow"
    end

    test "Starts tomorrow (at End of Service), ends 2-6 calendar days later (at Start of Service)" do
      # ends after start of service 2 days from now
      now = format_datetime(~D[2024-02-26], ~T[22:00:00])
      start = format_datetime(~D[2024-02-27], ~T[02:30:00])
      ending = format_datetime(~D[2024-02-28], ~T[04:30:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Tomorrow through Tuesday"
    end

    test "Starts tomorrow (at End of Service), ends 2-6 calendar days later" do
      now = format_datetime(~D[2024-02-26], ~T[22:00:00])
      start = format_datetime(~D[2024-02-27], ~T[02:30:00])
      ending = format_datetime(~D[2024-03-04], ~T[02:30:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Tomorrow through Sunday"
    end

    test "Starts 2-6 calendar days in the future (at End of Service), ends 2-6 calendar days later (at End of Service)" do
      now = format_datetime(~D[2024-02-26], ~T[22:00:00])
      start = format_datetime(~D[2024-03-01], ~T[02:30:00])
      ending = format_datetime(~D[2024-03-04], ~T[02:30:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Friday through Sunday"
    end

    test "Starts 2-6 calendar days in the future (at Start of Service), ends 2-6 calendar days later (at End of Service)" do
      now = format_datetime(~D[2024-02-26], ~T[22:00:00])
      start = format_datetime(~D[2024-03-01], ~T[04:30:00])
      ending = format_datetime(~D[2024-03-04], ~T[02:30:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Friday through Sunday"
    end

    test "Starts 2-6 calendar days in the future, ends >6 calendar days later" do
      now = format_datetime(~D[2024-02-26], ~T[22:00:00])
      start = format_datetime(~D[2024-03-01], ~T[10:00:00])
      ending = format_datetime(~D[2024-03-31], ~T[10:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "Starting Friday"
    end

    test "Starts >6 calendar days, ends same calendar day" do
      now = format_datetime(~D[2024-02-26], ~T[22:00:00])
      start = format_datetime(~D[2024-03-22], ~T[06:00:00])
      ending = format_datetime(~D[2024-03-22], ~T[19:00:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "March 22"
    end

    test "Starts >6 calendar days in the future (before End of Service), ends >6 calendar days later (at End of Service)" do
      now = format_datetime(~D[2024-02-26], ~T[22:00:00])
      start = format_datetime(~D[2024-03-22], ~T[20:45:00])
      ending = format_datetime(~D[2024-03-25], ~T[02:30:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "March 22-24"
    end

    test "Starts >6 calendar days in the future (at End of Service), ends >6 calendar days later (at End of Service)" do
      now = format_datetime(~D[2024-02-26], ~T[22:00:00])
      start = format_datetime(~D[2024-03-22], ~T[02:30:00])
      ending = format_datetime(~D[2024-03-25], ~T[02:30:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "March 22-24"
    end

    test "Starts >6 calendar days in the future (at Start of Service), ends >6 calendar days later (at End of Service)" do
      now = format_datetime(~D[2024-02-26], ~T[22:00:00])
      start = format_datetime(~D[2024-03-22], ~T[04:30:00])
      ending = format_datetime(~D[2024-03-25], ~T[02:30:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "March 22-24"
    end

    test "Starts >6 calendar days in the future (at Start of Service), ends >6 calendar days later (at End of Service) in a different calendar month" do
      now = format_datetime(~D[2024-02-26], ~T[22:00:00])
      start = format_datetime(~D[2024-03-22], ~T[04:30:00])
      ending = format_datetime(~D[2024-04-02], ~T[02:30:00])

      assert TimeframeText.timeframe_text(start, ending, now) == "March 22-April 1"
    end
  end

  defp format_datetime(date, time) do
    # creates datetimes in UTC. this lets us see see a nice eastern datetime in our tests
    # but actually give the function the UTC date it would get in real life
    DateTime.new!(date, time, "America/New_York") |> DateTime.shift_zone!("Etc/UTC")
  end
end
