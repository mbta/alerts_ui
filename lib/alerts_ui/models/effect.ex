defmodule AlertsUI.Models.Effect do
  @moduledoc """
    Effects to be used in the effect field of Alerts.
  """

  @doc """
  Returns list of atoms allowed in effect field of alert

  ## Examples
      iex> is_list(AlertsUI.Models.Effect.effects)
      true
  """
  def effects,
    do: [
      :ACCESSIBILITY_ISSUE,
      :NO_SERVICE,
      :REDUCED_SERVICE,
      :SIGNIFICANT_DELAYS,
      :DETOUR,
      :ADDITIONAL_SERVICE,
      :MODIFIED_SERVICE,
      :OTHER_EFFECT,
      :UNKNOWN_EFFECT,
      :STOP_MOVED
    ]
end
