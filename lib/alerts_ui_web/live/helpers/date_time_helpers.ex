defmodule AlertsUIWeb.Helpers.DateTimeHelpers do
  @moduledoc """
  Utility functions for manipulating / interpreting dates and times.
  """

  alias AlertsUI.ActivePeriodBuilder
  alias AlertsUI.Models.ActivePeriod

  def current_time,
    do:
      DateTime.now!("America/New_York") |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)

  @doc """
  Returns true if alert end is in today's service day and alert is not closed

  iex> will_be_ending_today?(DateTime.add(DateTime.now!("America/New_York"), 1, :hour), nil)
  true

  iex> will_be_ending_today?(DateTime.add(DateTime.now!("America/New_York"), 2, :day), nil)
  false

  iex> will_be_ending_today?(~U[2025-08-21 06:00:00Z], ~U[2025-08-21 06:00:00Z])
  false

  """
  @spec will_be_ending_today?(DateTime.t(), DateTime.t() | nil) :: boolean()
  def will_be_ending_today?(end_datetime, nil), do: same_service_date?(end_datetime, :end)
  def will_be_ending_today?(_end_datetime, _closed_timestamp), do: false

  @doc """
  Returns whether 2 datetimes are in the same service date
  If `:start` is passed as the second argument, it will not count the
  next instance of 3am (EOS) as the same service day, but if `:end`
  is passed, the next instance of EOS WILL count as the same service day

  Second argument defaults to now

  iex> same_service_date?(nil, :end, ~U[2025-08-20 11:00:00Z])
  false
  iex> same_service_date?(~U[2025-08-20 11:00:00Z], :end, ~U[2025-08-21 06:00:00Z])
  true
  iex> same_service_date?(~U[2025-08-20 11:00:00Z], :start, ~U[2025-08-21 06:00:00Z])
  true
  iex> same_service_date?(~U[2025-08-20 11:00:00Z], :end, ~U[2025-08-21 08:00:00Z])
  false
  iex> same_service_date?(~U[2025-08-20 11:00:00Z], :start, ~U[2025-08-21 08:00:00Z])
  false
  #end of service differences
  iex> same_service_date?(~U[2025-08-20 12:00:00Z], :start, ~U[2025-08-21 07:00:00Z])
  false
  iex> same_service_date?(~U[2025-08-20 12:00:00Z], :end, ~U[2025-08-21 07:00:00Z])
  true
  """
  @spec same_service_date?(DateTime.t() | nil, :start | :end, DateTime.t()) :: boolean()
  def same_service_date?(_, _, _ \\ DateTime.now!("Etc/UTC"))

  def same_service_date?(nil, _, _), do: false

  def same_service_date?(utc_datetime, :start, now) do
    first_service_date = ActivePeriod.datetime_to_service_date_exclusive(utc_datetime)

    second_service_date = ActivePeriod.datetime_to_service_date_exclusive(now)

    Date.compare(first_service_date, second_service_date) == :eq
  end

  def same_service_date?(utc_datetime, :end, now) do
    first_service_date = ActivePeriod.datetime_to_service_date(utc_datetime)

    second_service_date = ActivePeriod.datetime_to_service_date(now)

    Date.compare(first_service_date, second_service_date) == :eq
  end

  @spec future_datetime?(NaiveDateTime.t(), DateTime.t()) :: boolean()
  def future_datetime?(datetime, now \\ DateTime.now!("Etc/UTC")) do
    datetime
    |> ActivePeriodBuilder.naive_eastern_datetime_to_utc()
    |> DateTime.compare(now) == :gt
  end

  @doc """
  Returns whether a datetime is before or equal to the second datetime
  Second argument defaults to now

  iex> time_is_past?(nil, ~U[2025-08-20 11:00:00Z])
  false
  iex> time_is_past?(~U[2025-08-20 10:00:00Z], ~U[2025-08-20 11:00:00Z])
  true
  iex> time_is_past?(~U[2025-08-20 12:00:00Z], ~U[2025-08-20 11:00:00Z])
  false
  """
  def time_is_past?(time, current_time \\ current_time())
  def time_is_past?(nil, _current_time), do: false

  def time_is_past?(time, current_time),
    do: NaiveDateTime.compare(current_time, time) in [:eq, :gt]

  @doc """
  Returns whether a datetime is in the future relative to the second datetime
  Second argument defaults to now

  iex> time_is_in_future?(nil, ~U[2025-08-20 11:00:00Z])
  false
  iex> time_is_in_future?(~U[2025-08-20 10:00:00Z], ~U[2025-08-20 11:00:00Z])
  false
  iex> time_is_in_future?(~U[2025-08-20 12:00:00Z], ~U[2025-08-20 11:00:00Z])
  true
  """
  def time_is_in_future?(time, current_time \\ current_time())
  def time_is_in_future?(nil, _current_time), do: false

  def time_is_in_future?(time, current_time),
    do: NaiveDateTime.compare(current_time, time) in [:lt]

  def naive_datetime_to_iso8601(%NaiveDateTime{} = datetime),
    do:
      datetime
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.to_iso8601()
      |> String.slice(0..-4//1)

  def naive_datetime_to_iso8601(_), do: ""

  def time_to_iso8601(%Time{} = time) do
    time
    |> Time.to_iso8601()
    |> String.slice(0..-4//1)
  end

  def time_to_iso8601(_), do: ""
end
