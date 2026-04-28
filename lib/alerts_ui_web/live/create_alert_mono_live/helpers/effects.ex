defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.Effects do
  @moduledoc """
  All things effects.
  """
  alias AlertsUI.Configs.ModeEffect
  alias AlertsUI.Models.Effect

  @forbidden_effects ~w[Summary]

  def list_effect_path_names(route_type) when is_binary(route_type) do
    route_type
    |> String.to_existing_atom()
    |> list_effect_path_names()
  end

  def list_effect_path_names(route_type_name) do
    case ModeEffect.mode_effects_by_route_type_name(route_type_name) do
      nil -> []

      effects->
        effects
        |> Enum.reject(fn {name, struct} -> name in @forbidden_effects end)
        |> Enum.map(fn {name, struct} -> struct.path_name end)
    end
  end

  def humanize_effect_name(_, nil), do: nil 

  def humanize_effect_name(route_type_name, effect_name) do
    mode_effect = 
      ModeEffect.mode_effects_by_route_type_name(route_type_name)
      |> Enum.find(fn {mode_effect_name, mode_effect_struct} ->
        mode_effect_struct.path_name == effect_name
      end)

    case mode_effect do
      nil -> nil
      {mode_effect_name, _mode_effect_struct} -> mode_effect_name
    end
  end 
end
