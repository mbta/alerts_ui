defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.DurationText do
  @moduledoc """
  Helpers to ghenerate time range durations
  """

  use Timex
  use AlertsUIWeb, :live_component

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

  @spec ensure_date_format(nil | String.t() | Date.t()) ::
          nil | Date.t()
  defp ensure_date_format(nil), do: nil

  defp ensure_date_format(""), do: nil

  defp ensure_date_format(date) when is_binary(date) do
    Date.from_iso8601!(date)
  end

  defp ensure_date_format(%Date{} = date), do: date

  defp ensure_time_format(nil), do: nil

  @spec ensure_time_format(nil | String.t() | Time.t()) ::
          nil | Time.t()
  defp ensure_time_format(""), do: nil

  defp ensure_time_format(time) when is_binary(time) do
    time
    |> String.pad_trailing(08, ":00")
    |> Time.from_iso8601!()
  end

  defp ensure_time_format(%Time{} = time), do: time
end
