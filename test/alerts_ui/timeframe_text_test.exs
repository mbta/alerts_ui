defmodule AlertsUI.TimeframeTextTest do
  @moduledoc false
  use AlertsUI.DataCase
  alias AlertsUI.Models.ActivePeriod
  alias AlertsUI.TimeframeText

  describe "one time alerts - effect start within past 7 days" do
    setup do
      now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])

      %{
        recurring: false,
        now: now,
        start: DateTime.add(now, -5, :day)
      }
    end

    test "effect end - further notice", %{recurring: recurring, now: now, start: start} do
      ending = nil
      duration_certainty = :UNKNOWN

      assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
               nil
    end

    test "effect end - later today", %{recurring: recurring, now: now, start: start} do
      duration_certainty = :ESTIMATED
      ending = DateTime.add(now, 2, :hour)

      assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
               nil
    end

    test "effect end - today", %{recurring: recurring, now: now, start: start} do
      duration_certainty = :KNOWN
      ending = DateTime.add(now, 2, :hour)

      assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
               nil
    end

    test "effect end - tomorrow", %{recurring: recurring, now: now, start: start} do
      duration_certainty = :KNOWN
      ending = DateTime.add(now, 1, :day)

      assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
               "through tomorrow"
    end
  end

  describe "one time alerts - effect start >=7 days ago" do
    setup do
      now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])

      %{
        recurring: false,
        now: now,
        start: DateTime.add(now, -8, :day)
      }
    end

    test "effect end - further notice", %{recurring: recurring, now: now, start: start} do
      ending = nil
      duration_certainty = :UNKNOWN

      assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
               "ongoing"
    end

    test "effect end - later today", %{recurring: recurring, now: now, start: start} do
      ending = DateTime.add(now, 2, :hour)
      duration_certainty = :ESTIMATED

      assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
               "ongoing"
    end

    test "effect end - today", %{recurring: recurring, now: now, start: start} do
      ending = DateTime.add(now, 2, :hour)
      duration_certainty = :KNOWN

      assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
               "last day"
    end

    # Below are effectively the same as the tests
    test "effect end - 2-6 days from today", %{
      now: now,
      start: start,
      recurring: recurring
    } do
      # 6 days from now is 3/2, but make it 3/3 since end of service is 3AM
      ending = utc_datetime_from_local(~D[2024-03-03], ActivePeriod.end_of_service_time())
      duration_certainty = :KNOWN

      assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
               "through Saturday"
    end
  end

  describe "recurring alerts - start within past 30 days ago" do
    setup do
      now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])

      %{
        recurring: true,
        now: now,
        start: DateTime.add(now, -28, :day)
      }
    end

    test "effect end - further notice", %{recurring: recurring, now: now, start: start} do
      ending = nil
      duration_certainty = :UNKNOWN

      assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
               nil
    end

    test "effect end - later today", %{recurring: recurring, now: now, start: start} do
      ending = DateTime.add(now, 2, :hour)
      duration_certainty = :ESTIMATED

      assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
               nil
    end

    test "effect end - today", %{recurring: recurring, now: now, start: start} do
      ending = DateTime.add(now, 2, :hour)
      duration_certainty = :KNOWN

      assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
               nil
    end
  end

  describe "recurring alerts - start >=30 days ago" do
    setup do
      now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])

      %{
        recurring: true,
        now: now,
        start: DateTime.add(now, -31, :day)
      }
    end

    test "effect end - further notice", %{recurring: recurring, now: now, start: start} do
      ending = nil
      duration_certainty = :UNKNOWN

      assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
               "ongoing"
    end

    test "effect end - later today", %{recurring: recurring, now: now, start: start} do
      ending = DateTime.add(now, 2, :hour)
      duration_certainty = :ESTIMATED

      assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
               "ongoing"
    end

    test "effect end - today", %{recurring: recurring, now: now, start: start} do
      ending = DateTime.add(now, 2, :hour)
      duration_certainty = :KNOWN

      assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
               "last day"
    end
  end

  test "recurring - starts now or within 30 minutes" do
    recurring = true
    now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])
    start = now
    ending = DateTime.add(now, 1, :day)
    # starts now
    assert TimeframeText.timeframe_text(start, ending, recurring, :KNOWN, now) == "starting today"

    # starts in 30 min
    start_in_30 = DateTime.add(now, 30, :minute)

    assert TimeframeText.timeframe_text(start_in_30, ending, recurring, :KNOWN, now) ==
             "starting today"
  end

  describe "known end, one-time, effect start agnostic" do
    setup do
      now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])

      starts = [
        %{name: "now", datetime: now},
        %{name: "in 30 minutes", datetime: DateTime.add(now, 30, :minute)},
        %{name: "recently", datetime: DateTime.add(now, -5, :day)},
        %{name: "a while ago", datetime: DateTime.add(now, -20, :day)}
      ]

      %{
        now: now,
        starts: starts,
        recurring: false
      }
    end

    test "effect end - tomorrow (at end of service)", %{
      now: now,
      starts: starts,
      recurring: recurring
    } do
      ending = utc_datetime_from_local(~D[2024-02-27], ActivePeriod.end_of_service_time())
      duration_certainty = :KNOWN

      Enum.each(starts, fn %{name: name, datetime: start} ->
        assert TimeframeText.timeframe_text(
                 start,
                 ending,
                 recurring,
                 duration_certainty,
                 now
               ) ==
                 "through tomorrow",
               "starts #{name} and ends tomorrow"
      end)
    end

    test "effect end - 2 to 6 days from today", %{
      now: now,
      starts: starts,
      recurring: recurring
    } do
      # Friday, March 1st 2024
      ending = DateTime.add(now, 5, :day)
      duration_certainty = :KNOWN

      Enum.each(starts, fn %{name: name, datetime: start} ->
        assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
                 "through Friday",
               "starts #{name} and ends 2-6 days from today"
      end)
    end

    test "effect end - 6 days from today at end of service", %{
      now: now,
      starts: starts,
      recurring: recurring
    } do
      # 6 days from now is 3/2, but make it 3/3 since end of service is 3AM
      ending = utc_datetime_from_local(~D[2024-03-03], ActivePeriod.end_of_service_time())
      duration_certainty = :KNOWN

      Enum.each(starts, fn %{name: name, datetime: start} ->
        assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
                 "through Saturday",
               "starts #{name} and ends 6 days from today end of service"
      end)
    end

    test "effect end - 7 to 90 days from today", %{
      now: now,
      starts: starts,
      recurring: recurring
    } do
      # Sunday, March 3rd 2024
      ending_7 = DateTime.add(now, 7, :day)
      # Saturday, May 25th 2024
      ending_90 = DateTime.add(now, 90, :day)
      duration_certainty = :KNOWN

      Enum.each(starts, fn %{name: name, datetime: start} ->
        assert TimeframeText.timeframe_text(
                 start,
                 ending_7,
                 recurring,
                 duration_certainty,
                 now
               ) ==
                 "through March 3",
               "starts #{name}, ends in 7 days"

        assert TimeframeText.timeframe_text(
                 start,
                 ending_90,
                 recurring,
                 duration_certainty,
                 now
               ) ==
                 "through May 25",
               "starts #{name}, ends in 90 days"
      end)
    end

    test "effect end - >90 days but still this year", %{
      now: now,
      starts: starts,
      recurring: recurring
    } do
      # Saturday, May 25th 2024
      ending_90 = DateTime.add(now, 120, :day)
      duration_certainty = :KNOWN

      Enum.each(starts, fn %{name: name, datetime: start} ->
        assert TimeframeText.timeframe_text(
                 start,
                 ending_90,
                 recurring,
                 duration_certainty,
                 now
               ) == "until June",
               "starts #{name}, ends >90 days but still this year"
      end)
    end

    test "effect end - >90 days but still this year (until Dec end of service)", %{
      now: now,
      starts: starts,
      recurring: recurring
    } do
      ending = utc_datetime_from_local(~D[2024-12-31], ActivePeriod.end_of_service_time())
      duration_certainty = :KNOWN

      Enum.each(starts, fn %{name: name, datetime: start} ->
        assert TimeframeText.timeframe_text(
                 start,
                 ending,
                 recurring,
                 duration_certainty,
                 now
               ) == "until December",
               "starts #{name}, ends Dec end of service"
      end)
    end

    test "effect end - >90 days but next year or beyond", %{
      now: now,
      starts: starts,
      recurring: recurring
    } do
      # Saturday, May 25th 2024
      ending_90 = DateTime.add(now, 320, :day)
      duration_certainty = :KNOWN

      Enum.each(starts, fn %{name: name, datetime: start} ->
        assert TimeframeText.timeframe_text(
                 start,
                 ending_90,
                 recurring,
                 duration_certainty,
                 now
               ) ==
                 "until January 2025",
               "starts #{name} and ends next year"
      end)
    end

    test "effect end - >90 days but on Jan 1 start of service", %{
      now: now,
      starts: starts,
      recurring: recurring
    } do
      start_of_service = Time.add(ActivePeriod.start_of_service_time(), 1, :second)
      ending = utc_datetime_from_local(~D[2025-01-01], start_of_service)
      duration_certainty = :KNOWN

      Enum.each(starts, fn %{name: name, datetime: start} ->
        assert TimeframeText.timeframe_text(
                 start,
                 ending,
                 recurring,
                 duration_certainty,
                 now
               ) ==
                 "until January 2025",
               "starts #{name} ends on Jan 1 start of service"
      end)
    end

    test "effect end - within 90 days but at the end of the year" do
      now = utc_datetime_from_local(~D[2024-12-25], ~T[22:00:00])

      starts = [
        %{name: "now", datetime: now},
        %{name: "in 30 minutes", datetime: DateTime.add(now, 30, :minute)},
        %{name: "recently", datetime: DateTime.add(now, -5, :day)},
        %{name: "a while ago", datetime: DateTime.add(now, -20, :day)}
      ]

      duration_certainty = :KNOWN
      recurring = false

      ending = DateTime.add(now, 20, :day)

      Enum.each(starts, fn %{name: name, datetime: start} ->
        assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
                 "through January 14",
               "starts #{name} and ends within 90 days in same year"
      end)
    end
  end

  describe "starts later today" do
    setup do
      now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])

      %{
        now: now,
        start: DateTime.add(now, 1, :hour)
      }
    end

    test "effect end - today (at end of service)", %{now: now, start: start} do
      ending = utc_datetime_from_local(~D[2024-02-26], ActivePeriod.end_of_service_time())

      assert TimeframeText.timeframe_text(start, ending, false, :KNOWN, now) == "later today"
      assert TimeframeText.timeframe_text(start, ending, true, :KNOWN, now) == "later today"
    end

    test "effect end - after today", %{now: now, start: start} do
      ending = DateTime.add(now, 1, :day)

      assert TimeframeText.timeframe_text(start, ending, false, :KNOWN, now) ==
               "starting later today"

      assert TimeframeText.timeframe_text(start, ending, true, :KNOWN, now) ==
               "starting later today"
    end

    test "effect end - until further notice", %{now: now, start: start} do
      ending = nil

      assert TimeframeText.timeframe_text(start, ending, false, :UNKNOWN, now) ==
               "starting later today"

      assert TimeframeText.timeframe_text(start, ending, true, :UNKNOWN, now) ==
               "starting later today"
    end
  end

  describe "starts tomorrow" do
    setup do
      now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])

      %{
        now: now,
        start: DateTime.add(now, 1, :day)
      }
    end

    test "ends tomorrow", %{now: now, start: start} do
      ending = DateTime.add(now, 1, :day) |> DateTime.add(1, :hour)

      assert TimeframeText.timeframe_text(start, ending, false, :KNOWN, now) == "tomorrow"
      assert TimeframeText.timeframe_text(start, ending, true, :KNOWN, now) == "tomorrow"
    end

    test "ends <= 7 days from now", %{now: now, start: start} do
      ending = DateTime.add(now, 7, :day)

      assert TimeframeText.timeframe_text(start, ending, false, :KNOWN, now) ==
               "tomorrow through Sunday"

      assert TimeframeText.timeframe_text(start, ending, true, :KNOWN, now) ==
               "tomorrow through Sunday"
    end

    test "ends > 7 days from now", %{now: now, start: start} do
      ending = DateTime.add(now, 8, :day)

      assert TimeframeText.timeframe_text(start, ending, false, :KNOWN, now) ==
               "starting tomorrow"

      assert TimeframeText.timeframe_text(start, ending, true, :KNOWN, now) == "starting tomorrow"
    end

    test "end effect - further notice", %{now: now, start: start} do
      ending = nil

      assert TimeframeText.timeframe_text(start, ending, false, :UNKNOWN, now) ==
               "starting tomorrow"

      assert TimeframeText.timeframe_text(start, ending, true, :UNKNOWN, now) ==
               "starting tomorrow"
    end
  end

  describe "starts after tomorrow but within 6 days" do
    setup do
      now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])

      %{
        now: now,
        start: DateTime.add(now, 5, :day)
      }
    end

    test "ends same day as start date", %{now: now, start: start} do
      ending = DateTime.add(start, 1, :hour)

      assert TimeframeText.timeframe_text(start, ending, false, :KNOWN, now) == "Friday"
      assert TimeframeText.timeframe_text(start, ending, true, :KNOWN, now) == "Friday"
    end

    test "ends <= 7 days from now", %{now: now, start: start} do
      ending = DateTime.add(now, 7, :day)

      assert TimeframeText.timeframe_text(start, ending, false, :KNOWN, now) ==
               "Friday through Sunday"

      assert TimeframeText.timeframe_text(start, ending, true, :KNOWN, now) ==
               "Friday through Sunday"
    end

    test "ends > 7 days from now", %{now: now, start: start} do
      ending = DateTime.add(now, 8, :day)

      assert TimeframeText.timeframe_text(start, ending, false, :KNOWN, now) == "starting Friday"
      assert TimeframeText.timeframe_text(start, ending, true, :KNOWN, now) == "starting Friday"
    end

    test "end effect - further notice", %{now: now, start: start} do
      ending = nil

      assert TimeframeText.timeframe_text(start, ending, false, :UNKNOWN, now) ==
               "starting Friday"

      assert TimeframeText.timeframe_text(start, ending, true, :UNKNOWN, now) == "starting Friday"
    end
  end

  test "starts on a Saturday within 6 days and ends the Sunday directly after" do
    # Saturday, Feb 24th
    start = utc_datetime_from_local(~D[2024-02-24], ~T[22:00:00])
    # Currently 5 days before Saturday
    now = DateTime.add(start, -5, :day)
    # Sunday, Feb 25th
    ending = utc_datetime_from_local(~D[2024-02-25], ~T[21:00:00])

    assert TimeframeText.timeframe_text(start, ending, false, :KNOWN, now) == "this weekend"
    assert TimeframeText.timeframe_text(start, ending, true, :KNOWN, now) == "this weekend"
  end

  describe "starts >= 7 days from now" do
    setup do
      now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])

      %{
        now: now,
        # March 3rd
        start: DateTime.add(now, 7, :day)
      }
    end

    test "ends same day as start date", %{now: now, start: start} do
      ending = DateTime.add(start, 1, :hour)

      assert TimeframeText.timeframe_text(start, ending, false, :KNOWN, now) == "March 3"
      assert TimeframeText.timeframe_text(start, ending, true, :KNOWN, now) == "March 3"
    end

    test "ends same month as start date", %{now: now, start: start} do
      ending = utc_datetime_from_local(~D[2024-03-31], ~T[22:00:00])

      assert TimeframeText.timeframe_text(start, ending, false, :KNOWN, now) == "March 3-31"
      assert TimeframeText.timeframe_text(start, ending, true, :KNOWN, now) == "March 3-31"
    end

    test "ends different month from start date", %{now: now, start: start} do
      ending = DateTime.add(start, 40, :day)

      assert TimeframeText.timeframe_text(start, ending, false, :KNOWN, now) == "starting March 3"
      assert TimeframeText.timeframe_text(start, ending, true, :KNOWN, now) == "starting March 3"
    end

    test "end effect - further notice", %{now: now, start: start} do
      ending = nil

      assert TimeframeText.timeframe_text(start, ending, false, :UNKNOWN, now) ==
               "starting March 3"

      assert TimeframeText.timeframe_text(start, ending, true, :UNKNOWN, now) ==
               "starting March 3"
    end
  end

  def utc_datetime_from_local(date, time) do
    # creates datetimes in UTC. this lets us see see a nice eastern datetime in our tests
    # but actually give the function the UTC date it would get in real life
    DateTime.new!(date, time, "America/New_York") |> DateTime.shift_zone!("Etc/UTC")
  end
end
