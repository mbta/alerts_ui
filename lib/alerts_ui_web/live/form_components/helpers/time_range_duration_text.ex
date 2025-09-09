defmodule AlertsUIWeb.FormComponents.Helpers.TimeRangeDurationText do
  @moduledoc """
    Constructs one-time time range duration text for time-range component.
  """
  use Timex

  def one_time_duration_text(params) do
    start_text = one_time_duration_start_phrase(params)
    end_text = one_time_duration_end_phrase(params)
    duration = one_time_duration_phrase(params)

    "#{start_text} #{end_text} #{duration}"
  end

  def one_time_duration_start_phrase(params) do
    start_dt = ensure_naive_datetime_format(params["active_period_start"])

    start_text =
      start_text(params["active_period_start_specifier"], start_dt)

    "#{start_text} until"
  end

  def one_time_duration_end_phrase(params) do
    end_dt = ensure_naive_datetime_format(params["active_period_end"])

    end_text(params["active_period_end_specifier"], end_dt)
  end

  def one_time_duration_phrase(params) do
    start_dt = ensure_naive_datetime_format(params["active_period_start"])
    end_dt = ensure_naive_datetime_format(params["active_period_end"])

    duration(
      params["active_period_end_specifier"],
      start_dt,
      end_dt
    )
  end

  def get_start_text(start_specifier, start) do
    start_dt = ensure_naive_datetime_format(start)

    start_text(start_specifier, start_dt)
  end

  defp start_text("now", _start_dt), do: "Now"

  defp start_text(_, nil), do: ""

  defp start_text(_specifier, start_dt) do
    Timex.format!(start_dt, "{WDshort} {Mshort} {0D}, {YYYY} @ {h12}:{0m} {AM}")
  end

  defp end_text(:until_further_notice, end_dt), do: end_text("until_further_notice", end_dt)

  defp end_text("until_further_notice", _end_dt) do
    "alert is manually closed"
  end

  defp end_text("later_today", _end_dt) do
    "later today"
  end

  defp end_text(:later_today, _end_dt) do
    "later today"
  end

  defp end_text(_, nil), do: ""

  defp end_text(_, end_dt) do
    Timex.format!(end_dt, "{WDshort} {Mshort} {0D}, {YYYY} @ {h12}:{0m} {AM}")
  end

  defp duration(:until_further_notice, _, _), do: "(indefinite)"

  defp duration("until_further_notice", _start_dt, _end_dt) do
    "(indefinite)"
  end

  defp duration(_, nil, _), do: ""
  defp duration(_, _, nil), do: ""

  defp duration(:later_today, start_dt, end_dt), do: duration("later_today", start_dt, end_dt)

  defp duration("later_today", start_dt, end_dt) do
    "(max #{duration_text(start_dt, end_dt)})"
  end

  defp duration(:end_of_service, start_dt, end_dt),
    do: duration("end_of_service", start_dt, end_dt)

  defp duration(_, start_dt, end_dt) do
    "(#{duration_text(start_dt, end_dt)})"
  end

  defp duration_text(start_dt, end_dt) do
    if NaiveDateTime.compare(start_dt, end_dt) === :lt do
      Interval.new(from: Timex.set(start_dt, second: 0), until: Timex.set(end_dt, second: 0))
      |> Interval.duration(:duration)
      |> Timex.format_duration(:humanized)
    else
      ""
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

  defp ensure_naive_datetime_format(%NaiveDateTime{} = datetime), do: datetime
end
