defmodule AlertsUI.Models.SeverityLevel do
  @moduledoc """
    Causes to be used in the severity level field of Alerts.
  """
  def severity_levels,
    do: [
      :UNKNOWN_SEVERITY,
      :INFO,
      :WARNING,
      :SEVERE
    ]
end
