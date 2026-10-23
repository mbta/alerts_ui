defmodule AlertsUIWeb.CreateAlertLive.Helpers.TimeRangeDurationText do
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
      start_text(start_dt)

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

  def get_start_text(start) do
    start_dt = ensure_naive_datetime_format(start)
    start_text(start_dt)
  end

  defp start_text(nil), do: ""

  defp start_text(start_dt) do
    Calendar.strftime(start_dt, "%a %b %-d, %Y @ %-I:%M %p")
  end

  def notification_period_end_text(
        true = _end_in_past?,
        %NaiveDateTime{} = notification_period_end
      ) do
    end_text(nil, notification_period_end)
  end

  def notification_period_end_text(_, _), do: "alert is closed"

  defp end_text(:until_further_notice, end_dt), do: end_text("until_further_notice", end_dt)

  defp end_text("until_further_notice", _end_dt) do
    "alert is manually closed"
  end

  defp end_text(:when_work_order_is_closed, end_dt),
    do: end_text("when_work_order_is_closed", end_dt)

  defp end_text("when_work_order_is_closed", _end_dt) do
    "a work order for this facility is closed"
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
end
