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
      :ADDITIONAL_SERVICE,
      :DETOUR,
      :MODIFIED_SERVICE,
      :NO_EFFECT,
      :NO_SERVICE,
      :OTHER_EFFECT,
      :REDUCED_SERVICE,
      :SIGNIFICANT_DELAYS,
      :STOP_MOVED,
      :UNKNOWN_EFFECT
    ]

  def effect_details,
    do: [
      "ACCESS_ISSUE",
      "AMBER_ALERT",
      "BIKE_ISSUE",
      "CANCELLATION",
      "DELAY",
      "DETOUR",
      "DOCK_CLOSURE",
      "DOCK_ISSUE",
      "ELEVATOR_CLOSURE",
      "ESCALATOR_CLOSURE",
      "EXTRA_SERVICE",
      "FACILITY_ISSUE",
      "PARKING_CLOSURE",
      "PARKING_ISSUE",
      "POLICY_CHANGE",
      "SCHEDULE_CHANGE",
      "SERVICE_CHANGE",
      "SHUTTLE",
      "SNOW_ROUTE",
      "STATION_CLOSURE",
      "STATION_ISSUE",
      "STOP_CLOSURE",
      "STOP_MOVE",
      "STOP_SHOVELING",
      "SUMMARY",
      "SUSPENSION",
      "TRACK_CHANGE"
    ]
end
