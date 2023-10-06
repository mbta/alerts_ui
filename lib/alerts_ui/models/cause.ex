defmodule AlertsUI.Models.Cause do
  @moduledoc """
    Causes to be used in the cause field of Alerts.
  """
  def causes,
    do: [
      "UNKNOWN_CAUSE",
      "OTHER_CAUSE",
      "TECHNICAL_PROBLEM",
      "STRIKE",
      "DEMONSTRATION",
      "ACCIDENT",
      "HOLIDAY",
      "WEATHER",
      "MAINTENANCE",
      "CONSTRUCTION",
      "POLICE_ACTIVITY",
      "MEDICAL_EMERGENCY"
    ]
end
