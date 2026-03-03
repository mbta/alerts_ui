defmodule AlertsUI.Helpers.DateTime do
  @moduledoc """
  Helper functions for dealing with DateTimes
  """

  # Used when interpreting existing alerts with times that are in the gap
  # (Chosen when it's better to try to keep the time relative, like interpreting legacy alerts)
  @spec new_protecting_gaps!(Date.t(), Time.t(), String.t()) :: DateTime.t()
  def new_protecting_gaps!(date, time, zone \\ "America/New_York") do
    case DateTime.new(date, time, zone) do
      {:ok, datetime} ->
        datetime

      {:gap, early, late} ->
        # project the time into the future, past the edge of the gap
        gap = Time.diff(DateTime.to_time(late), DateTime.to_time(early))
        new_protecting_gaps!(date, Time.add(time, gap), zone)

      e ->
        raise e
    end
  end

  # Used when creating new alerts with times that are in the gap
  # (Chosen when relative accuracy is less important, like adjusting a single active period
  # for a recurring alert)
  @spec new_round_up_to_gap!(Date.t(), Time.t(), String.t()) :: DateTime.t()
  def new_round_up_to_gap!(date, time, zone \\ "America/New_York") do
    case DateTime.new(date, time, zone) do
      {:ok, datetime} ->
        datetime

      {:gap, _early, late} ->
        # round up to the gap
        new_protecting_gaps!(date, DateTime.to_time(late), zone)

      e ->
        raise e
    end
  end
end
