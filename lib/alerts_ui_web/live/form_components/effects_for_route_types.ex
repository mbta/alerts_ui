defmodule AlertsUIWeb.FormComponents.EffectsForRouteTypes do
  @moduledoc """
  associates route types with their subset of effects
  """

  def list_effects(nil), do: AlertsUI.Models.Effect.effect_details()

  def list_effects("Subway"),
    do:
      [
        "DELAY",
        "STATION_CLOSURE",
        "EXTRA_SERVICE",
        "SHUTTLE",
        "STATION_ISSUE",
        "SERVICE_CHANGE",
        "SUSPENSION",
        "SCHEDULE_CHANGE"
      ]
      |> Enum.sort()

  def list_effects("Commuter Rail"),
    do:
      [
        "DELAY",
        "SUSPENSION",
        "TRACK_CHANGE",
        "SERVICE_CHANGE",
        "CANCELLATION",
        "STATION_CLOSURE",
        "SCHEDULE_CHANGE",
        "SHUTTLE",
        "STATION_ISSUE",
        "EXTRA_SERVICE"
      ]
      |> Enum.sort()

  def list_effects("Bus"),
    do:
      [
        "DELAY",
        "MULTI-ROUTE_DETOUR",
        "STOP_CLOSURE",
        "EXTRA_SERVICE",
        "STOP_MOVE",
        "SNOW_ROUTE",
        "SCHEDULE_CHANGE",
        "SERVICE_CHANGE",
        "DETOUR",
        "SUSPENSION",
        "STOP_SHOVELING",
        "CANCELLATION"
      ]
      |> Enum.sort()

  def list_effects("Ferry"),
    do:
      [
        "DELAY",
        "SUSPENSION",
        "SCHEDULE_CHANGE",
        "CANCELLATION",
        "DOCK_CLOSURE",
        "EXTRA_SERVICE",
        "SHUTTLE",
        "DOCK_ISSUE",
        "SERVICE_CHANGE"
      ]
      |> Enum.sort()
end
