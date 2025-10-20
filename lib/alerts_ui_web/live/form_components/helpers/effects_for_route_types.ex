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
      iex> is_list(EffectsForRouteTypes.list_effects(:subway))
      true
      iex> is_list(EffectsForRouteTypes.list_effects(:commuter_rail))
      true
      iex> is_list(EffectsForRouteTypes.list_effects(:bus))
      true
      iex> is_list(EffectsForRouteTypes.list_effects(:ferry))
      true
      iex> is_list(EffectsForRouteTypes.list_effects(:systemwide))
      true
  """
  def list_effects(nil), do: Effect.effect_names()

  def list_effects(:subway),
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

  def list_effects(:commuter_rail),
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

  def list_effects(:bus),
    do: [
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

  def list_effects(:ferry),
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

  def list_effects(:facility),
    do: [
      "Elevator Closure",
      "Parking Closure",
      "Access Issue",
      "Bike Issue",
      "Escalator Closure",
      "Parking Issue",
      "Facility Issue"
    ]

  def list_effects(:systemwide),
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
