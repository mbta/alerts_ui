defmodule AlertsUIWeb.FormComponents.Helpers.RecurringDurationText do
  @moduledoc """
    Validators for time range component
  """
  use Timex

  def recurring_duration_text(params) do
    start_time = params["active_period_start_time"] |> ensure_time_format()
    end_time = params["active_period_end_time"] |> ensure_time_format()

    start_date = params["active_period_start_date"] |> ensure_date_format()
    end_date = params["active_period_end_date"] |> ensure_date_format()

    start_time_text = time_text(start_time)
    end_time_text = time_text(end_time)

    duration_text = duration(start_time, end_time)

    weekday_text = weekday_text(params["recurrence_days"])

    start_date_text = date_text(start_date, nil)
    end_date_text = date_text(end_date, params["active_period_end_specifier"])

    "#{start_time_text} – #{end_time_text}#{duration_text} every #{weekday_text} from #{start_date_text} until #{end_date_text}"
  end

  def time_text(nil), do: ""
  def time_text(""), do: ""

  def time_text(time) do
    Timex.format!(time, "{h12}:{0m} {AM}")
  end

  def date_text(_, "until_further_notice") do
    "alert is closed"
  end

  def date_text(nil, _), do: ""

  def date_text(date, _) do
    Timex.format!(date, "{WDshort} {Mshort} {0D}, {YYYY}")
  end

  defp duration(nil, _), do: ""
  defp duration(_, nil), do: ""

  defp duration(start_time, end_time) do
    plus_one =
      if Time.compare(start_time, end_time) === :lt do
        ""
      else
        "+1"
      end

    "#{plus_one} (#{duration_text(start_time, end_time)})"
  end

  defp duration_text(start_time, end_time) do
    Time.diff(end_time, start_time, :minute)

    minutes =
      if Time.compare(start_time, end_time) === :lt do
        Time.diff(start_time, end_time, :minute)
      else
        1440 + Time.diff(end_time, start_time, :minute)
      end

    minutes
    |> Duration.from_minutes()
    |> Timex.format_duration(:humanized)
  end

  def weekday_text(nil), do: ""
  def weekday_text([]), do: ""
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
      |> Enum.map(&String.capitalize/1)
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
