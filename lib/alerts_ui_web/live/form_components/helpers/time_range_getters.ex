defmodule AlertsUIWeb.FormComponents.Helpers.TimeRangeGetters do
  @moduledoc """
    Helpers for fetching the proper date/time/datetimes from the time_range form
  """
  alias AlertsUI.Helpers.DateTime, as: DTHelpers
  alias AlertsUI.Models.ActivePeriod
  alias AlertsUIWeb.FormComponents.Helpers.DateTimeHelpers

  # The DateTime getters execute directly on the time_range from the form
  def get_onetime_start_datetime(time_range, current_time, previous_state) do
    case time_range["active_period_start_specifier"] do
      "now" ->
        current_time |> DateTimeHelpers.naive_datetime_to_iso8601()

      "start_of_service" ->
        {validity, date} = Date.from_iso8601(time_range["active_period_start_date"])

        if validity === :ok do
          NaiveDateTime.new!(date, ActivePeriod.start_of_service_time())
        else
          current_time
        end
        |> DateTimeHelpers.naive_datetime_to_iso8601()

      "custom" ->
        cond do
          previous_state == "now" ->
            current_time |> DateTimeHelpers.naive_datetime_to_iso8601()

          previous_state == "start_of_service" ->
            time_range["active_period_start_date"]
            |> Date.from_iso8601!()
            |> NaiveDateTime.new!(ActivePeriod.start_of_service_time())
            |> DateTimeHelpers.naive_datetime_to_iso8601()

          true ->
            time_range["active_period_start"]
        end
    end
  end

  def get_onetime_end_datetime(time_range, current_time, previous_state) do
    case time_range["active_period_end_specifier"] do
      "later_today" ->
        current_time
        |> ActivePeriod.end_of_service_datetime_naive()
        |> DateTimeHelpers.naive_datetime_to_iso8601()

      "end_of_service" ->
        if time_range["active_period_end_date"] in ["", nil] do
          ""
        else
          # The provided end date should always result in the end of service for that day
          # (ie the next morning)
          time_range["active_period_end_date"]
          |> Date.from_iso8601!()
          |> Date.add(1)
          |> NaiveDateTime.new!(ActivePeriod.end_of_service_time())
          |> DateTimeHelpers.naive_datetime_to_iso8601()
        end

      "until_further_notice" ->
        ""

      "custom" ->
        cond do
          previous_state == "until_further_notice" ->
            current_time |> DateTimeHelpers.naive_datetime_to_iso8601()

          previous_state !== "custom" ->
            time_range["active_period_end_date"]
            |> Date.from_iso8601!()
            |> NaiveDateTime.new!(~T[23:59:00])
            |> DateTimeHelpers.naive_datetime_to_iso8601()

          true ->
            time_range["active_period_end"]
        end
    end
  end

  # The Date / Time getters execute on the output from the DateTime getters
  def get_onetime_start_date(nil), do: ""
  def get_onetime_start_date(start_datetime), do: NaiveDateTime.to_date(start_datetime)

  def get_onetime_end_date(nil), do: ""

  def get_onetime_end_date(end_datetime) do
    end_date = NaiveDateTime.to_date(end_datetime)

    end_time = NaiveDateTime.to_time(end_datetime)

    if Time.compare(end_time, ActivePeriod.start_of_service_time()) == :eq do
      Date.add(end_date, -1)
    else
      end_date
    end
  end

  # The Date / Time getters execute directly on the time_range from the form
  def get_recurring_start_time(time_range, current_time, previous_state) do
    case time_range["active_period_start_time_specifier"] do
      :start_of_service ->
        ActivePeriod.start_of_service_time()

      "start_of_service" ->
        ActivePeriod.start_of_service_time()

      "custom" ->
        if previous_state !== "custom" do
          current_time |> NaiveDateTime.to_time() |> DateTimeHelpers.time_to_iso8601()
        else
          time_range["active_period_start_time"]
        end
    end
  end

  def get_recurring_end_time(time_range, current_time, previous_state) do
    case time_range["active_period_end_time_specifier"] do
      :end_of_service ->
        ActivePeriod.end_of_service_time()

      "end_of_service" ->
        ActivePeriod.end_of_service_time()

      "custom" ->
        if previous_state !== "custom" do
          current_time |> NaiveDateTime.to_time() |> DateTimeHelpers.time_to_iso8601()
        else
          time_range["active_period_end_time"]
        end
    end
  end

  def get_recurring_start_date(time_range, current_time, previous_state) do
    case time_range["active_period_start_specifier"] do
      "now" ->
        current_time |> NaiveDateTime.to_date()

      "custom" ->
        if previous_state !== "custom" do
          current_time |> NaiveDateTime.to_date()
        else
          time_range["active_period_start_date"]
        end

      _ ->
        time_range["active_period_start_date"]
    end
  end

  def get_recurring_end_date(time_range, current_time, previous_state) do
    case time_range["active_period_end_specifier"] do
      "custom" ->
        if previous_state !== "custom" do
          current_time
          |> NaiveDateTime.to_date()
        else
          time_range["active_period_end_date"]
        end

      "until_further_notice" ->
        ""

      _ ->
        time_range["active_period_end_date"]
    end
  end

  # The DateTime getters execute on output from the Date / Time getters
  def get_recurring_start_datetime("", _), do: ""
  def get_recurring_start_datetime(_, ""), do: ""

  def get_recurring_start_datetime(start_date, start_time) do
    start_date
    |> string_to_date_helper()
    |> DTHelpers.new_round_up_to_gap!(string_to_time_helper(start_time), "America/New_York")
  end

  def get_recurring_end_datetime("", _), do: ""
  def get_recurring_end_datetime(_, ""), do: ""

  def get_recurring_end_datetime(end_date, end_time) do
    end_time = string_to_time_helper(end_time)

    if Time.compare(end_time, ActivePeriod.start_of_service_time()) == :lt do
      end_date
      |> string_to_date_helper()
      |> DTHelpers.new_round_up_to_gap!(end_time, "America/New_York")
    else
      end_date
      |> string_to_date_helper()
      |> DTHelpers.new_round_up_to_gap!(end_time, "America/New_York")
      |> DateTime.add(1, :day)
    end
  end

  # Date/time/datetime conversion helpers
  defp string_to_date_helper(date) when is_binary(date), do: Date.from_iso8601!(date)
  defp string_to_date_helper(date), do: date

  defp string_to_time_helper(time) when is_binary(time) do
    case Time.from_iso8601(time <> ":00") do
      {:ok, time} -> time
      {:error, _} -> nil
    end
  end

  defp string_to_time_helper(time), do: time

  def string_to_datetime_helper(%DateTime{} = datetime),
    do: DateTime.to_naive(datetime)

  def string_to_datetime_helper(%NaiveDateTime{} = datetime), do: datetime

  def string_to_datetime_helper(datetime) when is_binary(datetime) do
    # At this stage, we see string dates in the following formats:
    # 2025-12-13T03:00
    # 2025-12-13T03:00:00
    # s (an invalid entry)
    case NaiveDateTime.from_iso8601((datetime <> ":00:00") |> String.slice(0..18)) do
      {:ok, start_datetime} -> start_datetime
      {:error, _} -> nil
    end
  end
end
