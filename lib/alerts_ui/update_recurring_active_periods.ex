defmodule AlertsUI.UpdateRecurringActivePeriods do
@moduledoc """
  Runs once a day to remove old active periods, and add new active periods to recurring
  active periods with no end
"""
#TODO update active period start and end

  def update_active_periods(alert_id, nil), do: nil
  def update_active_periods(alert_id, [_active_period]), do: nil
  def update_active_periods(alert_id, active_periods) do

  end
end
