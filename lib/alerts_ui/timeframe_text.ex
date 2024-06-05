defmodule AlertsUI.TimeframeText do
  @moduledoc """
    Returns timeframe text given a start and end time
  """

  @timezone "America/New_York"
  @end_of_service ~T[02:30:00]
  @start_of_service ~T[04:30:00]

  @type datetime_tuple :: {DateTime.t(), Date.t(), Time.t()}

  defp starts_later_today_ends_same_calendar_day, do: "Later today"
  defp starts_later_today_ends_next_calendar_day, do: "Starting later today"
  defp starts_tomorrow, do: "Tomorrow"
  defp starts_tomorrow_ends_this_week(end_day_name), do: "Tomorrow through #{end_day_name}"

  defp starts_this_week_ends_next_week(start_day_name, end_day_name),
    do: "#{start_day_name} through #{end_day_name}"

  defp starts_this_week(start_day_name), do: "Starting #{start_day_name}"
  defp distant_date_ends_same_day(start_date), do: start_date
  defp distant_date(start_date, end_date), do: "#{start_date}-#{end_date}"

  @spec timeframe_text(DateTime.t(), DateTime.t() | nil) :: String.t() | nil
  @spec timeframe_text(DateTime.t(), DateTime.t() | nil, DateTime.t()) :: String.t() | nil
  def timeframe_text(start_datetime, end_datetime, current_datetime \\ DateTime.utc_now())
  def timeframe_text(_start_datetime, nil, _current_datetime), do: nil

  def timeframe_text(start_datetime, end_datetime, current_datetime) do
    # all datetimes are shifted to Eastern time and calculated from there
    {current_datetime, current_date, _} = to_local_with_date(current_datetime)

    {start_datetime, start_date, _} = to_local_with_date(start_datetime)

    {_, end_date, _} = end_time_tuple = to_local_with_date(end_datetime)

    cond do
      DateTime.compare(start_datetime, current_datetime) == :gt and
          Date.compare(start_date, current_date) == :eq ->
        starts_later_today(current_date, end_date)

      start_date == Date.add(current_date, 1) ->
        starts_tomorrow(current_date, start_date, end_time_tuple)

      between_two_and_six_days(current_date, start_datetime) ->
        starts_2_to_6_days_from_now(start_date, end_time_tuple)

      more_than_six_days(current_datetime, start_datetime) ->
        starts_more_than_six_days_from_now(start_date, end_time_tuple)

      true ->
        nil
    end
  end

  defp starts_later_today(current_date, end_date) do
    ends_today = Date.compare(end_date, current_date) == :eq

    if ends_today do
      starts_later_today_ends_same_calendar_day()
    else
      starts_later_today_ends_next_calendar_day()
    end
  end

  defp starts_tomorrow(
         current_date,
         start_date,
         {end_datetime, end_date, end_time} = end_time_tuple
       ) do
    ends_next_day_after_start_of_service =
      end_date == start_date |> Date.add(1) and
        Time.compare(@end_of_service, end_time) in [:lt, :eq]

    ends_2_to_6_days_from_now = between_two_and_six_days(current_date, end_datetime)

    if ends_next_day_after_start_of_service or ends_2_to_6_days_from_now do
      starts_tomorrow_ends_this_week(get_day_name_for_end(end_time_tuple))
    else
      starts_tomorrow()
    end
  end

  defp starts_2_to_6_days_from_now(start_date, {end_datetime, _, _} = end_time_tuple) do
    ends_2_to_6_days_from_start = between_two_and_six_days(start_date, end_datetime)

    if ends_2_to_6_days_from_start do
      starts_this_week_ends_next_week(
        get_day_name(start_date),
        get_day_name_for_end(end_time_tuple)
      )
    else
      starts_this_week(get_day_name(start_date))
    end
  end

  defp starts_more_than_six_days_from_now(
         start_date,
         {_, end_date, _} = end_date_tuple
       ) do
    if end_date == start_date do
      distant_date_ends_same_day(get_human_readable_start_date(start_date))
    else
      distant_date(
        get_human_readable_start_date(start_date),
        get_human_readable_end_date(start_date, end_date_tuple)
      )
    end
  end

  defp between_two_and_six_days(start_date, end_datetime) do
    # returns true if the end_datetime falls between the beginning of service 2 days from
    # start datetime and end of service 7 days from start_datetime

    beginning_of_service_on_day_two =
      Date.add(start_date, 2) |> DateTime.new!(@start_of_service, @timezone)

    end_of_service_on_day_seven =
      Date.add(start_date, 7) |> DateTime.new!(@end_of_service, @timezone)

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
      Date.add(start_date, 7) |> DateTime.new!(@start_of_service, @timezone)

    DateTime.compare(end_datetime, six_days_from_start) in [:gt, :eq]
  end

  defp get_day_name_for_end({_, end_date, end_time}) do
    # moves end day up 1 day if end time is before start of service

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

  defp get_human_readable_end_date(start_date, {_, end_date, end_time}) do
    # moves end date up 1 day if end time is before start of service
    # also ends month name on end date if start and end month are different

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

  @spec to_local_with_date(DateTime.t()) :: datetime_tuple()
  defp to_local_with_date(datetime) do
    datetime = Timex.Timezone.convert(datetime, @timezone)
    {datetime, DateTime.to_date(datetime), DateTime.to_time(datetime)}
  end
end
