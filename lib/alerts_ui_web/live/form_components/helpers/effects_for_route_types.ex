defmodule AlertsUIWeb.FormComponents.Helpers.EffectsForRouteTypes do
  @moduledoc """
  associates route types with their subset of effects
  """
  alias AlertsUI.Configs.ModeEffect
  alias AlertsUI.Models.Effect

  @type route_type_names_t() :: :bus | :commuter_rail | :facility | :ferry | :subway | :systemwide
  @spec list_effects(route_type_names_t() | nil) ::
          [String.t()]
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

  def list_effects(route_type_name) do
    ModeEffect.mode_effect()[route_type_name] |> Map.keys()
  end
end
