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
  end

  describe "one time alerts - effect start >=7 days ago" do
    setup do
      now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])

      %{
        recurring: false,
        now: now,
        start: DateTime.add(now, -7, :day)
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
        start: DateTime.add(now, -30, :day)
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

  describe "starts now or within 30 minutes" do
    setup do
      now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])

      %{
        now: now,
        start_now: now,
        start_in_30: DateTime.add(now, 30, :minute)
      }
    end

    test "effect end - tomorrow", %{now: now, start_now: start_now, start_in_30: start_in_30} do
      ending = DateTime.add(now, 1, :day)
      duration_certainty = :KNOWN

      Enum.each([true, false], fn recurring ->
        Enum.each([start_now, start_in_30], fn start ->
          assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
                   "through tomorrow"
        end)
      end)
    end

    test "effect end - 2 to 6 days from today", %{
      now: now,
      start_now: start_now,
      start_in_30: start_in_30
    } do
      # Friday, March 1st 2024
      ending = DateTime.add(now, 5, :day)
      duration_certainty = :KNOWN

      Enum.each([true, false], fn recurring ->
        Enum.each([start_now, start_in_30], fn start ->
          assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
                   "through Friday"
        end)
      end)
    end

    test "effect end - 7 to 90 days from today", %{
      now: now,
      start_now: start_now,
      start_in_30: start_in_30
    } do
      # Sunday, March 3rd 2024
      ending_7 = DateTime.add(now, 7, :day)
      # Saturday, May 25th 2024
      ending_90 = DateTime.add(now, 90, :day)
      duration_certainty = :KNOWN

      Enum.each([true, false], fn recurring ->
        Enum.each([start_now, start_in_30], fn start ->
          assert TimeframeText.timeframe_text(start, ending_7, recurring, duration_certainty, now) ==
                   "through March 3"

          assert TimeframeText.timeframe_text(
                   start,
                   ending_90,
                   recurring,
                   duration_certainty,
                   now
                 ) ==
                   "through May 25"
        end)
      end)
    end

    test "effect end - >90 days but still this year", %{
      now: now,
      start_now: start_now,
      start_in_30: start_in_30
    } do
      # Saturday, May 25th 2024
      ending_90 = DateTime.add(now, 120, :day)
      duration_certainty = :KNOWN

      Enum.each([true, false], fn recurring ->
        Enum.each([start_now, start_in_30], fn start ->
          assert TimeframeText.timeframe_text(
                   start,
                   ending_90,
                   recurring,
                   duration_certainty,
                   now
                 ) == "until June"
        end)
      end)
    end

    test "effect end - >90 days but next year or beyond", %{
      now: now,
      start_now: start_now,
      start_in_30: start_in_30
    } do
      # Saturday, May 25th 2024
      ending_90 = DateTime.add(now, 320, :day)
      duration_certainty = :KNOWN

      Enum.each([true, false], fn recurring ->
        Enum.each([start_now, start_in_30], fn start ->
          assert TimeframeText.timeframe_text(
                   start,
                   ending_90,
                   recurring,
                   duration_certainty,
                   now
                 ) ==
                   "until January 2025"
        end)
      end)
    end

    test "effect end - within 90 days but at the end of the year" do
      now = utc_datetime_from_local(~D[2024-12-25], ~T[22:00:00])
      start_now = now
      start_in_30 = DateTime.add(now, 30, :minute)
      duration_certainty = :KNOWN

      ending = DateTime.add(now, 20, :day)

      Enum.each([true, false], fn recurring ->
        Enum.each([start_now, start_in_30], fn start ->
          assert TimeframeText.timeframe_text(start, ending, recurring, duration_certainty, now) ==
                   "through January 14"
        end)
      end)
    end
  end

  # describe "starts later today" do
  #   setup do
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])

  #     %{
  #       now: now,
  #       start: DateTime.add(now, 1, :hour)
  #     }
  #   end

  #   test "effect end - today", %{now: now, start: start} do
  #     ending = DateTime.add(now, 2, :hour)

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "later today"
  #     assert TimeframeText.timeframe_text(start, ending, true, now) == "later today"
  #   end

  #   test "effect end - after today", %{now: now, start: start} do
  #     ending = DateTime.add(now, 1, :day)

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "starting later today"
  #     assert TimeframeText.timeframe_text(start, ending, true, now) == "starting later today"
  #   end

  #   test "effect end - until further notice", %{now: now, start: start} do
  #     ending = nil

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "starting later today"
  #     assert TimeframeText.timeframe_text(start, ending, true, now) == "starting later today"
  #   end
  # end

  # describe "starts tomorrow" do
  #   setup do
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])

  #     %{
  #       now: now,
  #       start: DateTime.add(now, 1, :day)
  #     }
  #   end

  #   test "ends tomorrow", %{now: now, start: start} do
  #     ending = DateTime.add(now, 1, :day) |> DateTime.add(1, :hour)

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "tomorrow"
  #     assert TimeframeText.timeframe_text(start, ending, true, now) == "tomorrow"
  #   end

  #   test "ends <= 7 days from now", %{now: now, start: start} do
  #     ending = DateTime.add(now, 7, :day)

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "tomorrow through Sunday"
  #     assert TimeframeText.timeframe_text(start, ending, true, now) == "tomorrow through Sunday"
  #   end

  #   test "ends > 7 days from now", %{now: now, start: start} do
  #     ending = DateTime.add(now, 8, :day)

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "starting tomorrow"
  #     assert TimeframeText.timeframe_text(start, ending, true, now) == "starting tomorrow"
  #   end

  #   test "end effect - further notice", %{now: now, start: start} do
  #     ending = nil

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "starting tomorrow"
  #     assert TimeframeText.timeframe_text(start, ending, true, now) == "starting tomorrow"
  #   end
  # end

  # describe "starts after tomorrow but within 6 days" do
  #   setup do
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])

  #     %{
  #       now: now,
  #       start: DateTime.add(now, 5, :day)
  #     }
  #   end

  #   test "ends same day as start date", %{now: now, start: start} do
  #     ending = DateTime.add(start, 1, :hour)

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Friday"
  #     assert TimeframeText.timeframe_text(start, ending, true, now) == "Friday"
  #   end

  #   test "ends <= 7 days from now", %{now: now, start: start} do
  #     ending = DateTime.add(start, 6, :day)

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Friday through Thursday"
  #     assert TimeframeText.timeframe_text(start, ending, true, now) == "Friday through Thursday"
  #   end

  #   test "ends > 7 days from now", %{now: now, start: start} do
  #     ending = DateTime.add(now, 8, :day)

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "starting Friday"
  #     assert TimeframeText.timeframe_text(start, ending, true, now) == "starting Friday"
  #   end

  #   test "end effect - further notice", %{now: now, start: start} do
  #     ending = nil

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "starting Friday"
  #     assert TimeframeText.timeframe_text(start, ending, true, now) == "starting Friday"
  #   end
  # end

  # test "starts on a Saturday within 6 days and ends the Sunday directly after" do
  #   # Saturday, Feb 24th
  #   start = utc_datetime_from_local(~D[2024-02-24], ~T[22:00:00])
  #   # Currently 5 days before Saturday
  #   now = DateTime.add(start, -5, :day)
  #   ending = utc_datetime_from_local(~D[2024-02-25], ~T[21:00:00])

  #   assert TimeframeText.timeframe_text(start, ending, false, now) == "this weekend"
  #   assert TimeframeText.timeframe_text(start, ending, true, now) == "this weekend"
  # end

  # describe "starts >= 7 days from now" do
  #   setup do
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])

  #     %{
  #       now: now,
  #       # March 3rd
  #       start: DateTime.add(now, 7, :day)
  #     }
  #   end

  #   test "ends same day as start date", %{now: now, start: start} do
  #     ending = DateTime.add(start, 1, :hour)

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "March 3"
  #     assert TimeframeText.timeframe_text(start, ending, true, now) == "March 3"
  #   end

  #   test "ends same month as start date", %{now: now, start: start} do
  #     ending = utc_datetime_from_local(~D[2024-03-31], ~T[22:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "March 3-31"
  #     assert TimeframeText.timeframe_text(start, ending, true, now) == "March 3-31"
  #   end

  #   test "ends different month from start date", %{now: now, start: start} do
  #     ending = DateTime.add(start, 40, :day)

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "starting March 3"
  #     assert TimeframeText.timeframe_text(start, ending, true, now) == "starting March 3"
  #   end

  #   test "end effect - further notice", %{now: now, start: start} do
  #     ending = nil

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "starting March 3"
  #     assert TimeframeText.timeframe_text(start, ending, true, now) == "starting March 3"
  #   end
  # end

  # describe "old tests" do
  #   test "Starts now, ends next calendar day (before End of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])
  #     start = now
  #     ending = utc_datetime_from_local(~D[2024-02-26], ~T[01:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == nil
  #   end

  #   test "Starts now, ends next calendar day (between End of Service and Start of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])
  #     start = now
  #     ending = utc_datetime_from_local(~D[2024-02-26], ~T[03:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == nil
  #   end

  #   test "Starts now, ends next calendar day (after Start of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])
  #     start = now
  #     ending = utc_datetime_from_local(~D[2024-02-26], ~T[05:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == nil
  #   end

  #   test "Starts now, ends 2-6 calendar days later" do
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])
  #     start = now
  #     ending = utc_datetime_from_local(~D[2024-02-27], ~T[01:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == nil
  #   end

  #   test "Starts later today, ends same calendar day" do
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-02-25], ~T[23:00:00])
  #     ending = utc_datetime_from_local(~D[2024-02-25], ~T[23:59:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Later today"
  #   end

  #   test "Starts later today, ends next calendar day (before End of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-02-25], ~T[23:00:00])
  #     ending = utc_datetime_from_local(~D[2024-02-26], ~T[01:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Starting later today"
  #   end

  #   test "Starts later today, ends next calendar day (between End of Service and Start of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-02-25], ~T[23:00:00])
  #     ending = utc_datetime_from_local(~D[2024-02-26], ~T[03:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Starting later today"
  #   end

  #   test "Starts later today, ends next calendar day (after Start of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-02-25], ~T[23:00:00])
  #     ending = utc_datetime_from_local(~D[2024-02-26], ~T[05:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Starting later today"
  #   end

  #   test "Starts tomorrow, ends same calendar day (before End of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-02-26], ~T[00:00:00])
  #     ending = utc_datetime_from_local(~D[2024-02-26], ~T[01:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Starting tomorrow"
  #   end

  #   test "Starts tomorrow, ends same calendar day (between End of Service and Start of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-02-26], ~T[00:00:00])
  #     ending = utc_datetime_from_local(~D[2024-02-26], ~T[03:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Starting tomorrow"
  #   end

  #   test "Starts tomorrow, ends same calendar day (after Start of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-02-26], ~T[00:00:00])
  #     ending = utc_datetime_from_local(~D[2024-02-26], ~T[05:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Starting tomorrow"
  #   end

  #   test "Starts tomorrow, ends 2-6 calendar days later" do
  #     # ends before start of service 2 days from now
  #     now = utc_datetime_from_local(~D[2024-02-25], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-02-26], ~T[00:00:00])
  #     ending = utc_datetime_from_local(~D[2024-02-27], ~T[01:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Starting tomorrow"
  #   end

  #   test "Starts now (before End of Service), ends same calendar day" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[00:00:00])
  #     start = now
  #     ending = utc_datetime_from_local(~D[2024-02-26], ~T[01:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == nil
  #   end

  #   test "Starts now (before End of Service), ends same calendar day (between End of Service and Start of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[00:00:00])
  #     start = now
  #     ending = utc_datetime_from_local(~D[2024-02-26], ~T[03:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == nil
  #   end

  #   test "Starts now (before End of Service), ends same calendar day (after Start of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[00:00:00])
  #     start = now
  #     ending = utc_datetime_from_local(~D[2024-02-26], ~T[05:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == nil
  #   end

  #   test "Starts now (before End of Service), ends next calendar day (before End of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[00:00:00])
  #     start = now
  #     ending = utc_datetime_from_local(~D[2024-02-27], ~T[01:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == nil
  #   end

  #   test "Starts later today (between End of Service and Start of Service), ends same calendar day (between End of Service and Start of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[00:00:00])
  #     start = utc_datetime_from_local(~D[2024-02-26], ~T[03:00:00])
  #     ending = utc_datetime_from_local(~D[2024-02-26], ~T[04:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Later today"
  #   end

  #   test "Starts later today (between End of Service and Start of Service), ends same calendar day (after Start of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[00:00:00])
  #     start = utc_datetime_from_local(~D[2024-02-26], ~T[03:00:00])
  #     ending = utc_datetime_from_local(~D[2024-02-26], ~T[05:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Later today"
  #   end

  #   test "Starts later today (between End of Service and Start of Service), ends next calendar day (before End of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[00:00:00])
  #     start = utc_datetime_from_local(~D[2024-02-26], ~T[03:00:00])
  #     ending = utc_datetime_from_local(~D[2024-02-27], ~T[01:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Starting later today"
  #   end

  #   test "Starts later today, ends next calendar day (at End of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-02-26], ~T[23:00:00])
  #     ending = utc_datetime_from_local(~D[2024-02-27], ActivePeriod.end_of_service_time())

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Starting later today"
  #   end

  #   test "Starts tomorrow, ends same calendar day (at End of Service) " do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-02-27], ~T[01:00:00])
  #     ending = utc_datetime_from_local(~D[2024-02-27], ActivePeriod.end_of_service_time())

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Starting tomorrow"
  #   end

  #   test "Starts tomorrow (at End of Service), ends 2-6 calendar days later (at Start of Service)" do
  #     # ends after start of service 2 days from now
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-02-27], ActivePeriod.end_of_service_time())
  #     ending = utc_datetime_from_local(~D[2024-02-28], ActivePeriod.start_of_service_time())

  #     assert TimeframeText.timeframe_text(start, ending, false, now) ==
  #              "Tomorrow through Tuesday"
  #   end

  #   test "Starts tomorrow (at End of Service), ends 2-6 calendar days later" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-02-27], ActivePeriod.end_of_service_time())
  #     ending = utc_datetime_from_local(~D[2024-03-04], ActivePeriod.end_of_service_time())

  #     assert TimeframeText.timeframe_text(start, ending, false, now) ==
  #              "Tomorrow through Sunday"
  #   end

  #   test "Starts 2-6 calendar days in the future (at End of Service), ends 2-6 calendar days later (at End of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-03-01], ActivePeriod.end_of_service_time())
  #     ending = utc_datetime_from_local(~D[2024-03-04], ActivePeriod.end_of_service_time())

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Friday through Sunday"
  #   end

  #   test "Starts 2-6 calendar days in the future (at Start of Service), ends 2-6 calendar days later (at End of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-03-01], ActivePeriod.start_of_service_time())
  #     ending = utc_datetime_from_local(~D[2024-03-04], ActivePeriod.start_of_service_time())

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Friday through Sunday"
  #   end

  #   test "Starts 2-6 calendar days in the future, ends next day, is a weekend" do
  #     now = utc_datetime_from_local(~D[2024-02-28], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-03-02], ~T[10:00:00])
  #     ending = utc_datetime_from_local(~D[2024-03-03], ~T[10:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "this weekend"
  #   end

  #   test "Starts 2-6 calendar days in the future at start of service, ends next day at end of service, is a weekend" do
  #     now = utc_datetime_from_local(~D[2024-02-28], ~T[03:00:00])
  #     start = utc_datetime_from_local(~D[2024-03-02], ~T[10:00:00])
  #     ending = utc_datetime_from_local(~D[2024-03-04], ~T[03:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "this weekend"
  #   end

  #   test "Starts 2-6 calendar days in the future, ends >6 calendar days later" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-03-01], ~T[10:00:00])
  #     ending = utc_datetime_from_local(~D[2024-03-31], ~T[10:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Starting Friday"
  #   end

  #   test "Starts 2-6 calendar days in the future, ends same day" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-03-01], ~T[10:00:00])
  #     ending = utc_datetime_from_local(~D[2024-03-01], ~T[11:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Friday"
  #   end

  #   test "Starts 2-6 calendar days in the future, ends same day, start and end at service times" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-03-01], ~T[03:00:00])
  #     ending = utc_datetime_from_local(~D[2024-03-02], ~T[03:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "Friday"
  #   end

  #   test "Starts >6 calendar days, ends same calendar day" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-03-22], ~T[06:00:00])
  #     ending = utc_datetime_from_local(~D[2024-03-22], ~T[19:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "March 22"
  #   end

  #   test "Starts >6 calendar days, ends same calendar day when end is end of service" do
  #     now = utc_datetime_from_local(~D[2024-03-15], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-03-22], ~T[03:00:00])
  #     ending = utc_datetime_from_local(~D[2024-03-23], ~T[03:00:00])

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "March 22"
  #   end

  #   test "Starts >6 calendar days in the future (before End of Service), ends >6 calendar days later (at End of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-03-22], ~T[20:45:00])
  #     ending = utc_datetime_from_local(~D[2024-03-25], ActivePeriod.end_of_service_time())

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "March 22-24"
  #   end

  #   test "Starts >6 calendar days in the future (at End of Service), ends >6 calendar days later (at End of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-03-22], ActivePeriod.end_of_service_time())
  #     ending = utc_datetime_from_local(~D[2024-03-25], ActivePeriod.end_of_service_time())

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "March 22-24"
  #   end

  #   test "Starts >6 calendar days in the future (at Start of Service), ends >6 calendar days later (at End of Service)" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-03-22], ActivePeriod.start_of_service_time())
  #     ending = utc_datetime_from_local(~D[2024-03-25], ActivePeriod.end_of_service_time())

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "March 22-24"
  #   end

  #   test "Starts >6 calendar days in the future (at Start of Service), ends >6 calendar days later (at End of Service) in a different calendar month" do
  #     now = utc_datetime_from_local(~D[2024-02-26], ~T[22:00:00])
  #     start = utc_datetime_from_local(~D[2024-03-22], ActivePeriod.start_of_service_time())
  #     ending = utc_datetime_from_local(~D[2024-04-02], ActivePeriod.end_of_service_time())

  #     assert TimeframeText.timeframe_text(start, ending, false, now) == "March 22-April 1"
  #   end
  # end

  def utc_datetime_from_local(date, time) do
    # creates datetimes in UTC. this lets us see see a nice eastern datetime in our tests
    # but actually give the function the UTC date it would get in real life
    DateTime.new!(date, time, "America/New_York") |> DateTime.shift_zone!("Etc/UTC")
  end
end
