defmodule AlertsUIWeb.CreateAlertLive.Helpers.DurationTextTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AlertsUIWeb.CreateAlertLive.Helpers.DurationText

  # Build a Phoenix.HTML.Form whose `form[:field].value` returns the typed value
  # we pass in. The map-backed FormData impl looks up by stringified key in
  # params first, so we use string keys with typed values.
  defp form(values) do
    Phoenix.Component.to_form(values, as: :alert_data)
  end

  describe "one_time_duration_text/1" do
    test "renders a custom start and custom end with the duration between them" do
      f =
        form(%{
          "active_period_start_specifier" => "custom",
          "active_period_start" => ~N[2024-11-27 09:00:00],
          "active_period_end_specifier" => "custom",
          "active_period_end" => ~N[2024-11-27 15:00:00]
        })

      assert DurationText.one_time_duration_text(f) ==
               "Wed Nov 27, 2024 @ 9:00 AM until Wed Nov 27, 2024 @ 3:00 PM (6 hours)"
    end

    test "shows 0 minutes when start and end are less than one minute apart" do
      f =
        form(%{
          "active_period_start" => ~N[2024-11-27 13:00:00],
          "active_period_end" => ~N[2024-11-27 13:00:45],
          "active_period_end_specifier" => "custom"
        })

      assert DurationText.one_time_duration_text(f) ==
               "Wed Nov 27, 2024 @ 1:00 PM until Wed Nov 27, 2024 @ 1:00 PM (0 minutes)"
    end

    test "renders 1 day span across consecutive service starts" do
      f =
        form(%{
          "active_period_start" => ~N[2024-11-27 03:00:00],
          "active_period_end" => ~N[2024-11-28 03:00:00],
          "active_period_end_specifier" => "custom"
        })

      assert DurationText.one_time_duration_text(f) ==
               "Wed Nov 27, 2024 @ 3:00 AM until Thu Nov 28, 2024 @ 3:00 AM (1 day)"
    end

    test "displays 'later today' with a max-prefix duration" do
      f =
        form(%{
          "active_period_start" => ~N[2024-11-27 09:00:00],
          "active_period_end" => ~N[2024-11-28 03:00:00],
          "active_period_end_specifier" => "later_today"
        })

      assert DurationText.one_time_duration_text(f) ==
               "Wed Nov 27, 2024 @ 9:00 AM until later today (max 18 hours)"
    end

    test "renders end_of_service with the actual end timestamp" do
      f =
        form(%{
          "active_period_start" => ~N[2024-11-28 01:00:00],
          "active_period_end" => ~N[2024-11-28 03:00:00],
          "active_period_end_specifier" => "end_of_service"
        })

      assert DurationText.one_time_duration_text(f) ==
               "Thu Nov 28, 2024 @ 1:00 AM until Thu Nov 28, 2024 @ 3:00 AM (2 hours)"
    end

    test "displays until_further_notice as indefinite" do
      f =
        form(%{
          "active_period_start" => ~N[2024-11-27 09:00:00],
          "active_period_end" => "",
          "active_period_end_specifier" => "until_further_notice"
        })

      assert DurationText.one_time_duration_text(f) ==
               "Wed Nov 27, 2024 @ 9:00 AM until alert is manually closed (indefinite)"
    end

    test "tolerates nil/empty start and end values" do
      f =
        form(%{
          "active_period_start" => nil,
          "active_period_end" => nil,
          "active_period_end_specifier" => "custom"
        })

      # start_phrase returns " until" when start is nil; end_phrase returns ""
      # for "custom" with nil end; duration returns "" with nil endpoints.
      # Joined with single spaces: " until" <> " " <> "" <> " " <> "".
      assert DurationText.one_time_duration_text(f) == " until  "
    end
  end

  describe "recurring_duration_text/1" do
    test "renders a full recurring schedule with a non-+1 time span" do
      f =
        form(%{
          "active_period_start_time" => ~T[07:35:00],
          "active_period_end_time" => ~T[21:45:00],
          "active_period_start_date" => ~D[2024-11-25],
          "active_period_end_date" => ~D[2025-01-01],
          "active_period_end_specifier" => "custom",
          "recurrence_days" => ["wednesday"]
        })

      assert Phoenix.HTML.safe_to_string(DurationText.recurring_duration_text(f)) ==
               "7:35 AM – 9:45 PM (14 hours, 10 minutes) every Wednesday from Mon Nov 25, 2024 until Wed Jan 01, 2025"
    end

    test "uses the +1 suffix when end time equals start time (spans midnight)" do
      f =
        form(%{
          "active_period_start_time" => ~T[07:35:00],
          "active_period_end_time" => ~T[07:35:00],
          "active_period_start_date" => ~D[2024-11-26],
          "active_period_end_date" => ~D[2025-01-02],
          "active_period_end_specifier" => "custom",
          "recurrence_days" => ["tuesday", "thursday"]
        })

      assert Phoenix.HTML.safe_to_string(DurationText.recurring_duration_text(f)) ==
               "7:35 AM – 7:35 AM<sup>+1</sup> (1 day) every Tuesday and Thursday from Tue Nov 26, 2024 until Thu Jan 02, 2025"
    end

    test "uses the +1 suffix when end time is before start time" do
      f =
        form(%{
          "active_period_start_time" => ~T[09:45:00],
          "active_period_end_time" => ~T[07:35:00],
          "active_period_start_date" => ~D[2024-11-26],
          "active_period_end_date" => ~D[2025-01-02],
          "active_period_end_specifier" => "custom",
          "recurrence_days" => ["tuesday", "wednesday", "thursday"]
        })

      assert Phoenix.HTML.safe_to_string(DurationText.recurring_duration_text(f)) ==
               "9:45 AM – 7:35 AM<sup>+1</sup> (21 hours, 50 minutes) every Tuesday, Wednesday, and Thursday from Tue Nov 26, 2024 until Thu Jan 02, 2025"
    end

    test "renders 'every day' and 'alert is manually closed' for full-week + until_further_notice" do
      f =
        form(%{
          "active_period_start_time" => ~T[11:45:00],
          "active_period_end_time" => ~T[03:45:00],
          "active_period_start_date" => ~D[2024-11-26],
          "active_period_end_date" => nil,
          "active_period_end_specifier" => "until_further_notice",
          "recurrence_days" => [
            "sunday",
            "monday",
            "tuesday",
            "wednesday",
            "thursday",
            "friday",
            "saturday"
          ]
        })

      assert Phoenix.HTML.safe_to_string(DurationText.recurring_duration_text(f)) ==
               "11:45 AM – 3:45 AM<sup>+1</sup> (16 hours) every day from Tue Nov 26, 2024 until alert is manually closed"
    end

    test "tolerates nil/empty values" do
      f =
        form(%{
          "active_period_start_time" => nil,
          "active_period_end_time" => nil,
          "active_period_start_date" => nil,
          "active_period_end_date" => nil,
          "active_period_end_specifier" => nil,
          "recurrence_days" => []
        })

      rendered = Phoenix.HTML.safe_to_string(DurationText.recurring_duration_text(f))

      # No times, no days, no dates — the helper still produces a stable shell.
      assert rendered == " –   every  from  until "
    end
  end

  describe "recurring_duration_date_range/3" do
    test "joins formatted start and end dates with 'until'" do
      assert DurationText.recurring_duration_date_range(
               ~D[2024-11-25],
               ~D[2025-01-01],
               "custom"
             ) == "Mon Nov 25, 2024 until Wed Jan 01, 2025"
    end

    test "honors the until_further_notice end specifier" do
      assert DurationText.recurring_duration_date_range(
               ~D[2024-11-25],
               nil,
               "until_further_notice"
             ) == "Mon Nov 25, 2024 until alert is manually closed"
    end
  end

  describe "recurring_duration_recurrence_days/1" do
    test "prefixes the weekday text with 'every '" do
      assert DurationText.recurring_duration_recurrence_days(["wednesday"]) ==
               "every Wednesday"
    end
  end

  describe "recurring_duration_time_range/2" do
    test "renders a non-+1 time range" do
      assert DurationText.recurring_duration_time_range(~T[07:35:00], ~T[21:45:00]) ==
               "7:35 AM – 9:45 PM"
    end

    test "renders the +1 suffix when end is not strictly after start" do
      assert DurationText.recurring_duration_time_range(~T[09:00:00], ~T[09:00:00]) ==
               "9:00 AM – 9:00 AM<sup>+1</sup>"
    end
  end

  describe "time_text/1" do
    test "returns an empty string for nil" do
      assert DurationText.time_text(nil) == ""
    end

    test "returns an empty string for the empty string" do
      assert DurationText.time_text("") == ""
    end

    test "formats a Time as 12-hour with AM/PM" do
      assert DurationText.time_text(~T[07:35:00]) == "7:35 AM"
      assert DurationText.time_text(~T[21:45:00]) == "9:45 PM"
    end
  end

  describe "plus_one?/2" do
    test "returns false when end time is strictly after start time" do
      assert DurationText.plus_one?(~T[07:00:00], ~T[08:00:00]) == false
    end

    test "returns true when start and end times are equal" do
      assert DurationText.plus_one?(~T[09:00:00], ~T[09:00:00]) == true
    end

    test "returns true when end time is before start time (rollover)" do
      assert DurationText.plus_one?(~T[22:00:00], ~T[01:00:00]) == true
    end

    test "returns false for non-Time arguments" do
      assert DurationText.plus_one?(nil, nil) == false
      assert DurationText.plus_one?("", "") == false
    end
  end

  describe "date_text/2" do
    test "returns the manual-close phrase for an atom :until_further_notice specifier" do
      assert DurationText.date_text(~D[2024-11-25], :until_further_notice) ==
               "alert is manually closed"
    end

    test "returns the manual-close phrase for a string 'until_further_notice' specifier" do
      assert DurationText.date_text(~D[2024-11-25], "until_further_notice") ==
               "alert is manually closed"
    end

    test "returns an empty string when the date is nil" do
      assert DurationText.date_text(nil, "custom") == ""
    end

    test "formats a Date with weekday, month, day, year" do
      assert DurationText.date_text(~D[2024-11-25], "custom") == "Mon Nov 25, 2024"
    end
  end

  describe "weekday_text/1" do
    test "returns an empty string for nil and empty list" do
      assert DurationText.weekday_text(nil) == ""
      assert DurationText.weekday_text([]) == ""
    end

    test "converts a list of atoms to a list of capitalized strings before formatting" do
      assert DurationText.weekday_text([:monday]) == "Monday"
    end

    test "returns a single capitalized weekday" do
      assert DurationText.weekday_text(["monday"]) == "Monday"
    end

    test "joins two weekdays with 'and'" do
      assert DurationText.weekday_text(["monday", "wednesday"]) == "Monday and Wednesday"
    end

    test "collapses all seven weekdays to 'day'" do
      assert DurationText.weekday_text(
               ~w[sunday monday tuesday wednesday thursday friday saturday]
             ) ==
               "day"
    end

    test "renders 3+ weekdays as a comma-separated list with 'and' before the last" do
      assert DurationText.weekday_text(["tuesday", "wednesday", "thursday"]) ==
               "Tuesday, Wednesday, and Thursday"
    end
  end
end
