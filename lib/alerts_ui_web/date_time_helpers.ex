defmodule AlertsViewerWeb.DateTimeHelpers do
  @moduledoc """
  Utility functions for formatting dates and times.
  """

  @one_minute_in_seconds 60
  @one_hour_in_seconds @one_minute_in_seconds * 60

  @doc """
  Return a human-friendly date-time string relative to "now".
  Use the time (converted to EST) if today, the month and day if this year, and the month and
  year if a different year.

  iex> friendly_date_time(~U[2022-01-12 14:01:00.00Z], ~U[2022-01-12 15:02:00.00Z])
  "9:01 AM"
  iex> friendly_date_time(~U[2022-01-07 14:01:00.00Z], ~U[2022-01-12 15:02:00.00Z])
  "Jan 7"
  iex> friendly_date_time(~U[2021-12-07 14:01:00.00Z], ~U[2022-01-12 15:02:00.00Z])
  "Dec 2021"
  iex> friendly_date_time(nil, ~U[2022-01-12 15:02:00.00Z])
  ""
  """
  @spec friendly_date_time(DateTime.t() | nil) :: String.t()
  @spec friendly_date_time(DateTime.t() | nil, DateTime.t()) :: String.t()
  def friendly_date_time(dt, now \\ DateTime.now!("America/New_York"))

  def friendly_date_time(nil, _now), do: ""

  def friendly_date_time(dt, now) do
    format = date_time_format(dt, now)
    Calendar.strftime(DateTime.shift_zone!(dt, "America/New_York"), format)
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

  @spec date_time_format(DateTime.t(), DateTime.t()) :: String.t()
  defp date_time_format(dt, now) when dt.day == now.day, do: "%-I:%M %p"
  defp date_time_format(dt, now) when dt.year == now.year, do: "%b %-d"
  defp date_time_format(_, _), do: "%b %Y"
end
