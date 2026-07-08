defmodule AlertsUI.TimeframeText do
  @moduledoc """
    Returns timeframe text given a start and end time
  """
  alias AlertsUI.Models.ActivePeriod

  @timezone "America/New_York"

  @type datetime_tuple :: {DateTime.t(), Date.t(), Time.t()}
  @type duration_certainties_t :: :KNOWN | :UNKNOWN | :ESTIMATED
  @type format_t :: :month | :month_year

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

  def timeframe_text(
        start_datetime,
        end_datetime,
        recurring,
        duration_certainty,
        current_datetime
      ) do
    # all datetimes are shifted to Eastern time and calculated from there
    {current_datetime, current_date, _} =
      current_time_tuple = to_local_with_date(current_datetime)

    {start_datetime, _, _} = start_time_tuple = to_local_with_date(start_datetime)

    end_time_tuple = if end_datetime, do: to_local_with_date(end_datetime), else: nil

    cond do
      # Alerts that start between now and in 30 minutes
      starts_now_or_soon?(start_datetime, current_datetime) ->
        starts_now_or_soon(current_date, end_time_tuple, recurring)

      # Alerts that have yet to start
      starts_in_future?(start_datetime, current_datetime) ->
        starts_in_future(start_time_tuple, current_time_tuple, end_time_tuple)

      # Alerts that have already started
      already_started?(start_datetime, current_datetime) ->
        already_started(
          start_time_tuple,
          current_time_tuple,
          end_time_tuple,
          recurring,
          duration_certainty
        )

      true ->
        nil
    end
  end

  ## Helpers for alerts that start now and in 30 minutes
  @spec starts_now_or_soon?(DateTime.t(), DateTime.t()) :: boolean()
  defp starts_now_or_soon?(start_datetime, current_datetime) do
    soon_datetime = DateTime.add(current_datetime, 30, :minute)
    in_future? = DateTime.compare(start_datetime, current_datetime) in [:eq, :gt]
    soon? = DateTime.compare(soon_datetime, start_datetime) in [:eq, :gt]

    if soon? and in_future? do
      true
    else
      false
    end
  end

  @spec starts_now_or_soon(Date.t(), datetime_tuple(), boolean()) :: String.t() | nil
  defp starts_now_or_soon(_current_date, _end_time_tuple, true), do: "starting today"

  defp starts_now_or_soon(current_date, end_time_tuple, _recurring),
    do: text_based_on_end(current_date, end_time_tuple)

  @spec text_based_on_end(Date.t(), datetime_tuple() | nil) :: String.t() | nil
  defp text_based_on_end(_, nil), do: nil

  defp text_based_on_end(current_date, end_time_tuple) do
    {end_datetime, _, _} = end_time_tuple

    cond do
      ends_tomorrow?(current_date, end_time_tuple) ->
        "through tomorrow"

      between_x_and_y_days?(current_date, end_datetime, 2, 6) ->
        "through #{get_day_name_for_end(end_time_tuple)}"

      between_x_and_y_days?(current_date, end_datetime, 7, 90) ->
        "through #{get_human_readable_end_date(end_time_tuple)}"

      more_than_x_days?(current_date, end_datetime, 90, true) and
          ends_this_year?(current_date, end_datetime) ->
        "until #{get_human_readable_end_date(end_time_tuple, :month)}"

      more_than_x_days?(current_date, end_datetime, 90, true) and
          ends_after_this_year?(current_date, end_datetime) ->
        "until #{get_human_readable_end_date(end_time_tuple, :month_year)}"

      true ->
        nil
    end
  end

  ## Helpers for alerts that have yet to start
  @spec starts_in_future?(DateTime.t(), DateTime.t()) :: boolean()
  defp starts_in_future?(start_datetime, current_datetime) do
    DateTime.compare(start_datetime, current_datetime) == :gt
  end

  @spec starts_in_future(datetime_tuple(), datetime_tuple(), datetime_tuple()) :: String.t() | nil
  defp starts_in_future(
         {start_datetime, start_date, _},
         {current_datetime, current_date, _},
         end_time_tuple
       ) do
    cond do
      starts_today?(start_datetime, current_datetime) ->
        starts_later_today(current_date, end_time_tuple)

      starts_tomorrow?(start_datetime, current_date) ->
        starts_tomorrow(current_date, end_time_tuple)

      between_x_and_y_days?(current_date, start_datetime, 2, 6) ->
        starts_2_to_6_days_from_now(start_date, current_date, end_time_tuple)

      more_than_x_days?(current_date, start_datetime, 7, true) ->
        starts_a_while_later(start_date, end_time_tuple)
    end
  end

  @spec starts_today?(DateTime.t(), DateTime.t()) :: boolean()
  defp starts_today?(start_datetime, current_datetime) do
    starts_in_future?(start_datetime, current_datetime) &&
      DateTime.to_date(start_datetime) == DateTime.to_date(current_datetime)
  end

  @spec starts_tomorrow?(DateTime.t(), Date.t()) :: boolean()
  defp starts_tomorrow?(start_datetime, current_date) do
    # returns true if the start_datetime is at or after the start of service for the next day
    tomorrow_start_of_service =
      current_date
      |> DateTime.new!(ActivePeriod.start_of_service_time(), @timezone)
      |> DateTime.add(1, :day)

    DateTime.compare(start_datetime, tomorrow_start_of_service) in [:gt, :eq] &&
      DateTime.to_date(start_datetime) == DateTime.to_date(tomorrow_start_of_service)
  end

  @spec starts_later_today(Date.t(), datetime_tuple() | nil) :: String.t()
  defp starts_later_today(_current_date, nil) do
    "starting later today"
  end

  defp starts_later_today(current_date, end_time_tuple) do
    ends_today? = same_day?(current_date, end_time_tuple)

    if ends_today? do
      "later today"
    else
      "starting later today"
    end
  end

  @spec starts_tomorrow(Date.t(), datetime_tuple() | nil) :: String.t()
  defp starts_tomorrow(_, nil), do: "starting tomorrow"

  defp starts_tomorrow(
         current_date,
         {end_datetime, _end_date, _end_time} = end_time_tuple
       ) do
    ends_tomorrow = ends_tomorrow?(current_date, end_time_tuple)

    ends_within_7_days = within_x_days?(current_date, end_datetime, 7, true)
    ends_over_7_days_from_now = more_than_x_days?(current_date, end_datetime, 7)

    cond do
      ends_tomorrow ->
        "tomorrow"

      ends_within_7_days ->
        "tomorrow through #{get_day_name_for_end(end_time_tuple)}"

      ends_over_7_days_from_now ->
        "starting tomorrow"

      true ->
        "starting tomorrow"
    end
  end

  @spec starts_2_to_6_days_from_now(Date.t(), Date.t(), datetime_tuple() | nil) ::
          String.t() | nil
  defp starts_2_to_6_days_from_now(start_date, _current_date, nil) do
    "starting #{get_day_name(start_date)}"
  end

  defp starts_2_to_6_days_from_now(
         start_date,
         current_date,
         {end_datetime, end_date, _} = end_time_tuple
       ) do
    start_end_same_day = same_day?(start_date, end_time_tuple)
    ends_within_7_days = within_x_days?(current_date, end_datetime, 7, true)
    ends_over_7_days_from_now = more_than_x_days?(current_date, end_datetime, 7)

    start_day_name = get_day_name(start_date)
    end_day_name = get_day_name_for_end(end_time_tuple)

    is_this_weekend =
      ["Saturday", "Sunday"] == [start_day_name, end_day_name] and
        Date.diff(get_service_date(end_time_tuple), start_date) == 1

    cond do
      start_end_same_day ->
        get_day_name(start_date)

      is_this_weekend ->
        "this weekend"

      ends_within_7_days ->
        "#{get_day_name(start_date)} through #{get_day_name(end_date)}"

      ends_over_7_days_from_now ->
        "starting #{get_day_name(start_date)}"

      true ->
        nil
    end
  end

  @spec starts_a_while_later(Date.t(), datetime_tuple() | nil) :: String.t()
  defp starts_a_while_later(start_date, nil) do
    "starting #{get_human_readable_start_date(start_date)}"
  end

  defp starts_a_while_later(start_date, {_, end_date, _} = end_time_tuple) do
    start_end_same_day = same_day?(start_date, end_time_tuple)
    start_end_same_month = start_date.month == end_date.month

    cond do
      start_end_same_day ->
        "#{get_human_readable_start_date(start_date)}"

      start_end_same_month ->
        "#{get_human_readable_start_date(start_date)}-#{end_date.day}"

      true ->
        "starting #{get_human_readable_start_date(start_date)}"
    end
  end

  ## Helpers for alerts that have already started
  @spec already_started?(DateTime.t(), DateTime.t()) :: boolean()
  defp already_started?(start_datetime, current_datetime) do
    DateTime.compare(start_datetime, current_datetime) == :lt
  end

  @spec already_started(
          datetime_tuple(),
          datetime_tuple(),
          datetime_tuple(),
          boolean(),
          duration_certainties_t()
        ) :: boolean()
  defp already_started(
         {_, start_date, _},
         {current_datetime, current_date, _},
         end_time_tuple,
         recurring,
         duration_certainty
       ) do
    cond do
      within_x_days?(start_date, current_datetime, 7) and not recurring ->
        started_recently(current_date, end_time_tuple)

      within_x_days?(start_date, current_datetime, 30) and recurring ->
        started_recently(current_date, end_time_tuple)

      more_than_x_days?(start_date, current_datetime, 7, true) and
          not recurring ->
        started_a_while_ago(current_date, end_time_tuple, duration_certainty)

      more_than_x_days?(start_date, current_datetime, 30, true) and
          recurring ->
        started_a_while_ago(current_date, end_time_tuple, duration_certainty)
    end
  end

  @spec started_recently(Date.t(), datetime_tuple() | nil) :: String.t() | nil
  defp started_recently(_, nil), do: nil

  defp started_recently(current_date, end_time_tuple) do
    if ends_today?(current_date, end_time_tuple) do
      nil
    else
      text_based_on_end(current_date, end_time_tuple)
    end
  end

  @spec started_a_while_ago(Date.t(), datetime_tuple() | nil, duration_certainties_t) ::
          String.t()
  defp started_a_while_ago(_current_date, nil, _duration_certainty), do: "ongoing"

  defp started_a_while_ago(current_date, end_time_tuple, duration_certainty) do
    later_today? = same_day?(current_date, end_time_tuple) and duration_certainty == :KNOWN

    if later_today? do
      "last day"
    else
      "ongoing"
    end
  end

  ## General helpers

  @spec ends_today?(Date.t(), datetime_tuple() | nil) :: boolean()
  defp ends_today?(_, nil), do: false

  defp ends_today?(current_date, {_end_datetime, end_date, end_time} = _end_time_tuple) do
    end_date == current_date and
      Time.compare(ActivePeriod.end_of_service_time(), end_time) in [:lt, :eq]
  end

  @spec ends_tomorrow?(Date.t(), datetime_tuple()) :: boolean()
  defp ends_tomorrow?(current_date, {_end_datetime, end_date, end_time} = _end_time_tuple) do
    end_date == current_date |> Date.add(1) and
      Time.compare(ActivePeriod.end_of_service_time(), end_time) in [:lt, :eq]
  end

  @spec ends_this_year?(Date.t(), DateTime.t()) :: boolean()
  defp ends_this_year?(current_date, end_datetime) do
    last_datetime_of_year =
      %{current_date | month: 12, day: 31}
      |> DateTime.new!(ActivePeriod.start_of_service_time(), @timezone)

    DateTime.compare(end_datetime, last_datetime_of_year) in [:lt, :eq]
  end

  @spec ends_after_this_year?(Date.t(), DateTime.t()) :: boolean()
  defp ends_after_this_year?(current_date, end_datetime) do
    last_datetime_of_year =
      %{current_date | month: 12, day: 31}
      |> DateTime.new!(ActivePeriod.start_of_service_time(), @timezone)

    DateTime.compare(end_datetime, last_datetime_of_year) == :gt
  end

  @spec between_x_and_y_days?(Date.t(), DateTime.t(), integer(), integer()) :: boolean()
  defp between_x_and_y_days?(date_a, datetime_b, x, y) do
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

  @spec within_x_days?(Date.t(), DateTime.t(), integer(), boolean() | nil) :: boolean()
  defp within_x_days?(date_a, datetime_b, x, or_equal \\ false) do
    # returns true if datetime_b is less than x days from end of service of date_a
    comparisons = if or_equal, do: [:lt, :eq], else: [:lt]

    x_days_from_a =
      date_a
      |> DateTime.new!(ActivePeriod.end_of_service_time(), @timezone)
      # +1 because end of service is 3am the next day
      |> DateTime.add(x + 1, :day)

    DateTime.compare(datetime_b, x_days_from_a) in comparisons
  end

  @spec more_than_x_days?(Date.t(), DateTime.t(), integer(), boolean() | nil) :: boolean()
  defp more_than_x_days?(date_a, datetime_b, x, or_equal \\ false) do
    # returns true if datetime_b is after the start of service x days after date_a
    comparisons = if or_equal, do: [:gt, :eq], else: [:gt]

    x_days_from_a =
      date_a
      |> DateTime.new!(ActivePeriod.start_of_service_time(), @timezone)
      |> DateTime.add(x, :day)

    DateTime.compare(datetime_b, x_days_from_a) in comparisons
  end

  @spec same_day?(Date.t(), datetime_tuple()) :: boolean()
  defp same_day?(start_date, end_time_tuple) do
    get_service_date(end_time_tuple) == start_date
  end

  @spec get_day_name_for_end(datetime_tuple()) :: String.t()
  defp get_day_name_for_end(end_time_tuple) do
    end_time_tuple |> get_service_date |> get_day_name
  end

  @spec get_service_date(datetime_tuple()) :: Date.t()
  defp get_service_date({_, end_date, end_time}) do
    # moves end day up 1 day if end time is before start of service
    if Time.compare(end_time, ActivePeriod.start_of_service_time()) in [:lt, :eq] do
      Date.add(end_date, -1)
    else
      end_date
    end
  end

  @spec get_day_name(Date.t()) :: String.t()
  defp get_day_name(date) do
    date |> Timex.weekday() |> Timex.day_name()
  end

  @spec get_day_name(Date.t()) :: String.t()
  defp get_human_readable_start_date(date) do
    "#{Timex.month_name(date.month)} #{date.day}"
  end

  @spec get_human_readable_end_date(datetime_tuple(), format_t | nil) :: String.t()
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
  defp to_local_with_date(datetime) do
    datetime = Timex.Timezone.convert(datetime, @timezone)
    {datetime, DateTime.to_date(datetime), DateTime.to_time(datetime)}
  end
end
