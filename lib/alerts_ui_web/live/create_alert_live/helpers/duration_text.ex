defmodule AlertsUIWeb.CreateAlertLive.Helpers.DurationText do
  @moduledoc """
  Helpers to ghenerate time range durations
  """

  use Timex
  use AlertsUIWeb, :live_component

  # One-Time

  def one_time_duration_text(form) do
    start_text = one_time_duration_start_phrase(form)
    end_text = one_time_duration_end_phrase(form)
    duration = one_time_duration_phrase(form)

    "#{start_text} #{end_text} #{duration}"
  end

  def one_time_duration_start_phrase(form) do
    start_dt = ensure_naive_datetime_format(form[:active_period_start].value)
    start_text = start_text(start_dt)

    "#{start_text} until"
  end

  def one_time_duration_end_phrase(form) do
    end_dt = ensure_naive_datetime_format(form[:active_period_end].value)

    end_text(form[:active_period_end_specifier].value, end_dt)
  end

  def one_time_duration_phrase(form) do
    start_dt = ensure_naive_datetime_format(form[:active_period_start].value)
    end_dt = ensure_naive_datetime_format(form[:active_period_end].value)

    duration(
      form[:active_period_end_specifier].value,
      start_dt,
      end_dt
    )
  end

  defp start_text(nil), do: ""

  defp start_text(start_dt) do
    Calendar.strftime(start_dt, "%a %b %-d, %Y @ %-I:%M %p")
  end

  defp end_text(:until_further_notice, end_dt), do: end_text("until_further_notice", end_dt)

  defp end_text("until_further_notice", _end_dt) do
    "alert is manually closed"
  end

  defp end_text(:when_work_order_is_closed, end_dt),
    do: end_text("when_work_order_is_closed", end_dt)

  defp end_text("when_work_order_is_closed", _end_dt) do
    "a work order with this facility ID is closed"
  end

  defp end_text("later_today", _end_dt) do
    "later today"
  end

  defp end_text(:later_today, _end_dt) do
    "later today"
  end

  defp end_text(_, nil), do: ""

  defp end_text(_, end_dt) do
    Calendar.strftime(end_dt, "%a %b %-d, %Y @ %-I:%M %p")
  end

  defp duration(:until_further_notice, _, _), do: "(indefinite)"
  defp duration("until_further_notice", _, _), do: "(indefinite)"

  defp duration(:when_work_order_is_closed, _, _), do: ""
  defp duration("when_work_order_is_closed", _, _), do: ""

  defp duration(_, nil, _), do: ""
  defp duration(_, _, nil), do: ""

  defp duration(:later_today, start_dt, end_dt), do: duration("later_today", start_dt, end_dt)

  defp duration("later_today", start_dt, end_dt) do
    "(max #{duration_text(start_dt, end_dt)})"
  end

  defp duration(_, start_dt, end_dt) do
    "(#{duration_text(start_dt, end_dt)})"
  end

  defp duration_text(start_dt, end_dt) do
    if NaiveDateTime.diff(end_dt, start_dt, :second) > 60 do
      Interval.new(from: Timex.set(start_dt, second: 0), until: Timex.set(end_dt, second: 0))
      |> Interval.duration(:duration)
      |> Timex.format_duration(:humanized)
    else
      "0 minutes"
    end
  end

  @spec ensure_naive_datetime_format(nil | String.t() | NaiveDateTime.t()) ::
          nil | NaiveDateTime.t()
  defp ensure_naive_datetime_format(nil), do: nil

  defp ensure_naive_datetime_format(""), do: nil

  defp ensure_naive_datetime_format(datetime) when is_binary(datetime) do
    {result, time} = datetime |> String.pad_trailing(19, ":00") |> NaiveDateTime.from_iso8601()

    if result === :ok do
      time
    else
      nil
    end
  end

  defp ensure_naive_datetime_format(%DateTime{} = datetime), do: DateTime.to_naive(datetime)
  defp ensure_naive_datetime_format(%NaiveDateTime{} = datetime), do: datetime

  # Recurring

  # These strings are all built using time values, which are not generally
  # editable in the same way plain strings are.

  # sobelow_skip ["XSS.Raw"]
  def recurring_duration_text(form) do
    start_date = form[:active_period_start_date].value
    start_time = form[:active_period_start_time].value
    end_date = form[:active_period_end_date].value
    end_time = form[:active_period_end_time].value
    end_specifier = form[:active_period_end_specifier].value
    recurrence_days = form[:recurrence_days].value

    time_range_text = recurring_duration_time_range(start_time, end_time)
    duration_text = duration(start_time, end_time)
    recurrence_day_text = recurring_duration_recurrence_days(recurrence_days)
    date_range_text = recurring_duration_date_range(start_date, end_date, end_specifier)

    raw("#{time_range_text} #{duration_text} #{recurrence_day_text} from #{date_range_text}")
  end

  def recurring_duration_date_range(start_date, end_date, end_specifier) do
    start_date_text = date_text(start_date, nil)
    end_date_text = date_text(end_date, end_specifier)

    start_date_text <> " until " <> end_date_text
  end

  def recurring_duration_recurrence_days(recurrence_days) do
    "every " <> weekday_text(recurrence_days)
  end

  def recurring_duration_time_range(start_time, end_time) do
    plus_one_sup =
      if plus_one?(start_time, end_time),
        do: "<sup>+1</sup>",
        else: ""

    "#{time_text(start_time)} – #{time_text(end_time)}#{plus_one_sup}"
  end

  def time_text(nil), do: ""
  def time_text(""), do: ""

  def time_text(time) do
    Timex.format!(time, "{h12}:{0m} {AM}")
  end

  def plus_one?(%Time{} = start_time, %Time{} = end_time) do
    Time.compare(start_time, end_time) !== :lt
  end

  def plus_one?(_start_time, _end_time), do: false

  def date_text(_, :until_further_notice) do
    "alert is manually closed"
  end

  def date_text(_, "until_further_notice") do
    "alert is manually closed"
  end

  def date_text(nil, _), do: ""

  def date_text(date, _) do
    Timex.format!(date, "{WDshort} {Mshort} {0D}, {YYYY}")
  end

  defp duration(nil, _), do: ""
  defp duration(_, nil), do: ""

  defp duration(start_time, end_time) do
    Time.diff(end_time, start_time, :minute)

    minutes =
      if Time.compare(start_time, end_time) === :lt do
        Time.diff(start_time, end_time, :minute)
      else
        1440 + Time.diff(end_time, start_time, :minute)
      end

    duration_text =
      minutes
      |> Duration.from_minutes()
      |> Timex.format_duration(:humanized)

    "(#{duration_text})"
  end

  def weekday_text(nil), do: ""
  def weekday_text([]), do: ""

  def weekday_text([day | _] = weekday_list) when is_atom(day) do
    weekday_list
    |> Enum.map(fn day -> Atom.to_string(day) end)
    |> weekday_text
  end

  def weekday_text([day]), do: String.capitalize(day)

  def weekday_text([day_1, day_2]) do
    "#{String.capitalize(day_1)} and #{String.capitalize(day_2)}"
  end

  def weekday_text([_, _, _, _, _, _, _]) do
    "day"
  end

  def weekday_text(weekday_list) do
    [hd | tail] =
      weekday_list
      |> Enum.map(fn weekday -> String.capitalize(weekday) end)
      |> Enum.reverse()

    ["and " <> hd | tail]
    |> Enum.reverse()
    |> Enum.join(", ")
  end
end
