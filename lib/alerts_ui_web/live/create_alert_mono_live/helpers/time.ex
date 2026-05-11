defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.Time do
  @moduledoc """
  Date and time utility functions.
  """

  def today() do
    DateTime.now!("America/New_York") |> DateTime.to_date()
  end

  def replace_date(d, %DateTime{} = dt) do
    DateTime.new!(d, DateTime.to_time(dt), dt.time_zone)
  end

  def replace_date(d, %NaiveDateTime{} = dt) do
    NaiveDateTime.new!(d, NaiveDateTime.to_time(dt))
  end

  def replace_time(%DateTime{} = dt, t) do
    DateTime.new!(DateTime.to_date(dt), t, dt.time_zone)
  end

  def replace_time(%NaiveDateTime{} = dt, t) do
    NaiveDateTime.new!(NaiveDateTime.to_date(dt), t)
  end
end
