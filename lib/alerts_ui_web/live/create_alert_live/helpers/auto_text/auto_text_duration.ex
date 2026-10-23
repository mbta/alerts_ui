defmodule AlertsUIWeb.CreateAlertLive.Helpers.AutoText.AutoTextDuration do
  @moduledoc """
    Durations for auto text.
    All datetimes are naive and in EST.
  """
  alias AlertsUI.Models.ActivePeriod
  alias AlertsUIWeb.CreateAlertLive.Helpers.AutoText.BuildAutoText
  alias AlertsUIWeb.FormComponents.Helpers.DateTimeHelpers
  alias AlertsUIWeb.CreateAlertLive.Helpers.GetKeyForModeEffect

  @spec build_duration_text(BuildAutoText.t()) :: String.t()
  @spec build_duration_text(BuildAutoText.t(), NaiveDateTime.t() | nil) :: String.t()
  def build_duration_text(autotext_data, current_time \\ nil)

  def build_duration_text(autotext_data, nil) do
    ct = Map.get(autotext_data, :current_time) || DateTimeHelpers.current_time()
    build_duration_text(autotext_data, ct)
  end

  def build_duration_text(
        # duration text for alerts with 1 active period
        %{
          alert_timing: :"one-time",
          start_specifier: start_specifier,
          end_specifier: end_specifier,
          start_datetime: start_datetime,
          end_datetime: end_datetime,
          route_type: route_type,
          effect_name: effect_name
        } = autotext,
        current_time
      ) do
    combination = GetKeyForModeEffect.get_value_of_key(:combination, route_type, effect_name)
    is_trip_combination? = combination in [:RDT, :RDTS]
    schedules = Map.get(autotext, :schedules)
    has_trips? = is_list(schedules) && schedules != []

    start_specifier = change_start_specifier(start_datetime, start_specifier)
    end_specifier = change_end_specifier(end_datetime, end_specifier)

    starts_today? = starts_today?(start_datetime, current_time)
    starts_before_today? = starts_before_today?(start_datetime, current_time)

    ends_today? = ends_today?(end_datetime, current_time)

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
      starts_before_today?: starts_before_today?,
      ends_today?: ends_today?,
      within_same_service_day?: within_same_service_day?,
      within_same_calendar_day?: within_same_calendar_day?,
      is_trip_combination?: is_trip_combination?,
      has_trips?: has_trips?
    })
  end

  def build_duration_text(
        # duration text for alerts with more than 1 active period
        %{
          alert_timing: :recurring,
          start_time_specifier: start_time_specifier,
          end_time_specifier: end_time_specifier,
          start_date: start_date,
          end_date: end_date,
          start_time: start_time,
          end_time: end_time,
          recurrence_days: recurrence_days,
          route_type: route_type,
          effect_name: effect_name
        } = auto_text_data,
        current_time
      ) do
    combination = GetKeyForModeEffect.get_value_of_key(:combination, route_type, effect_name)

    start_time_specifier = change_start_specifier(start_time, start_time_specifier)
    end_time_specifier = change_end_specifier(end_time, end_time_specifier)

    start_datetime = build_datetime(start_date, start_time)
    end_datetime = build_datetime(end_date, end_time)

    lasts_a_single_day? = within_same_service_day?(start_datetime, end_datetime)

    starts_today_or_earlier? =
      starts_today?(start_datetime, current_time) or
        starts_before_today?(start_datetime, current_time)

    ends_today? = starts_today?(end_datetime, current_time)

    duration_data = %{
      is_trip_combination?: combination in [:RDT, :RDTS],
      starts_today_or_earlier?: starts_today_or_earlier?,
      start_time: start_time,
      end_time: end_time,
      start_time_specifier: change_start_specifier(start_time, start_time_specifier),
      end_time_specifier: change_end_specifier(end_time, end_time_specifier),
      start_datetime: build_datetime(start_date, start_time),
      end_datetime: build_datetime(end_date, end_time)
    }

    # if the alert lasts a single day or ends today, it is treated like a one-time alert.
    if lasts_a_single_day? or ends_today? do
      auto_text_data
      |> Map.merge(%{
        alert_timing: :"one-time",
        start_datetime: start_datetime,
        end_datetime: end_datetime
      })
      |> build_duration_text(current_time)
    else
      date_string = build_date_string(duration_data)
      weekday_string = build_weekday_string(recurrence_days)

      time_string =
        build_time_string(duration_data)

      "#{date_string} every #{weekday_string} #{time_string}"
    end
  end

  def build_duration_text(_, _), do: ""

  # output string for one-time

  # # trip specific

  def build_onetime_string(%{
        is_trip_combination?: true,
        starts_today?: false,
        starts_before_today?: false,
        within_same_service_day?: false,
        start_datetime: start_datetime,
        end_datetime: end_datetime
      })
      when not is_nil(end_datetime) do
    "from #{datetime_to_formatted_date(start_datetime)} through #{datetime_to_formatted_date(end_datetime)}"
  end

  def build_onetime_string(%{
        is_trip_combination?: true,
        starts_today?: false,
        starts_before_today?: false,
        within_same_service_day?: true,
        start_datetime: start_datetime
      }) do
    "on #{datetime_to_formatted_date(start_datetime)}"
  end

  def build_onetime_string(%{
        is_trip_combination?: true,
        starts_before_today?: true,
        ends_today?: true
      }) do
    "today"
  end

  def build_onetime_string(%{
        is_trip_combination?: true,
        within_same_service_day?: false,
        end_datetime: end_datetime
      })
      when not is_nil(end_datetime) do
    "today through #{datetime_to_formatted_date(end_datetime)}"
  end

  def build_onetime_string(%{
        is_trip_combination?: true,
        has_trips?: false,
        within_same_service_day?: true,
        starts_today?: true,
        end_specifier: :later_today
      }) do
    "today"
  end

  def build_onetime_string(%{
        is_trip_combination?: true,
        has_trips?: false,
        within_same_service_day?: true,
        starts_today?: true,
        end_specifier: :custom,
        end_datetime: end_datetime
      })
      when not is_nil(end_datetime) do
    "until #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(%{
        is_trip_combination?: true,
        within_same_service_day?: true,
        starts_today?: true,
        end_datetime: end_datetime
      })
      when not is_nil(end_datetime) do
    "today"
  end

  def build_onetime_string(%{
        is_trip_combination?: true
      }) do
    ""
  end

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
    formatted_end = service_date_to_formatted_date(end_datetime)
    "through #{formatted_end}"
  end

  def build_onetime_string(%{
        start_specifier: :now,
        end_specifier: :custom,
        within_same_service_day?: false,
        end_datetime: end_datetime
      }) do
    "until #{datetime_to_formatted_date(end_datetime)} at #{datetime_to_formatted_time(end_datetime)}"
  end

  # # start of "custom" on past day
  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :end_of_service,
        starts_before_today?: true,
        ends_today?: false,
        end_datetime: end_datetime
      }) do
    formatted_end = service_date_to_formatted_date(end_datetime)
    "through #{formatted_end}"
  end

  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :custom,
        starts_before_today?: true,
        ends_today?: false,
        end_datetime: end_datetime
      }) do
    "until #{datetime_to_formatted_date(end_datetime)} at #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :custom,
        starts_before_today?: true,
        ends_today?: true,
        end_datetime: end_datetime
      }) do
    "until #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :end_of_service,
        starts_before_today?: true,
        ends_today?: true
      }) do
    "today"
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
    formatted_end = service_date_to_formatted_date(end_datetime)
    "from #{datetime_to_formatted_time(start_datetime)} today through #{formatted_end}"
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
    "from #{datetime_to_formatted_date(start_datetime)} at #{datetime_to_formatted_time(start_datetime)} to #{datetime_to_formatted_date(end_datetime)} at #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :custom,
        end_specifier: :end_of_service,
        starts_today?: false,
        within_same_service_day?: false,
        start_datetime: start_datetime,
        end_datetime: end_datetime
      }) do
    formatted_end_date = service_date_to_formatted_date(end_datetime)

    "from #{datetime_to_formatted_date(start_datetime)} at #{datetime_to_formatted_time(start_datetime)} through #{formatted_end_date}"
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
    "from #{datetime_to_formatted_date(start_datetime)} at #{datetime_to_formatted_time(start_datetime)} to #{datetime_to_formatted_date(end_datetime)} at #{datetime_to_formatted_time(end_datetime)}"
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

  # # start of "start of service" on past day
  def build_onetime_string(%{
        start_specifier: :start_of_service,
        end_specifier: :custom,
        starts_before_today?: true,
        ends_today?: false,
        end_datetime: end_datetime
      }) do
    "until #{datetime_to_formatted_date(end_datetime)} at #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :start_of_service,
        end_specifier: :custom,
        starts_before_today?: true,
        ends_today?: true,
        end_datetime: end_datetime
      }) do
    "until #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(%{
        start_specifier: :start_of_service,
        end_specifier: :end_of_service,
        starts_before_today?: true,
        within_same_service_day?: false,
        ends_today?: true
      }) do
    "today"
  end

  def build_onetime_string(%{
        start_specifier: :start_of_service,
        end_specifier: :end_of_service,
        starts_before_today?: true,
        ends_today?: false,
        end_datetime: end_datetime
      }) do
    formatted_end = service_date_to_formatted_date(end_datetime)
    "through #{formatted_end}"
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
    start_weekday =
      if is_nil(start_datetime) do
        ""
      else
        start_datetime |> NaiveDateTime.to_date() |> Calendar.strftime("%A")
      end

    end_weekday =
      if is_nil(end_datetime) do
        ""
      else
        end_datetime |> ActivePeriod.datetime_to_service_date() |> Calendar.strftime("%A")
      end

    formatted_end_date = service_date_to_formatted_date(end_datetime)

    if {start_weekday, end_weekday} == {"Saturday", "Sunday"} do
      "the weekend of #{datetime_to_formatted_date(start_datetime)} and #{formatted_end_date}"
    else
      "from #{datetime_to_formatted_date(start_datetime)} through #{formatted_end_date}"
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
    "from #{datetime_to_formatted_date(start_datetime)} to #{datetime_to_formatted_date(end_datetime)} at #{datetime_to_formatted_time(end_datetime)}"
  end

  def build_onetime_string(_), do: ""

  @spec build_time_string(map()) :: String.t()

  def build_time_string(%{
        is_trip_combination?: true
      }),
      do: ""

  def build_time_string(%{
        end_time: nil,
        start_time_specifier: :start_of_service,
        end_time_specifier: :custom
      }),
      do: "from start of service"

  def build_time_string(%{
        end_time: end_time,
        start_time_specifier: :start_of_service,
        end_time_specifier: :custom
      }) do
    "from start of service to #{format_time(end_time)}"
  end

  def build_time_string(%{
        start_time: start_time,
        start_time_specifier: :custom,
        end_time_specifier: :end_of_service
      })
      when not is_nil(start_time) do
    "from #{format_time(start_time)} to end of service"
  end

  def build_time_string(%{
        end_time: nil,
        start_time_specifier: :custom,
        end_time_specifier: :custom
      }),
      do: ""

  def build_time_string(%{
        start_time: start_time,
        end_time: end_time,
        start_time_specifier: :custom,
        end_time_specifier: :custom
      })
      when not is_nil(start_time) do
    "from #{format_time(start_time)} to #{format_time(end_time)}"
  end

  def build_time_string(_), do: ""

  # date strings for recurring

  @spec build_date_string(map()) :: String.t()
  def build_date_string(%{start_datetime: nil}), do: ""

  def build_date_string(%{
        start_datetime: start_datetime,
        end_datetime: nil,
        starts_today_or_earlier?: false,
        is_trip_combination?: true
      }) do
    "starting #{datetime_to_formatted_date(start_datetime)}"
  end

  def build_date_string(%{
        end_datetime: nil,
        starts_today_or_earlier?: true,
        is_trip_combination?: true
      }) do
    "until further notice"
  end

  def build_date_string(%{
        start_datetime: start_datetime,
        end_datetime: nil,
        starts_today_or_earlier?: false
      }) do
    "starting #{datetime_to_formatted_date(start_datetime)} #{end_date_string_word(nil)} #{end_date_string(nil)}"
  end

  def build_date_string(%{
        start_datetime: start_datetime,
        end_datetime: end_datetime,
        starts_today_or_earlier?: false
      }) do
    "from #{datetime_to_formatted_date(start_datetime)} #{end_date_string_word(end_datetime)} #{end_date_string(end_datetime)}"
  end

  def build_date_string(%{
        end_datetime: end_datetime,
        starts_today_or_earlier?: true
      }) do
    "until #{end_date_string(end_datetime)}"
  end

  defp end_date_string_word(nil), do: "until"
  defp end_date_string_word(_), do: "to"
  defp end_date_string(nil), do: "further notice"
  defp end_date_string(end_datetime), do: datetime_to_formatted_date(end_datetime)

  def starts_today?(nil, _), do: false

  def starts_today?(start_datetime, current_time) do
    # returns true if time is before next end of service
    # and at or after previous beginning of service
    next_end_of_service = ActivePeriod.end_of_service_datetime_naive(current_time)
    previous_beginning_of_service = ActivePeriod.start_of_current_service_day(current_time)
    before_eos = NaiveDateTime.compare(start_datetime, next_end_of_service) in [:lt]
    after_bos = NaiveDateTime.compare(start_datetime, previous_beginning_of_service) in [:gt, :eq]

    before_eos and after_bos
  end

  def ends_today?(nil, _), do: false

  def ends_today?(end_datetime, current_time) do
    # returns true if time is at or before next end of service
    # and after previous beginning of service
    next_end_of_service = ActivePeriod.end_of_service_datetime_naive(current_time)
    previous_beginning_of_service = ActivePeriod.start_of_current_service_day(current_time)
    before_eos = NaiveDateTime.compare(end_datetime, next_end_of_service) in [:lt, :eq]
    after_bos = NaiveDateTime.compare(end_datetime, previous_beginning_of_service) in [:gt]

    before_eos and after_bos
  end

  def starts_before_today?(nil, _), do: false

  def starts_before_today?(start_datetime, current_time) do
    starts_today? = starts_today?(start_datetime, current_time)

    starts_in_past? = NaiveDateTime.compare(start_datetime, current_time) == :lt

    starts_in_past? && !starts_today?
  end

  defp build_datetime(nil, _), do: nil
  defp build_datetime(_, nil), do: nil

  defp build_datetime(date, time) do
    NaiveDateTime.new!(date, time)
  end

  # weekdays for recurring
  def build_weekday_string([]), do: ""

  def build_weekday_string([_, _, _, _, _, _, _]) do
    "day"
  end

  def build_weekday_string(recurrence_days) do
    days_string =
      recurrence_days
      |> Enum.map(fn weekday ->
        Atom.to_string(weekday)
        |> String.capitalize()
      end)
      |> BuildAutoText.join_together()

    "#{days_string}"
  end

  # helpers
  defp within_same_service_day?(nil, _), do: false
  defp within_same_service_day?(_, nil), do: false

  # returns true if start and end are part of the same service day
  defp within_same_service_day?(start_datetime, end_datetime) do
    start = start_datetime |> ActivePeriod.datetime_to_service_date()
    end_ = end_datetime |> ActivePeriod.datetime_to_service_date()

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

  defp service_date_to_formatted_date(nil) do
    ""
  end

  defp service_date_to_formatted_date(datetime) do
    datetime |> ActivePeriod.datetime_to_service_date() |> format_date
  end

  defp datetime_to_formatted_time(datetime) do
    datetime |> NaiveDateTime.to_time() |> format_time
  end

  defp format_time(time) do
    Calendar.strftime(time, "%-I:%M %p")
  end

  defp datetime_to_formatted_date(nil), do: ""

  defp datetime_to_formatted_date(datetime) do
    datetime |> NaiveDateTime.to_date() |> format_date
  end

  defp format_date(date) do
    Calendar.strftime(date, "%a, %b %-d")
  end
end
