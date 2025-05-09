defmodule AlertsUIWeb.FormComponents.Helpers.AutoText.AutoTextDuration do
  @moduledoc """
    Durations for auto text.
    All datetimes are naive and in EST.
    All days are "service days"
    There's lots of nil checks because we can't be sure there's valid times/dates supplied
  """
  use Timex
  alias AlertsUI.Models.ActivePeriod
  alias AlertsUIWeb.FormComponents.Helpers.AutoText.BuildAutoText

  @spec build_duration_text(BuildAutoText.t()) :: String.t()
  def build_duration_text(autotext_data, current_time \\ current_time_naive())

  def build_duration_text(
        %{
          alert_timing: :"one-time",
          start_specifier: start_specifier,
          end_specifier: end_specifier,
          start_datetime: start_datetime,
          end_datetime: end_datetime
        },
        current_time
      ) do
    starts_today? = starts_today?(start_datetime, current_time)
    ends_today? = starts_today?(end_datetime, current_time)
    start_and_end_same_day? = start_and_end_same_day?(start_datetime, end_datetime)

    build_onetime_string(%{
      start_datetime: start_datetime,
      end_datetime: end_datetime,
      start_specifier: start_specifier,
      end_specifier: end_specifier,
      starts_today?: starts_today?,
      ends_today?: ends_today?,
      start_and_end_same_day?: start_and_end_same_day?
    })
  end

  def build_duration_text(
        %{
          alert_timing: :recurring,
          start_specifier: start_specifier,
          end_specifier: end_specifier,
          start_date: start_date,
          end_date: end_date,
          start_time: start_time,
          end_time: end_time,
          recurrence_days: recurrence_days
        },
        current_time
      ) do
    start_datetime = build_datetime(start_date, start_time)
    end_datetime = build_datetime(end_date, end_time)

    starts_today? = starts_today?(start_datetime, current_time)
    date_string = build_date_string(start_datetime, end_datetime, starts_today?)
    weekday_string = build_weekday_string(recurrence_days)
    time_string = build_time_string(start_time, end_time, start_specifier, end_specifier)

    "#{date_string} every #{weekday_string} #{time_string}"
  end

  # output string for one-time
  # # start of "now"
  def build_onetime_string(%{
        start_specifier: :now,
        end_specifier: :end_of_service,
        ends_today?: true
      }) do
    "today"
  end

  def build_onetime_string(%{
        end_datetime: end_datetime,
        start_specifier: :now,
        end_specifier: :custom,
        ends_today?: true
      }) do
    "until #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(%{
        end_datetime: end_datetime,
        start_specifier: :now,
        end_specifier: :end_of_service,
        ends_today?: false
      }) do
    "through #{format_date(end_datetime)}"
  end

  def build_onetime_string(%{
        end_datetime: end_datetime,
        start_specifier: :now,
        end_specifier: :custom,
        ends_today?: false
      }) do
    "until #{format_date(end_datetime)}"
  end

  # # start of "custom" today
  def build_onetime_string(%{
        start_datetime: start_datetime,
        start_specifier: :custom,
        end_specifier: :later_today,
        starts_today?: true
      }) do
    "beginning at #{datetime_to_formatted_time(start_datetime)}"
  end

  def build_onetime_string(%{
        start_datetime: start_datetime,
        start_specifier: :custom,
        end_specifier: :further_notice,
        starts_today?: true
      }) do
    "beginning at #{datetime_to_formatted_time(start_datetime)}"
  end

  def build_onetime_string(%{
        start_datetime: start_datetime,
        start_specifier: :custom,
        end_specifier: :end_of_service,
        starts_today?: true,
        start_and_end_same_day?: true
      }) do
    "from #{datetime_to_formatted_time(start_datetime)} to end of service"
  end

  def build_onetime_string(%{
        start_datetime: start_datetime,
        end_datetime: end_datetime,
        start_specifier: :custom,
        end_specifier: :end_of_service,
        starts_today?: true,
        start_and_end_same_day?: false
      }) do
    "from #{datetime_to_formatted_time(start_datetime)} through #{format_date(end_datetime)}"
  end

  def build_onetime_string(%{
        start_datetime: start_datetime,
        end_datetime: end_datetime,
        start_specifier: :custom,
        end_specifier: :custom,
        starts_today?: true,
        start_and_end_same_day?: true
      }) do
    "from #{datetime_to_formatted_time(start_datetime)} to #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(%{
        start_datetime: start_datetime,
        end_datetime: end_datetime,
        start_specifier: :custom,
        end_specifier: :custom,
        starts_today?: true,
        start_and_end_same_day?: false
      }) do
    "from #{datetime_to_formatted_time(start_datetime)} today to #{format_date(end_datetime)} at #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(_), do: ""

  # time strings for recurring
  def build_time_string(_, _, :start_of_service, :end_of_service), do: ""

  def build_time_string(_, nil, :start_of_service, :custom), do: "from start of service"

  def build_time_string(_, end_time, :start_of_service, :custom) do
    "from start of service to #{format_time(end_time)}"
  end

  def build_time_string(nil, _, :custom, :end_of_service), do: "to end of service"

  def build_time_string(start_time, _, :custom, :end_of_service) do
    "from #{format_time(start_time)} to end of service"
  end

  def build_time_string(nil, _, :custom, :custom), do: ""
  def build_time_string(_, nil, :custom, :custom), do: ""

  def build_time_string(start_time, end_time, :custom, :custom) do
    "from #{format_time(start_time)} to #{format_time(end_time)}"
  end

  def build_time_string(_, _, _, _), do: ""

  def build_date_string(nil, _, _), do: ""

  # date strings for recurring
  def build_date_string(start_datetime, end_datetime, false) do
    "from #{format_date(start_datetime)} to #{end_date_string(end_datetime, false)}"
  end

  def build_date_string(_start_datetime, end_datetime, true) do
    "until #{end_date_string(end_datetime, true)}"
  end

  defp end_date_string(nil, false), do: "until further notice"
  defp end_date_string(nil, true), do: "further notice"
  defp end_date_string(end_datetime, _), do: format_date(end_datetime)

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

  # weekdays for recurring
  def build_weekday_string([]), do: ""

  def build_weekday_string([_, _, _, _, _, _, _]) do
    "day"
  end

  def build_weekday_string(recurrence_days) do
    recurrence_days
    |> Enum.map(fn weekday ->
      Atom.to_string(weekday)
      |> String.capitalize()
    end)
    |> BuildAutoText.join_together()
  end

  # helpers
  defp start_and_end_same_day?(nil, _), do: false
  defp start_and_end_same_day?(_, nil), do: false

  defp start_and_end_same_day?(start_datetime, end_datetime) do
    start_ = start_datetime |> ActivePeriod.end_of_service_datetime_naive()
    end_ = end_datetime |> ActivePeriod.end_of_service_datetime_naive()

    NaiveDateTime.compare(start_, end_) === :eq
  end

  defp datetime_to_formatted_time(datetime) do
    datetime |> NaiveDateTime.to_time() |> format_time
  end

  defp format_time(time) do
    Timex.format!(time, "{h12}:{0m} {AM}")
  end

  defp format_date(datetime),
    do: Timex.format!(NaiveDateTime.to_date(datetime), "{WDshort}, {Mshort} {0D}")
end
