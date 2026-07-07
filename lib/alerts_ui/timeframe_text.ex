defmodule AlertsUI.TimeframeText do
  @moduledoc """
    Returns timeframe text given a start and end time
  """
  alias AlertsUI.Models.{ActivePeriod, DurationCertainty}

  @timezone "America/New_York"

  @type datetime_tuple :: {DateTime.t(), Date.t(), Time.t()}

  defp starts_later_today_ends_same_calendar_day, do: "Later today"
  defp starts_later_today_ends_next_calendar_day, do: "Starting later today"
  defp starts_tomorrow, do: "Starting tomorrow"
  defp starts_tomorrow_ends_this_week(end_day_name), do: "Tomorrow through #{end_day_name}"

  defp starts_this_week_ends_next_week(start_day_name, end_day_name),
    do: "#{start_day_name} through #{end_day_name}"

  defp starts_this_week(start_day_name), do: "Starting #{start_day_name}"
  defp starts_this_week_and_is_weekend, do: "this weekend"
  defp starts_this_week_ends_same_day(start_day_name), do: start_day_name
  defp distant_date_ends_same_day(start_date), do: start_date
  defp distant_date(start_date, end_date), do: "#{start_date}-#{end_date}"

  @type duration_certainties_t :: :KNOWN | :UNKNOWN | :ESTIMATED

  @spec timeframe_text(
          DateTime.t(),
          DateTime.t() | nil,
          boolean(),
          duration_certainties_t
        ) :: String.t() | nil
  @spec timeframe_text(
          DateTime.t(),
          DateTime.t() | nil,
          boolean(),
          duration_certainties_t,
          DateTime.t()
        ) ::
          String.t() | nil
  def timeframe_text(
        start_datetime,
        end_datetime,
        recurring,
        duration_certainty,
        current_datetime \\ DateTime.utc_now()
      )

  # # TODO: "starting later today"
  # def timeframe_text(_start_datetime, nil, _recurring, _current_datetime) do

  # end

  def timeframe_text(
        start_datetime,
        end_datetime,
        recurring,
        duration_certainty,
        current_datetime
      ) do
    # all datetimes are shifted to Eastern time and calculated from there
    {current_datetime, current_date, _} = to_local_with_date(current_datetime)

    {start_datetime, start_date, _} = to_local_with_date(start_datetime)

    end_time_tuple = if end_datetime, do: to_local_with_date(end_datetime), else: nil

    # {_, end_date, _} = end_time_tuple = to_local_with_date(end_datetime)

    cond do
      # more_than_six_days(current_datetime, start_datetime) ->
      #   starts_more_than_six_days_from_now(start_date, end_time_tuple)

      # between_two_and_six_days(current_date, start_datetime) ->
      #   starts_2_to_6_days_from_now(start_date, end_time_tuple)

      # start_date == Date.add(current_date, 1) ->
      #   starts_tomorrow(current_date, start_date, end_time_tuple)

      # DateTime.compare(start_datetime, current_datetime) == :gt and
      #     Date.compare(start_date, current_date) == :eq ->
      #   starts_later_today(current_date, end_date)
      # starts_now_or_soon?(start_datetime, current_datetime) and recurring ->
      #   "starting today"

      starts_now_or_soon?(start_datetime, current_datetime) ->
        starts_now_or_soon(current_date, end_datetime)

      within_x_days?(start_date, current_datetime, 7) and not recurring ->
        nil

      within_x_days?(start_date, current_datetime, 30) and recurring ->
        nil

      more_than_or_equal_x_days?(start_date, current_datetime, 7) and
          not recurring ->
        started_a_while_ago(current_date, end_time_tuple, duration_certainty)

      more_than_or_equal_x_days?(start_date, current_datetime, 30) and
          recurring ->
        started_a_while_ago(current_date, end_time_tuple, duration_certainty)

      true ->
        nil
    end
  end

  defp starts_now_or_soon(current_date, end_datetime) do
    {end_datetime, end_date, _} = end_time_tuple = to_local_with_date(end_datetime)

    cond do
      ends_tomorrow?(current_date, end_time_tuple) ->
        "through tomorrow"

      between_x_and_y_days(current_date, end_datetime, 2, 6) ->
        "through #{get_day_name_for_end(end_time_tuple)}"

      between_x_and_y_days(current_date, end_datetime, 7, 90) and
          ends_after_this_year?(current_date, end_time_tuple) ->
        "through #{get_human_readable_end_date(end_time_tuple)}"

      between_x_and_y_days(current_date, end_datetime, 7, 90) ->
        "through #{get_human_readable_end_date(end_time_tuple)}"

      more_than_or_equal_x_days?(current_date, end_datetime, 90) and
          ends_this_year?(current_date, end_time_tuple) ->
        "until #{get_human_readable_end_date(end_time_tuple, :month)}"

      more_than_or_equal_x_days?(current_date, end_datetime, 90) and
          ends_after_this_year?(current_date, end_time_tuple) ->
        "until #{get_human_readable_end_date(end_time_tuple, :month_year)}"

      true ->
        nil
    end
  end

  defp starts_now_or_soon?(start_datetime, current_datetime) do
    soon = DateTime.add(current_datetime, 30, :minute)
    is_in_future = DateTime.compare(start_datetime, current_datetime) in [:eq, :gt]
    is_soon = DateTime.compare(soon, start_datetime) in [:eq, :gt]

    if is_soon and is_in_future do
      true
    else
      false
    end
  end

  defp started_a_while_ago(_current_date, nil, _duration_certainty), do: "ongoing"

  defp started_a_while_ago(current_date, end_time_tuple, duration_certainty) do
    if same_day?(current_date, end_time_tuple) and duration_certainty == :KNOWN do
      "last day"
    else
      "ongoing"
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

  defp ends_tomorrow?(current_date, {end_datetime, end_date, end_time} = end_time_tuple) do
    end_date == current_date |> Date.add(1) and
      Time.compare(ActivePeriod.end_of_service_time(), end_time) in [:lt, :eq]
  end

  defp ends_this_year?(current_date, {end_datetime, end_date, end_time} = end_time_tuple) do
    last_datetime_of_year =
      %{current_date | month: 12, day: 31}
      |> DateTime.new!(ActivePeriod.start_of_service_time(), @timezone)

    DateTime.compare(end_datetime, last_datetime_of_year) in [:lt, :eq]
  end

  defp ends_after_this_year?(current_date, {end_datetime, end_date, end_time} = end_time_tuple) do
    last_datetime_of_year =
      %{current_date | month: 12, day: 31}
      |> DateTime.new!(ActivePeriod.start_of_service_time(), @timezone)

    DateTime.compare(end_datetime, last_datetime_of_year) == :gt
  end

  defp starts_tomorrow(
         current_date,
         start_date,
         {end_datetime, end_date, end_time} = end_time_tuple
       ) do
    ends_next_day_after_start_of_service =
      end_date == start_date |> Date.add(1) and
        Time.compare(ActivePeriod.end_of_service_time(), end_time) in [:lt, :eq]

    ends_2_to_6_days_from_now = between_two_and_six_days(current_date, end_datetime)

    if ends_next_day_after_start_of_service or ends_2_to_6_days_from_now do
      starts_tomorrow_ends_this_week(get_day_name_for_end(end_time_tuple))
    else
      starts_tomorrow()
    end
  end

  defp starts_2_to_6_days_from_now(start_date, {end_datetime, _, _} = end_time_tuple) do
    ends_same_day = get_service_date(end_time_tuple) == start_date
    ends_2_to_6_days_from_start = between_two_and_six_days(start_date, end_datetime)
    start_day_name = get_day_name(start_date)
    end_day_name = get_day_name_for_end(end_time_tuple)

    is_this_weekend =
      ["Saturday", "Sunday"] == [start_day_name, end_day_name] and
        Date.diff(get_service_date(end_time_tuple), start_date) == 1

    cond do
      ends_same_day ->
        starts_this_week_ends_same_day(start_day_name)

      is_this_weekend ->
        starts_this_week_and_is_weekend()

      ends_2_to_6_days_from_start ->
        starts_this_week_ends_next_week(start_day_name, end_day_name)

      true ->
        starts_this_week(start_day_name)
    end
  end

  # defp starts_more_than_six_days_from_now(
  #        start_date,
  #        end_date_tuple
  #      ) do
  #   if get_service_date(end_date_tuple) == start_date do
  #     distant_date_ends_same_day(get_human_readable_start_date(start_date))
  #   else
  #     distant_date(
  #       get_human_readable_start_date(start_date),
  #       get_human_readable_end_date(start_date, end_date_tuple)
  #     )
  #   end
  # end

  defp between_x_and_y_days(date_a, datetime_b, x, y) do
    # returns true if datetime_b falls between the beginning of service x days from
    # date_a and end of service y days from date_a

    beginning_of_service_on_day_x =
      Date.add(date_a, x) |> DateTime.new!(ActivePeriod.start_of_service_time(), @timezone)

    end_of_service_on_day_y =
      Date.add(date_a, y + 1) |> DateTime.new!(ActivePeriod.end_of_service_time(), @timezone)

    end_is_after_beginning_of_service_on_day_x =
      DateTime.compare(datetime_b, beginning_of_service_on_day_x) in [:gt, :eq]

    ends_before_end_of_service_day_on_day_y =
      DateTime.compare(datetime_b, end_of_service_on_day_y) in [:lt, :eq]

    end_is_after_beginning_of_service_on_day_x and
      ends_before_end_of_service_day_on_day_y
  end

  defp between_two_and_six_days(start_date, end_datetime) do
    # returns true if the end_datetime falls between the beginning of service 2 days from
    # start datetime and end of service 7 days from start_datetime

    beginning_of_service_on_day_two =
      Date.add(start_date, 2) |> DateTime.new!(ActivePeriod.start_of_service_time(), @timezone)

    end_of_service_on_day_seven =
      Date.add(start_date, 7) |> DateTime.new!(ActivePeriod.end_of_service_time(), @timezone)

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
      Date.add(start_date, 7) |> DateTime.new!(ActivePeriod.start_of_service_time(), @timezone)

    DateTime.compare(end_datetime, six_days_from_start) in [:gt, :eq]
  end

  defp within_x_days?(date_a, datetime_b, x) do
    # returns true if datetime_b is less than x days from start of service of date_a

    x_days_from_a =
      date_a
      |> DateTime.new!(ActivePeriod.start_of_service_time(), @timezone)
      |> DateTime.add(x, :day)

    DateTime.compare(datetime_b, x_days_from_a) === :lt
  end

  defp more_than_or_equal_x_days?(date_a, datetime_b, x) do
    # returns true if datetime_b is after the start of service x days after date_a

    x_days_from_a =
      date_a
      |> DateTime.new!(ActivePeriod.start_of_service_time(), @timezone)
      |> DateTime.add(x, :day)

    DateTime.compare(datetime_b, x_days_from_a) in [:gt, :eq]
  end

  defp same_day?(start_date, end_time_tuple) do
    get_service_date(end_time_tuple) == start_date
  end

  defp get_day_name_for_end(end_time_tuple) do
    end_time_tuple |> get_service_date |> get_day_name
  end

  defp get_service_date({_, end_date, end_time}) do
    # moves end day up 1 day if end time is before start of service
    if Time.compare(end_time, ActivePeriod.start_of_service_time()) in [:lt, :eq] do
      Date.add(end_date, -1)
    else
      end_date
    end
  end

  defp get_day_name(date) do
    date |> Timex.weekday() |> Timex.day_name()
  end

  defp get_human_readable_start_date(date) do
    "#{Timex.month_name(date.month)} #{date.day}"
  end

  defp get_human_readable_end_date({_, end_date, end_time}, format \\ nil) do
    # moves end date up 1 day if end time is before start of service
    # also ends month name on end date if start and end month are different

    end_date =
      if Time.compare(end_time, ActivePeriod.start_of_service_time()) in [:lt, :eq] do
        Date.add(end_date, -1)
      else
        end_date
      end

    case format do
      :month ->
        "#{Timex.month_name(end_date.month)}"

      :month_year ->
        "#{Timex.month_name(end_date.month)} #{end_date.year}"

      _ ->
        "#{Timex.month_name(end_date.month)} #{end_date.day}"
    end
  end

  @spec to_local_with_date(DateTime.t()) :: datetime_tuple()
  defp to_local_with_date(nil) do
    {nil, nil, nil}
  end

  defp to_local_with_date(datetime) do
    datetime = Timex.Timezone.convert(datetime, @timezone)
    {datetime, DateTime.to_date(datetime), DateTime.to_time(datetime)}
  end
end
