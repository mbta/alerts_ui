defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.Time do
  @moduledoc """
  Date and time utility functions.
  """

  def today() do
    DateTime.now!("America/New_York") |> DateTime.to_date()
  end
end
