defmodule AlertsUIWeb.FormComponents.Helpers.EffectsForRouteTypes do
  @moduledoc """
  associates route types with their subset of effects
  """
  alias AlertsUI.Models.Effect

  @doc """
  Returns lists of effect names
  ## Examples
      iex> is_list(EffectsForRouteTypes.list_effects(nil))
      true
      iex> is_list(EffectsForRouteTypes.list_effects("Subway"))
      true
      iex> is_list(EffectsForRouteTypes.list_effects("Commuter Rail"))
      true
      iex> is_list(EffectsForRouteTypes.list_effects("Bus"))
      true
      iex> is_list(EffectsForRouteTypes.list_effects("Ferry"))
      true
      iex> is_list(EffectsForRouteTypes.list_effects("Systemwide"))
      true
  """
  def list_effects(nil), do: Effect.effect_names()

  def list_effects("Subway"),
    do: [
      "Delay",
      "Extra Service",
      "Schedule Change",
      "Service Change",
      "Shuttle",
      "Station Closure",
      "Station Issue",
      "Suspension"
    ]

  def list_effects("Commuter Rail"),
    do: [
      "Cancellation",
      "Delay",
      "Extra Service",
      "Schedule Change",
      "Service Change",
      "Shuttle",
      "Station Closure",
      "Station Issue",
      "Suspension",
      "Track Change"
    ]

  def list_effects("Bus"),
    do: [
      "Cancellation",
      "Delay",
      "Detour",
      "Extra Service",
      "Multi-Route Detour",
      "Schedule Change",
      "Service Change",
      "Snow Route",
      "Stop Closure",
      "Stop Move",
      "Stop Shoveling",
      "Suspension"
    ]

  def list_effects("Ferry"),
    do: [
      "Cancellation",
      "Delay",
      "Dock Closure",
      "Dock Issue",
      "Extra Service",
      "Schedule Change",
      "Service Change",
      "Shuttle",
      "Suspension"
    ]

  def list_effects("Systemwide"),
    do: [
      "Amber Alert",
      "Delay",
      "Extra Service",
      "Policy Change",
      "Schedule Change",
      "Service Change",
      "Summary",
      "Suspension"
    ]
end
