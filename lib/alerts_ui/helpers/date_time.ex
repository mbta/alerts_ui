defmodule AlertsUI.Helpers.DateTime do
  @moduledoc """
  Helper functions for dealing with DateTimes
  """

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
end
