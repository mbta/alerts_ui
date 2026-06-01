defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertData do
  require Logger
  alias AlertsUI.Models.Alert
  alias AlertsUI.Configs.ModeEffect
  alias AlertsUIWeb.FormComponents.Helpers.ContentFormatter
  alias Phoenix.HTML.Form

  import Ecto.Changeset, only: [get_field: 2]

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.Path,
    only: [path_route_type_from_form: 1, path_route_type: 2]

  @forbidden_effects ~w[Summary]

  @moduledoc """
  Helpers for dealing with alert data.
  """

  @doc """
  Get alert data from the changeset. Used for passing data as props,
  as `form[:field]` gives you a field struct rather than an actual value.
  """
  def alert_data_from_form(form, :route_type) do
    case get_field(form.source, :route_type) do
      nil -> nil
      route_type -> String.to_existing_atom(route_type)
    end
  end

  def alert_data_from_form(form, key) do
    get_field(form.source, key)
  end

  def show_details?(form) do
    !is_nil(form[:effect_name].value)
  end

  def get_route_type(nil), do: nil
  def get_route_type("access"), do: nil
  def get_route_type("systemwide"), do: nil

  def get_route_type(%Alert{} = alert) do
    get_route_type(alert.primary_service_type)
  end

  def get_route_type(route_type_string_int) do
    String.to_integer(route_type_string_int)
  end

  def list_effect_path_names(route_type) when is_binary(route_type) do
    route_type
    |> String.to_existing_atom()
    |> list_effect_path_names()
  end

  def list_effect_path_names(nil), do: []

  def list_effect_path_names(route_type_name) do
    (ModeEffect.mode_effects_by_route_type_name(route_type_name) || [])
    |> Enum.reject(fn {name, _struct} -> name in @forbidden_effects end)
    |> Enum.map(fn {_name, struct} -> struct.path_name end)
  end

  def humanize_effect_name(%Form{} = form) do
    route_type_name = path_route_type_from_form(form)
    effect_name = form[:effect_name].value
    humanize_effect_name(route_type_name, effect_name)
  end

  def humanize_effect_name(_, nil), do: nil
  def humanize_effect_name(nil, nil), do: nil
  def humanize_effect_name(nil, _), do: nil

  def humanize_effect_name(route_type_name, effect_name) when is_binary(route_type_name) do
    route_type_name
    |> String.to_existing_atom()
    |> humanize_effect_name(effect_name)
  end

  def humanize_effect_name(route_type_int, effect_name) when is_integer(route_type_int) do
    humanize_effect_name(
      path_route_type(route_type_int, effect_name),
      effect_name
    )
  end

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

  def humanize_route_type(%Form{} = form) do
    ContentFormatter.service_type_string(
      form[:route_type].value,
      form[:combination].value
    )
  end

  def get_single_route_effect_names do
    ["Detour", "Snow Route"]
  end

  def get_single_facility_effect_names do
    ["Elevator Closure", "Escalator Closure"]
  end

  def clear_my_errors(changeset, struct_module) do
    filtered_errors =
      Keyword.reject(changeset.errors, fn {key, _value} ->
        key in Map.keys(struct(struct_module))
      end)

    Map.put(changeset, :errors, filtered_errors)
  end

  def put_over_nil(map, key, value) do
    case Map.get(map, key) do
      nil -> Map.put(map, key, value)
      _ -> map
    end
  end

  def values_to_options(values) do
    Enum.map(values, fn value ->
      val = if is_atom(value), do: Atom.to_string(value), else: value
      name = val |> String.replace("_", " ") |> String.capitalize()
      {name, value}
    end)
  end

  def display_alert_timing(alert_timing) when is_atom(alert_timing) do
    display_alert_timing("#{alert_timing}")
  end

  def display_alert_timing(alert_timing) do
    String.capitalize(alert_timing)
  end

  def filter_empty_list_fields(map) do
    map
    |> Enum.reject(fn {_, v} -> v == [] end)
    |> Map.new()
  end
end
