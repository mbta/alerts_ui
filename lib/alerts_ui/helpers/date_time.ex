defmodule AlertsUI.Helpers.DateTime do
  @moduledoc """
  Helper functions for dealing with DateTimes
  """

  # Used when interpreting existing alerts with times that are in the gap
  # (Chosen when it's better to try to keep the time relative, like interpreting legacy alerts)
  @spec protect_dst_gap!(Date.t(), Time.t(), String.t()) :: DateTime.t()
  def protect_dst_gap!(date, time, zone \\ "America/New_York") do
    case DateTime.new(date, time, zone) do
      {:ok, datetime} ->
        datetime

      {:gap, early, late} ->
        # project the time into the future, past the edge of the gap
        gap = Time.diff(DateTime.to_time(late), DateTime.to_time(early))
        protect_dst_gap!(date, Time.add(time, gap), zone)

      {:error, e} ->
        raise "Error in adjusting time for DST: #{e}"
    end
  end

  # Used when creating new alerts with times that are in the gap
  # (Chosen when relative accuracy is less important, like adjusting a single active period
  # for a recurring alert)
  @spec round_up_to_gap!(Date.t(), Time.t(), String.t()) :: DateTime.t()
  def round_up_to_gap!(date, time, zone \\ "America/New_York") do
    case DateTime.new(date, time, zone) do
      {:ok, datetime} ->
        datetime

      {:gap, _early, late} ->
        # round up to the gap
        protect_dst_gap!(date, DateTime.to_time(late), zone)

      {:error, e} ->
        raise "Error in rounding time to DST gap: #{e}"
    end
  end
end
