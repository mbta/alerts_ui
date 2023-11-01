defmodule AlertsUI.Models.DurationCertainty do
  @moduledoc """
    Causes to be used in the duration certainty field of Alerts.
  """

  @doc """
  Returns list of atoms allowed in duration_certainty field of alert

  ## Examples
      iex> is_list(AlertsUI.Models.DurationCertainty.duration_certainties)
      true
  """
  def duration_certainties,
    do: [
      :KNOWN,
      :UNKNOWN,
      :ESTIMATED
    ]
end
