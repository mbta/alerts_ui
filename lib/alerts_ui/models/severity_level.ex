defmodule AlertsUI.Models.SeverityLevel do
  @moduledoc """
    Causes to be used in the severity level field of Alerts.
  """

  @doc """
  Returns list of atoms allowed in severity level field of alert

  ## Examples
      iex> is_list(AlertsUI.Models.SeverityLevel.severity_levels)
      true
  """
  def severity_levels,
    do: [
      :UNKNOWN_SEVERITY,
      :INFO,
      :WARNING,
      :SEVERE
    ]
end
