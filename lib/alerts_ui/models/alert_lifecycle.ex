defmodule AlertsUI.Models.AlertLifecycle do
  @moduledoc """
    Causes to be used in the alert lifecycle field of Alert
  """

  @doc """
  Returns list of atoms allowed in alert lifecycle field of alert

  ## Examples
      iex> is_list(AlertsUI.Models.AlertLifecycle.alert_lifecycles)
      true
  """
  def alert_lifecycles,
    do: [
      :UPCOMING_ONGOING,
      :NEW,
      :UPCOMING,
      :ONGOING,
      :ONGOING_UPCOMING
    ]

  @doc """
  Calcuates correct alert lifecycle value given a unix timestamp
  Default comparison is to current time UTC

  ## Examples
    ### returns :UPCOMING if start time is more than 30 minutes in the future
    ### start time is ~U[2024-05-10 15:30:54Z]
    iex> AlertsUI.Models.AlertLifecycle.get_alert_lifecycle(1715355054, ~U[2024-05-10 14:30:54Z])
    :UPCOMING

    ### returns :NEW if start time is between 30 minutes in the future and 1 week in the past
    ### start time is ~U[2024-05-10 14:45:54Z]
    iex> AlertsUI.Models.AlertLifecycle.get_alert_lifecycle(1715352354, ~U[2024-05-10 14:30:54Z])
    :NEW

    ### start time is ~U[2024-05-05 14:30:54Z]
    iex> AlertsUI.Models.AlertLifecycle.get_alert_lifecycle(1714919454, ~U[2024-05-10 14:30:54Z])
    :NEW

    ### return :ONGOING if start time is over 1 week ago
    ### start time is ~U[2024-05-02 14:25:54Z]
    iex> AlertsUI.Models.AlertLifecycle.get_alert_lifecycle(1714659954, ~U[2024-05-10 14:30:54Z])
    :ONGOING
  """

  @spec get_alert_lifecycle(integer() | nil, DateTime.t()) :: :UPCOMING | :NEW | :ONGOING | nil
  def get_alert_lifecycle(active_period_start, current_time \\ DateTime.utc_now())
  def get_alert_lifecycle(nil, _), do: nil

  def get_alert_lifecycle(active_period_start, current_time) do
    active_period_start = active_period_start |> DateTime.from_unix!()

    thirty_minutes_from_now = DateTime.add(current_time, 30, :minute)
    one_week_ago = DateTime.add(current_time, -7, :day)

    cond do
      #if start is MORE than 30 minutes in the future, do upcoming
      DateTime.compare(active_period_start, thirty_minutes_from_now) in [:gt, :eq] -> :UPCOMING
      #else if start is LESS than one week old, do new
      DateTime.compare(one_week_ago, active_period_start) in [:lt, :eq] -> :NEW
      # else (start is MORE than one week old) do ongoing
      true -> :ONGOING
    end
  end
end
