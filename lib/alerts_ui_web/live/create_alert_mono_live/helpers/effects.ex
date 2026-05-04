defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.Effects do
  @moduledoc """
  All things effects.
  """
  alias AlertsUI.Configs.ModeEffect
  alias Phoenix.HTML.Form

  @forbidden_effects ~w[Summary]

  def list_effect_path_names(route_type) when is_binary(route_type) do
    route_type
    |> String.to_existing_atom()
    |> list_effect_path_names()
  end

  def list_effect_path_names(route_type_name) do
    case ModeEffect.mode_effects_by_route_type_name(route_type_name) do
      nil ->
        []

      effects ->
        effects
        |> Enum.reject(fn {name, _struct} -> name in @forbidden_effects end)
        |> Enum.map(fn {_name, struct} -> struct.path_name end)
    end
  end

  def humanize_effect_name(%Form{} = form) do
    route_type_name = String.to_existing_atom(form[:route_type].value)
    effect_name = form[:effect_name].value
    humanize_effect_name(route_type_name, effect_name)
  end

  def humanize_effect_name(_, nil), do: nil

  def humanize_effect_name(route_type_name, effect_name) do
    mode_effect =
      ModeEffect.mode_effects_by_route_type_name(route_type_name)
      |> Enum.find(fn {_mode_effect_name, mode_effect_struct} ->
        mode_effect_struct.path_name == effect_name
      end)

    case mode_effect do
      nil -> nil
      {mode_effect_name, _mode_effect_struct} -> mode_effect_name
    end
  end
end
