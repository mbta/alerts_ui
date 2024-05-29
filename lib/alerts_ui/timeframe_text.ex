defmodule AlertsUI.TimeframeText do
  @moduledoc """
    Returns timeframe text given a start and end time
  """

  @end_of_service ~T[02:30:00]
  @start_of_service ~T[04:30:00]
  @timeframe_text_map %{
    starts_later_today_ends_same_calendar_day: "Later today",
    starts_later_today_ends_next_calendar_day: "Starting later today",
    starts_tomorrow: "Tomorrow",
    starts_tomorrow_ends_this_week: "Tomorrow through END_DAY_NAME",
    starts_this_week_ends_less_than_6_days_later: "START_DAY_NAME through END_DAY_NAME",
    starts_this_week: "Starting START_DAY_NAME",
    distant_date_ends_same_day: "HUMAN_READABLE_START_DATE",
    distant_date: "HUMAN_READABLE_START_DATE-HUMAN_READABLE_END_DATE"
  }

  @spec timeframe_text(DateTime.t(), DateTime.t() | nil, DateTime.t()) :: String.t() | nil

  def timeframe_text(start_datetime, end_datetime, current_datetime \\ DateTime.utc_now())
  def timeframe_text(_start_datetime, nil, _current_datetime), do: nil

  def timeframe_text(start_datetime, end_datetime, current_datetime) do
    # all datetimes are shifted to Eastern time and calculated from there
    [current_datetime, current_date] = format_datetime(current_datetime)
    [start_datetime, start_date] = format_datetime(start_datetime)
    [end_datetime, end_date] = format_datetime(end_datetime)

    starts_later_today =
      DateTime.compare(start_datetime, current_datetime) == :gt and
        Date.compare(start_date, current_date) == :eq

    starts_tomorrow = start_date == current_date |> Date.add(1)
    starts_2_6_days_from_now = between_two_and_six_days(current_datetime, start_datetime)
    starts_more_than_6_days_from_now = more_than_six_days(current_datetime, start_datetime)

    cond do
      starts_later_today ->
        starts_later_today(current_date, end_date)

      starts_tomorrow ->
        starts_tomorrow(current_datetime, start_date, end_datetime)

      starts_2_6_days_from_now ->
        starts_2_6_days_from_now(start_datetime, end_datetime)

      starts_more_than_6_days_from_now ->
        starts_more_than_six_days_from_now(start_date, end_datetime)

      true ->
        nil
    end
  end

  defp starts_later_today(current_date, end_date) do
    ends_today = Date.compare(end_date, current_date) == :eq

    if ends_today do
      @timeframe_text_map[:starts_later_today_ends_same_calendar_day]
    else
      @timeframe_text_map[:starts_later_today_ends_next_calendar_day]
    end
  end

  defp starts_tomorrow(current_datetime, start_date, end_datetime) do
    end_date = DateTime.to_date(end_datetime)
    end_time = DateTime.to_time(end_datetime)

    ends_next_day_after_start_of_service =
      end_date == start_date |> Date.add(1) and
        Time.compare(@end_of_service, end_time) in [:lt, :eq]

    ends_2_6_days_from_now = between_two_and_six_days(current_datetime, end_datetime)

    if ends_next_day_after_start_of_service or ends_2_6_days_from_now do
      @timeframe_text_map[:starts_tomorrow_ends_this_week]
      |> String.replace("END_DAY_NAME", get_weekday_name_for_end(end_datetime))
    else
      @timeframe_text_map[:starts_tomorrow]
    end
  end

  defp starts_2_6_days_from_now(start_datetime, end_datetime) do
    start_date = DateTime.to_date(start_datetime)

    ends_2_6_days_from_start = between_two_and_six_days(start_datetime, end_datetime)

    if ends_2_6_days_from_start do
      @timeframe_text_map[:starts_this_week_ends_less_than_6_days_later]
      |> String.replace("START_DAY_NAME", get_day_name(start_date))
      |> String.replace("END_DAY_NAME", get_weekday_name_for_end(end_datetime))
    else
      @timeframe_text_map[:starts_this_week]
      |> String.replace("START_DAY_NAME", get_day_name(start_date))
    end
  end

  defp starts_more_than_six_days_from_now(start_date, end_datetime) do
    end_date = DateTime.to_date(end_datetime)

    if end_date == start_date do
      @timeframe_text_map[:distant_date_ends_same_day]
      |> String.replace("HUMAN_READABLE_START_DATE", get_human_readable_start_date(start_date))
    else
      @timeframe_text_map[:distant_date]
      |> String.replace("HUMAN_READABLE_START_DATE", get_human_readable_start_date(start_date))
      |> String.replace(
        "HUMAN_READABLE_END_DATE",
        get_human_readable_end_date(start_date, end_datetime)
      )
    end
  end

  defp between_two_and_six_days(start_datetime, end_datetime) do
    # returns true if the end_datetime falls between the beginning of service 2 days from
    # start datetime and end of service 7 days from start_datetime
    start_date = DateTime.to_date(start_datetime)

    beginning_of_service_on_day_two =
      Date.add(start_date, 2) |> DateTime.new!(@start_of_service, "America/New_York")

    end_of_service_on_day_seven =
      Date.add(start_date, 7) |> DateTime.new!(@end_of_service, "America/New_York")

    end_is_after_beginning_of_service_on_day_two =
      DateTime.compare(end_datetime, beginning_of_service_on_day_two) in [:gt, :eq]

    ends_before_end_of_service_day_on_day_seven =
      DateTime.compare(end_datetime, end_of_service_on_day_seven) in [:lt, :eq]

    end_is_after_beginning_of_service_on_day_two and
      ends_before_end_of_service_day_on_day_seven
  end

  defp more_than_six_days(start_date, end_datetime) do
    # returns true if end_datetime is after the start of service 7 days after start_datetime

    six_days_from_start =
      Date.add(start_date, 7) |> DateTime.new!(@start_of_service, "America/New_York")

    DateTime.compare(end_datetime, six_days_from_start) in [:gt, :eq]
  end

  defp get_weekday_name_for_end(end_datetime) do
    # moves end day up 1 day if end time is before start of service
    end_date = DateTime.to_date(end_datetime)
    end_time = DateTime.to_time(end_datetime)

    if Time.compare(end_time, @start_of_service) in [:lt, :eq] do
      Date.add(end_date, -1)
    else
      end_date
    end
    |> get_day_name
  end

  defp get_day_name(date) do
    date |> Timex.weekday() |> Timex.day_name()
  end

  defp get_human_readable_start_date(date) do
    "#{Timex.month_name(date.month)} #{date.day}"
  end

  defp get_human_readable_end_date(start_date, end_datetime) do
    # moves end date up 1 day if end time is before start of service
    # also ends month name on end date if start and end month are different
    end_date = DateTime.to_date(end_datetime)
    end_time = DateTime.to_time(end_datetime)

    end_date =
      if Time.compare(end_time, @start_of_service) in [:lt, :eq] do
        Date.add(end_date, -1)
      else
        end_date
      end

    if start_date.month == end_date.month do
      "#{end_date.day}"
    else
      "#{Timex.month_name(end_date.month)} #{end_date.day}"
    end
  end

  defp format_datetime(datetime) do
    datetime = Timex.Timezone.convert(datetime, "America/New_York")
    [datetime, DateTime.to_date(datetime)]
  end
end
