defmodule AlertsUI.Models.Source do
  @moduledoc """
    Sourtces of Alerts, to be used on the source field
  """

  @doc """
  Returns list of atoms allowed in cause field of alert

  ## Examples
  iex> is_list(AlertsUI.Models.Cause.causes)
  true
  """
  def sources,
    do: [
      :ALERTS_MANAGER,
      :IBI,
      :TRAPEZE,
      :SKATE
    ]
end
