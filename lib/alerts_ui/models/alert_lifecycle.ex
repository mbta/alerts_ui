defmodule AlertsUI.Models.AlertLifecycle do
  @moduledoc """
    Causes to be used in the alert lifecycle field of Alert
  """

  @doc """
  Returns list of atoms allowed in alert lifecycle field of alert

  ## Examples
      iex> is_list(AlertsUI.Models.AlertLifecycle.alert_lifecycles)
      true
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
