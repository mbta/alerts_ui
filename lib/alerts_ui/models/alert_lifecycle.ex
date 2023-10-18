defmodule AlertsUI.Models.AlertLifecycle do
  @moduledoc """
    Causes to be used in the alert lifecycle field of Alerts.
  """
  def alert_lifecycles,
    do: [
      :UPCOMING_ONGOING,
      :NEW,
      :UPCOMING,
      :ONGOING,
      :ONGOING_UPCOMING
    ]
end
