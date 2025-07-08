defmodule AlertsUIWeb.FormComponents.Helpers.AutoText.AutoTextDuration do
  @moduledoc """
    Durations for auto text.
    All datetimes are naive and in EST.
  """
  alias AlertsUI.Models.ActivePeriod
  alias AlertsUIWeb.FormComponents.Helpers.AutoText.BuildAutoText

  @spec build_duration_text(BuildAutoText.t()) :: String.t()
  def build_duration_text(autotext_data, current_time \\ current_time_naive())

  def build_duration_text(
        # duration text for alerts with 1 active period
        %{
          alert_timing: :"one-time",
          start_specifier: start_specifier,
          end_specifier: end_specifier,
          start_datetime: start_datetime,
          end_datetime: end_datetime
        },
        current_time
      ) do
    start_specifier = change_start_specifier(start_datetime, start_specifier)
    end_specifier = change_end_specifier(end_datetime, end_specifier)

    starts_today? = happens_today?(start_datetime, current_time)

    within_same_service_day? =
      within_same_service_day?(start_datetime, end_datetime)

    within_same_calendar_day? =
      within_same_calendar_day?(start_datetime, end_datetime)

    build_onetime_string(%{
      start_datetime: start_datetime,
      end_datetime: end_datetime,
      start_specifier: start_specifier,
      end_specifier: end_specifier,
      starts_today?: starts_today?,
      within_same_service_day?: within_same_service_day?,
      within_same_calendar_day?: within_same_calendar_day?
    })
  end

  def build_duration_text(
        # duration text for alerts with more than 1 active period
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
    start_specifier = change_start_specifier(start_time, start_specifier)
    end_specifier = change_end_specifier(end_time, end_specifier)

    start_datetime = build_datetime(start_date, start_time)
    end_datetime = build_datetime(end_date, end_time)

    starts_today? = happens_today?(start_datetime, current_time)
    date_string = build_date_string(start_datetime, end_datetime, starts_today?)
    weekday_string = build_weekday_string(recurrence_days)
    time_string = build_time_string(start_time, end_time, start_specifier, end_specifier)

    "#{date_string} every #{weekday_string} #{time_string}"
  end

  def build_duration_text(_, _), do: ""

  # output string for one-time
  # # start of "now"
  def build_onetime_string(%{
        start_specifier: :now,
        end_specifier: :end_of_service,
        within_same_service_day?: true
      }) do
    "today"
  end

  def build_onetime_string(%{
        start_specifier: :now,
        end_specifier: :custom,
        within_same_service_day?: true,
        end_datetime: end_datetime
      }) do
    "until #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :now,
        end_specifier: :end_of_service,
        within_same_service_day?: false,
        end_datetime: end_datetime
      }) do
    formatted_end = end_datetime |> ActivePeriod.naive_datetime_to_service_date() |> format_date
    "through #{formatted_end}"
  end

  def build_onetime_string(%{
        start_specifier: :now,
        end_specifier: :custom,
        within_same_service_day?: false,
        end_datetime: end_datetime
      }) do
    "until #{datetime_to_formatted_date(end_datetime)}"
  end

  # # start of "custom" today
  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :later_today,
        starts_today?: true,
        start_datetime: start_datetime
      }) do
    "beginning at #{datetime_to_formatted_time(start_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :further_notice,
        starts_today?: true,
        start_datetime: start_datetime
      }) do
    "beginning at #{datetime_to_formatted_time(start_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :end_of_service,
        starts_today?: true,
        within_same_service_day?: true,
        start_datetime: start_datetime
      }) do
    "from #{datetime_to_formatted_time(start_datetime)} to end of service"
  end

  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :end_of_service,
        start_datetime: start_datetime,
        starts_today?: true,
        within_same_service_day?: false,
        end_datetime: end_datetime
      }) do
    formatted_end = end_datetime |> ActivePeriod.naive_datetime_to_service_date() |> format_date
    "from #{datetime_to_formatted_time(start_datetime)} through #{formatted_end}"
  end

  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :custom,
        starts_today?: true,
        within_same_service_day?: true,
        start_datetime: start_datetime,
        end_datetime: end_datetime
      }) do
    "from #{datetime_to_formatted_time(start_datetime)} to #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :custom,
        starts_today?: true,
        within_same_service_day?: false,
        start_datetime: start_datetime,
        end_datetime: end_datetime
      }) do
    "from #{datetime_to_formatted_time(start_datetime)} today to #{datetime_to_formatted_date(end_datetime)} at #{datetime_to_formatted_time(end_datetime)}"
  end

  # # start of custom in future

  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :custom,
        starts_today?: false,
        within_same_service_day?: false,
        start_datetime: start_datetime,
        end_datetime: end_datetime
      }) do
    "from #{datetime_to_formatted_date(start_datetime)} at #{datetime_to_formatted_time(start_datetime)} - #{datetime_to_formatted_date(end_datetime)} at #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :end_of_service,
        starts_today?: false,
        within_same_service_day?: false,
        start_datetime: start_datetime,
        end_datetime: end_datetime
      }) do
    formatted_end_date =
      end_datetime |> ActivePeriod.naive_datetime_to_service_date() |> format_date

    "from #{datetime_to_formatted_date(start_datetime)} at #{datetime_to_formatted_time(start_datetime)} - #{formatted_end_date}"
  end

  def build_onetime_string(%{
        start_specifier: :custom,
        starts_today?: false,
        within_same_service_day?: false,
        start_datetime: start_datetime
      }) do
    "beginning #{datetime_to_formatted_date(start_datetime)} at #{datetime_to_formatted_time(start_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :custom,
        starts_today?: false,
        within_same_service_day?: true,
        within_same_calendar_day?: true,
        start_datetime: start_datetime,
        end_datetime: end_datetime
      }) do
    "from #{datetime_to_formatted_time(start_datetime)} to #{datetime_to_formatted_time(end_datetime)} on #{datetime_to_formatted_date(start_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :custom,
        starts_today?: false,
        within_same_service_day?: true,
        within_same_calendar_day?: false,
        start_datetime: start_datetime,
        end_datetime: end_datetime
      }) do
    "from #{datetime_to_formatted_date(start_datetime)} at #{datetime_to_formatted_time(start_datetime)} - #{datetime_to_formatted_date(end_datetime)} at #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :end_of_service,
        starts_today?: false,
        within_same_service_day?: true,
        start_datetime: start_datetime
      }) do
    "on #{datetime_to_formatted_date(start_datetime)} starting at #{datetime_to_formatted_time(start_datetime)}"
  end

  # # start of "start of service" in future
  def build_onetime_string(%{
        start_specifier: :start_of_service,
        end_specifier: :end_of_service,
        starts_today?: false,
        within_same_service_day?: true,
        start_datetime: start_datetime
      }) do
    "on #{datetime_to_formatted_date(start_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :start_of_service,
        end_specifier: :until_further_notice,
        starts_today?: false,
        within_same_service_day?: false,
        start_datetime: start_datetime
      }) do
    "beginning #{datetime_to_formatted_date(start_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :start_of_service,
        end_specifier: :end_of_service,
        starts_today?: false,
        within_same_service_day?: false,
        start_datetime: start_datetime,
        end_datetime: end_datetime
      }) do
    start_weekday = start_datetime |> NaiveDateTime.to_date() |> Calendar.strftime("%A")

    end_weekday =
      end_datetime |> ActivePeriod.naive_datetime_to_service_date() |> Calendar.strftime("%A")

    formatted_end_date =
      end_datetime |> ActivePeriod.naive_datetime_to_service_date() |> format_date

    if {start_weekday, end_weekday} == {"Saturday", "Sunday"} do
      "the weekend of #{datetime_to_formatted_date(start_datetime)} - #{formatted_end_date}"
    else
      "from #{datetime_to_formatted_date(start_datetime)} - #{formatted_end_date}"
    end
  end

  def build_onetime_string(%{
        start_specifier: :start_of_service,
        end_specifier: :custom,
        starts_today?: false,
        within_same_service_day?: true,
        start_datetime: start_datetime,
        end_datetime: end_datetime
      }) do
    "on #{datetime_to_formatted_date(start_datetime)} until #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :start_of_service,
        end_specifier: :custom,
        starts_today?: false,
        within_same_service_day?: false,
        start_datetime: start_datetime,
        end_datetime: end_datetime
      }) do
    "from #{datetime_to_formatted_date(start_datetime)} - #{datetime_to_formatted_date(end_datetime)} at #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(_), do: ""

  # time strings for recurring
  @spec build_time_string(Time.t() | nil, Time.t() | nil, atom(), atom()) :: String.t()
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

  # date strings for recurring
  @spec build_date_string(NaiveDateTime.t() | nil, NaiveDateTime.t() | nil, boolean) :: String.t()
  def build_date_string(nil, _, _), do: ""

  def build_date_string(start_datetime, end_datetime, false) do
    "from #{datetime_to_formatted_date(start_datetime)} to #{end_date_string(end_datetime, false)}"
  end

  def build_date_string(_start_datetime, end_datetime, true) do
    "until #{end_date_string(end_datetime, true)}"
  end

  defp end_date_string(nil, false), do: "until further notice"
  defp end_date_string(nil, true), do: "further notice"
  defp end_date_string(end_datetime, _), do: datetime_to_formatted_date(end_datetime)

  def happens_today?(nil, _), do: false

  def happens_today?(start_datetime, current_time) do
    # returns true if time is before next end of service
    next_end_of_service = ActivePeriod.end_of_service_datetime_naive(current_time)
    NaiveDateTime.compare(start_datetime, next_end_of_service) in [:lt]
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
  defp within_same_service_day?(nil, _), do: false
  defp within_same_service_day?(_, nil), do: false

  # returns true if start and end are part of the same service day
  defp within_same_service_day?(start_datetime, end_datetime) do
    start = start_datetime |> ActivePeriod.naive_datetime_to_service_date()
    end_ = end_datetime |> ActivePeriod.naive_datetime_to_service_date()

    # special case where start is at start of service
    starts_at_sos = NaiveDateTime.to_time(start_datetime) == ActivePeriod.start_of_service_time()
    same_date = NaiveDateTime.diff(end_datetime, start_datetime, :hour) <= 24

    Date.compare(start, end_) === :eq || (starts_at_sos && same_date)
  end

  defp within_same_calendar_day?(nil, _), do: false
  defp within_same_calendar_day?(_, nil), do: false

  defp within_same_calendar_day?(start_datetime, end_datetime) do
    NaiveDateTime.to_date(start_datetime) == NaiveDateTime.to_date(end_datetime)
  end

  # changes start specifier to "start of service" if the time is the at the start of service
  defp change_start_specifier(nil, start_specifier), do: start_specifier
  defp change_start_specifier(_, :start_of_service), do: :start_of_service

  defp change_start_specifier(%NaiveDateTime{} = start_datetime, start_specifier) do
    if NaiveDateTime.to_time(start_datetime) == ActivePeriod.start_of_service_time() do
      :start_of_service
    else
      start_specifier
    end
  end

  defp change_start_specifier(%Time{} = start_time, start_specifier) do
    if start_time == ActivePeriod.start_of_service_time() do
      :start_of_service
    else
      start_specifier
    end
  end

  # changes end specifier to "end of service" if specifier is custom and the time is the at the end of service
  defp change_end_specifier(%NaiveDateTime{} = end_datetime, :custom) do
    if Time.compare(NaiveDateTime.to_time(end_datetime), ActivePeriod.end_of_service_time()) ==
         :eq do
      :end_of_service
    else
      :custom
    end
  end

  defp change_end_specifier(_, end_specifier), do: end_specifier

  defp datetime_to_formatted_time(datetime) do
    datetime |> NaiveDateTime.to_time() |> format_time
  end

  defp format_time(time) do
    Calendar.strftime(time, "%-I:%M %p")
  end

  defp datetime_to_formatted_date(datetime) do
    datetime |> NaiveDateTime.to_date() |> format_date
  end

  defp format_date(date) do
    Calendar.strftime(date, "%a, %b %-d")
  end
end
