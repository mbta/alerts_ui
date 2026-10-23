defmodule AlertsUIWeb.FormComponents.Helpers.DateTimeFormatters do
  @moduledoc """
  Utility functions for formatting dates and times.
  """

  # TODO general helper

  alias AlertsUI.Helpers.DateTime, as: DTHelpers
  alias AlertsUI.Models.ActivePeriod
  alias AlertsUIWeb.FormComponents.Helpers.DateTimeHelpers

  @one_minute_in_seconds 60
  @one_hour_in_seconds @one_minute_in_seconds * 60

  @doc """
  Return a human-friendly date-time string relative to "now".
  Use the time (converted to EST) if today (same SERVICE day), the month and day if this year, and the month, day and
  year if a different year.

  Pass `:start` as the second argument if it's a start time, and `:end` if it's an end time. The difference is that
  `:start` does not count the next instance of 3AM (EOS) as the same service day, but `:end` does.

  iex> friendly_date_time(~U[2025-07-03 06:02:00.00Z], :start, ~U[2025-07-02 16:21:52.928497Z])
  "2:02 AM"
  iex> friendly_date_time(~U[2022-01-12 01:01:00.00Z], :start, ~U[2022-01-12 15:02:00.00Z])
  "Jan 11"
  iex> friendly_date_time(~U[2022-01-12 14:01:00.00Z], :start, ~U[2022-01-12 15:02:00.00Z])
  "9:01 AM"
  iex> friendly_date_time(~U[2022-01-12 14:01:00.00Z], :start, ~U[2022-01-13 06:02:00.00Z])
  "9:01 AM"
  iex> friendly_date_time(~U[2022-01-12 08:00:00.00Z], :end, ~U[2022-01-11 12:02:00.00Z])
  "3:00 AM"
  iex> friendly_date_time(~U[2022-01-12 08:00:00.00Z], :start, ~U[2022-01-11 12:02:00.00Z])
  "Jan 12"
  iex> friendly_date_time(~U[2022-01-12 14:01:00.00Z], :start, ~U[2022-01-13 08:02:00.00Z])
  "Jan 12"
  iex> friendly_date_time(~U[2022-01-07 14:01:00.00Z], :start, ~U[2022-01-12 15:02:00.00Z])
  "Jan 7"
  iex> friendly_date_time(~U[2021-12-07 14:01:00.00Z], :start, ~U[2022-01-12 15:02:00.00Z])
  "Dec 7, 2021"
  iex> friendly_date_time("2020-01-13T17:32:00Z", :start, ~U[2022-01-12 15:02:00.00Z])
  "Jan 13, 2020"
  iex> friendly_date_time(nil, :start, ~U[2022-01-12 15:02:00.00Z])
  ""
  """
  @spec friendly_date_time(DateTime.t() | String.t() | nil, :start | :end) :: String.t()
  @spec friendly_date_time(DateTime.t() | String.t() | nil, :start | :end, DateTime.t()) ::
          String.t()
  def friendly_date_time(dt, start_or_end, now \\ DateTime.now!("America/New_York"))

  def friendly_date_time(nil, _, _now), do: ""

  def friendly_date_time(dt, start_or_end, now) when is_binary(dt) do
    {:ok, dt, 0} = DateTime.from_iso8601(dt)
    friendly_date_time(dt, start_or_end, now)
  end

  def friendly_date_time(%DateTime{} = dt, start_or_end, now) do
    dt = DateTime.shift_zone!(dt, "America/New_York")
    # get format using un-shifted date
    format = date_time_format(dt, start_or_end, now)

    # shift to service date
    new_date =
      if start_or_end == :start do
        ActivePeriod.datetime_to_service_date_exclusive(dt)
      else
        ActivePeriod.datetime_to_service_date(dt)
      end

    service_shifted_dt =
      DTHelpers.protect_dst_gap!(new_date, DateTime.to_time(dt), "America/New_York")

    Calendar.strftime(service_shifted_dt, format)
  end

  @doc """
  Return a human-friendly time string relative to "now".
  iex> friendly_time(~U[2022-01-07 14:01:00.00Z])
  "9:01 AM"
  iex> friendly_time(nil)
  ""
  """
  @spec friendly_time(DateTime.t() | nil) :: String.t()
  def friendly_time(nil), do: ""

  def friendly_time(%DateTime{} = dt) do
    dt
    |> DateTime.shift_zone!("America/New_York")
    |> Calendar.strftime("%-I:%M %p")
  end

  @doc """
  Return a human-friendly time duration string. Display in hours, rounded down,
  if greater than 1 hour, otherwise in minutes rounded down.

  iex> friendly_duration(7400)
  "2 hours"
  iex> friendly_duration(120)
  "2 minutes"
  iex> friendly_duration(5400)
  "1 hour"
  iex> friendly_duration(70)
  "1 minute"
  """
  @spec friendly_duration(integer()) :: String.t()
  def friendly_duration(time_in_secs)
      when time_in_secs >= @one_hour_in_seconds and time_in_secs < 2 * @one_hour_in_seconds,
      do: "1 hour"

  def friendly_duration(time_in_secs) when time_in_secs >= @one_hour_in_seconds,
    do: "#{floor(time_in_secs / @one_hour_in_seconds)} hours"

  def friendly_duration(time_in_secs)
      when time_in_secs >= @one_minute_in_seconds and time_in_secs < 2 * @one_minute_in_seconds,
      do: "1 minute"

  def friendly_duration(time_in_secs),
    do: "#{floor(time_in_secs / @one_minute_in_seconds)} minutes"

  @doc """
  Put a UTC timestamp in local time and display the month/day/year with hh:mm AM/PM.

  iex> timestamp_date_time(~U[2022-01-07 14:01:00.00Z])
  "Jan 7, 2022, 9:01 AM"
  iex> timestamp_date_time(nil)
  nil
  """
  @spec timestamp_date_time(DateTime.t() | nil) :: String.t()
  def timestamp_date_time(%DateTime{} = utc_timestamp) do
    utc_timestamp
    |> DateTime.shift_zone!("America/New_York")
    |> Calendar.strftime("%b %-d, %Y, %-I:%M %p")
  end

  def timestamp_date_time(nil), do: nil

  @doc """
  Change seconds into minutes, rounded to an integer

  iex> seconds_to_minutes(nil)
  nil
  iex> seconds_to_minutes(2)
  0
  iex> seconds_to_minutes(35)
  1
  iex> seconds_to_minutes(65)
  1
  iex> seconds_to_minutes(115)
  2
  """
  @spec seconds_to_minutes(number() | nil) :: integer() | nil
  def seconds_to_minutes(nil), do: nil

  def seconds_to_minutes(seconds) do
    round(seconds / 60)
  end

  @spec date_time_format(DateTime.t(), :start | :end, DateTime.t()) :: String.t()
  defp date_time_format(dt, start_or_end, now) do
    cond do
      # same service day
      DateTimeHelpers.same_service_date?(dt, start_or_end, now) ->
        "%-I:%M %p"

      # same year
      dt.year == now.year ->
        "%b %-d"

      # different year
      true ->
        "%b %-d, %Y"
    end
  end
end
