defmodule AlertsUIWeb.FormComponents.EffectsForRouteTypes do
  @moduledoc """
  associates route types with their subset of effects
  """
  alias AlertsUI.Models.Effect

  @doc """
  Returns lists of effect names
  ## Examples
      iex> is_list(AlertsUIWeb.FormComponents.EffectsForRouteTypes.list_effects(nil))
      true
      iex> is_list(AlertsUIWeb.FormComponents.EffectsForRouteTypes.list_effects("Subway"))
      true
      iex> is_list(AlertsUIWeb.FormComponents.EffectsForRouteTypes.list_effects("Commuter Rail"))
      true
      iex> is_list(AlertsUIWeb.FormComponents.EffectsForRouteTypes.list_effects("Bus"))
      true
      iex> is_list(AlertsUIWeb.FormComponents.EffectsForRouteTypes.list_effects("Ferry"))
      true
  """
  def list_effects(nil), do: Effect.effect_names()

  def list_effects("Subway"),
    do:
      [
        "Delay",
        "Station Closure",
        "Extra Service",
        "Shuttle",
        "Station Issue",
        "Service Change",
        "Suspension",
        "Schedule Change"
      ]
      |> Enum.sort()

  def list_effects("Commuter Rail"),
    do:
      [
        "Delay",
        "Suspension",
        "Track Change",
        "Service Change",
        "Cancellation",
        "Station Closure",
        "Schedule Change",
        "Shuttle",
        "Station Issue",
        "Extra Service"
      ]
      |> Enum.sort()

  def list_effects("Bus"),
    do:
      [
        "Delay",
        "Multi-Route Detour",
        "Stop Closure",
        "Extra Service",
        "Stop Move",
        "Snow Route",
        "Schedule Change",
        "Service Change",
        "Detour",
        "Suspension",
        "Stop Shoveling",
        "Cancellation"
      ]
      |> Enum.sort()

  def list_effects("Ferry"),
    do:
      [
        "Delay",
        "Suspension",
        "Schedule Change",
        "Cancellation",
        "Dock Closure",
        "Extra Service",
        "Shuttle",
        "Dock Issue",
        "Service Change"
      ]
      |> Enum.sort()
end
