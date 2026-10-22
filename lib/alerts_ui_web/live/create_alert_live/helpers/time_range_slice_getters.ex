defmodule AlertsUIWeb.CreateAlertLive.Helpers.TimeRangeSliceGetters do
  @moduledoc """
  Functions to calculate what times/dates/datetimes should be set when a user
  selects things in the TimeRange component
  """
  alias AlertsUI.Helpers.DateTime, as: DTHelpers
  alias AlertsUI.Models.ActivePeriod

  # one-time start

  def get_onetime_start_date(nil), do: nil
  def get_onetime_start_date(start_datetime), do: NaiveDateTime.to_date(start_datetime)

  def get_onetime_start_datetime(
        %{
          active_period_start_specifier: active_period_start_specifier,
          active_period_start_date: active_period_start_date,
          active_period_start: active_period_start
        },
        current_time,
        previous_state
      ) do
    case active_period_start_specifier do
      :now ->
        current_time

      :start_of_service ->
        if is_nil(active_period_start_date) do
          current_time
        else
          safe_new_datetime(active_period_start_date, ActivePeriod.start_of_service_time())
        end

      :custom ->
        cond do
          previous_state == :now ->
            current_time

          previous_state == :start_of_service ->
            safe_new_datetime(active_period_start_date, ActivePeriod.start_of_service_time())

          true ->
            active_period_start
        end
    end
  end

  defp safe_new_datetime(%Date{} = date, %Time{} = time) do
    NaiveDateTime.new!(date, time)
  end

  defp safe_new_datetime(_, _), do: nil

  # recurring start

  def get_recurring_start_time(
        %{
          active_period_start_time_specifier: active_period_start_time_specifier,
          active_period_start_time: active_period_start_time
        },
        current_time,
        previous_state
      ) do
    case active_period_start_time_specifier do
      :start_of_service ->
        ActivePeriod.start_of_service_time()

      :custom ->
        if previous_state !== :custom do
          current_time |> NaiveDateTime.to_time()
        else
          active_period_start_time
        end
    end
  end

  def get_recurring_start_date(
        %{
          active_period_start_specifier: active_period_start_specifier,
          active_period_start_date: active_period_start_date
        },
        current_time,
        previous_state
      ) do
    case active_period_start_specifier do
      :now ->
        current_time |> NaiveDateTime.to_date()

      :custom ->
        if previous_state !== :custom do
          current_time |> NaiveDateTime.to_date()
        else
          active_period_start_date
        end

      _ ->
        active_period_start_date
    end
  end

  def get_recurring_start_datetime(nil, _), do: nil
  def get_recurring_start_datetime(_, nil), do: nil

  def get_recurring_start_datetime(start_date, start_time) do
    start_date
    |> DTHelpers.round_up_to_gap!(start_time, "America/New_York")
    |> DateTime.to_naive()
  end

  # one-time end

  def get_onetime_end_date(nil), do: nil

  def get_onetime_end_date(end_datetime) do
    end_date = NaiveDateTime.to_date(end_datetime)
    end_time = NaiveDateTime.to_time(end_datetime)

    time_before_end_of_service? =
      Time.compare(end_time, ActivePeriod.end_of_service_time()) in [:lt, :eq]

    # date should be previous day IF previously set time was between midnight and end-of-service
    day_to_add =
      if time_before_end_of_service? do
        -1
      else
        0
      end

    Date.add(end_date, day_to_add)
  end

  def get_onetime_end_datetime(
        %{active_period_end_specifier: :later_today},
        current_time,
        _previous_state
      ) do
    current_time
    |> ActivePeriod.end_of_service_datetime_naive()
  end

  def get_onetime_end_datetime(
        %{
          active_period_end_specifier: :end_of_service,
          active_period_end_date: active_period_end_date
        },
        _current_time,
        _previous_state
      )
      when active_period_end_date in ["", nil] do
    nil
  end

  def get_onetime_end_datetime(
        %{
          active_period_end_specifier: :end_of_service,
          active_period_end_date: active_period_end_date
        },
        _current_time,
        _previous_state
      ) do
    # The provided end date should always result in the end of service for that day
    # (ie the next morning)

    active_period_end_date
    |> Date.add(1)
    |> NaiveDateTime.new!(ActivePeriod.end_of_service_time())
  end

  def get_onetime_end_datetime(
        %{active_period_end_specifier: :until_further_notice},
        _current_time,
        _previous_state
      ) do
    nil
  end

  def get_onetime_end_datetime(
        %{active_period_end_specifier: :when_work_order_is_closed},
        current_time,
        _previous_state
      ) do
    DateTime.new!(NaiveDateTime.to_date(current_time), ~T[23:59:59])
  end

  def get_onetime_end_datetime(
        %{
          active_period_end_specifier: :custom,
          active_period_end: active_period_end,
          active_period_end_date: active_period_end_date
        },
        current_time,
        previous_state
      ) do
    cond do
      previous_state == :until_further_notice ->
        current_time

      previous_state == :when_work_order_is_closed ->
        current_time

      # for trips
      is_nil(previous_state) ->
        active_period_end

      previous_state !== :custom ->
        safe_new_datetime(active_period_end_date, ~T[23:59:00])

      true ->
        active_period_end
    end
  end

  # recurring end

  def get_recurring_end_time(
        %{
          active_period_end_time_specifier: active_period_end_time_specifier,
          active_period_end_time: active_period_end_time
        },
        current_time,
        previous_state
      ) do
    case active_period_end_time_specifier do
      :end_of_service ->
        ActivePeriod.end_of_service_time()

      :custom ->
        if previous_state !== :custom do
          current_time |> NaiveDateTime.to_time()
        else
          active_period_end_time
        end
    end
  end

  def get_recurring_end_date(
        %{
          active_period_end_specifier: active_period_end_specifier,
          active_period_end_date: active_period_end_date
        },
        current_time,
        previous_state
      ) do
    case active_period_end_specifier do
      :custom ->
        if previous_state !== :custom do
          current_time
          |> NaiveDateTime.to_date()
        else
          active_period_end_date
        end

      :until_further_notice ->
        nil

      :when_work_order_is_closed ->
        nil

      _ ->
        active_period_end_date
    end
  end

  def get_recurring_end_datetime(nil, _), do: nil
  def get_recurring_end_datetime(_, nil), do: nil

  def get_recurring_end_datetime(end_date, end_time) do
    if Time.compare(end_time, ActivePeriod.start_of_service_time()) == :lt do
      end_date
      |> DTHelpers.round_up_to_gap!(end_time, "America/New_York")
      |> DateTime.to_naive()
    else
      end_date
      |> DTHelpers.round_up_to_gap!(end_time, "America/New_York")
      |> DateTime.add(1, :day)
      |> DateTime.to_naive()
    end
  end
end
