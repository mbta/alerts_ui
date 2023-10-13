defmodule AlertsUI.Models.AlertLifecycle do
  @moduledoc """
    Causes to be used in the alert lifecycle field of Alerts.
  """
  def alert_lifecycles,
    do: [
      :NEW,
      :UPCOMING,
      :ONGOING,
      :ONGOING_UPCOMING
    ]
end
