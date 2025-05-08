defmodule AlertsUIWeb.FormComponents.Helpers.AutoText.AutoTextDuration do
  @moduledoc """
    Durations for auto text.
    All datetimes are naive and in EST.
  """
  use Timex
  alias AlertsUI.Models.ActivePeriod
  alias AlertsUIWeb.FormComponents.Helpers.AutoText

  @spec build_duration_text(AutoText.BuildAutoText.t()) :: String.t()
  def build_duration_text(%{alert_timing: :one_time} = autotext_data) do
    ""
  end

  def build_duration_text(%{
        alert_timing: :recurring,
        start_specifier: start_specifier,
        end_specifier: end_specifier,
        start_date: start_date,
        end_date: end_date,
        start_time: start_time,
        end_time: end_time,
        recurrence_days: recurrence_days
      }) do
    start_datetime = build_datetime(start_date, start_time)
    end_datetime = build_datetime(end_date, end_time)

    starts_today? = starts_today?(start_datetime, current_time_naive())
    date_string = build_date_string(start_datetime, end_datetime, starts_today?)
  end

  def build_date_string(nil, _, _), do: ""

  def build_date_string(start_datetime, end_datetime, false) do
    "from #{formatted_date_string(start_datetime)} to #{end_date_string(end_datetime, false)}"
  end

  def build_date_string(_start_datetime, end_datetime, true) do
    "until #{end_date_string(end_datetime, true)}"
  end

  defp end_date_string(nil, false), do: "until further notice"
  defp end_date_string(nil, true), do: "further notice"
  defp end_date_string(end_datetime, _), do: formatted_date_string(end_datetime)

  defp formatted_date_string(datetime),
    do: Timex.format!(NaiveDateTime.to_date(datetime), "{WDshort}, {Mshort} {0D}")

  def starts_today?(nil, _), do: false

  def starts_today?(start_datetime, current_time) do
    next_end_of_service = ActivePeriod.end_of_service_datetime_naive(current_time)
    NaiveDateTime.compare(start_datetime, next_end_of_service) in [:lt, :eq]
  end

  defp build_datetime(nil, _), do: nil
  defp build_datetime(_, nil), do: nil

  defp build_datetime(date, time) do
    NaiveDateTime.new!(date, time)
  end

  defp current_time_naive do
    DateTime.utc_now()
    |> DateTime.shift_zone!("America/New_York")
    |> DateTime.to_naive()
  end
end
