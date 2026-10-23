defmodule AlertsUIWeb.FormComponents.Helpers.EffectsForRouteTypes do
  @moduledoc """
  associates route types with their subset of effects
  """

  #TODO general helper
  alias AlertsUI.Configs.ModeEffect
  alias AlertsUI.Models.Effect

  @forbidden_effects ~w[Summary]

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

  def list_effects(route_type_string) when is_binary(route_type_string) do
    route_type_string
    |> String.to_existing_atom()
    |> list_effects()
  end

  def list_effects(route_type_name) do
    ModeEffect.mode_effect()[route_type_name]
    |> Map.keys()
    # wondering if there are places in the app that need to see these?
    |> Enum.reject(&(&1 in @forbidden_effects))
  end

  @spec list_path_names(route_type_names_t()) :: [String.t()]
  def list_path_names(route_type_name) do
    case ModeEffect.mode_effect()[route_type_name] do
      nil -> []
      effects -> effects |> Map.values() |> Enum.map(& &1.path_name)
    end
  end
end
