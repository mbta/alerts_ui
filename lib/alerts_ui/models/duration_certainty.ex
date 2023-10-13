defmodule AlertsUI.Models.DurationCertainty do
  @moduledoc """
    Causes to be used in the duration certainty field of Alerts.
  """
  def duration_certainties,
    do: [
      :KNOWN,
      :UNKNOWN,
      :ESTIMATED
    ]
end
