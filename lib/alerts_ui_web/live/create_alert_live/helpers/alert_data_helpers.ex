defmodule AlertsUIWeb.CreateAlertLive.Helpers.AlertDataHelpers do
  alias AlertsUI.Configs.ModeEffect
  alias AlertsUI.Models.Alert
  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.FormComponents.Helpers.ContentFormatter
  alias AlertsUIWeb.FormComponents.Helpers.GetKeyForModeEffect
  alias Phoenix.HTML.Form

  import Ecto.Changeset, only: [get_field: 2]

  import AlertsUIWeb.CreateAlertLive.Helpers.Path,
    only: [path_route_type_from_form: 1, path_route_type: 2]

  @forbidden_effects ~w[Summary]

  @atomized_fields [
    :active_period_start_specifier,
    :active_period_start_time_specifier,
    :active_period_end_specifier,
    :active_period_end_time_specifier,
    :notification_specifier,
    :recurrence_days
  ]

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

  @spec show_details?(Phoenix.HTML.Form.t(), boolean()) :: boolean()
  def show_details?(form, change_type?)

  def show_details?(form, change_type?) do
    if change_type? do
      false
    else
      !is_nil(form[:effect_name].value)
    end
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

  def humanize_effect_name(nil, effect_name) do
    humanize_effect_name(path_route_type(nil, effect_name), effect_name)
  end

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

  def normalize_effect_name(alert_data) do
    normalized =
      case Map.get(alert_data, :effect_name) do
        nil ->
          nil

        effect_name ->
          effect_name
          |> String.split(" ")
          |> Enum.map_join("_", &String.downcase(&1))
      end

    Map.put(alert_data, :effect_name, normalized)
  end

  def humanize_route_type(%Form{} = form) do
    ContentFormatter.service_type_string(
      form[:route_type].value,
      form[:combination].value
    )
  end

  def get_single_route_effect_names do
    ["Detour", "Snow Route", "Station Bypass", "Dock Bypass"]
  end

  def get_single_facility_effect_names do
    ["Elevator Closure", "Escalator Closure"]
  end

  @spec facility_types(String.t()) :: [String.t()]
  def facility_types(effect_name) do
    effect_name
    |> effect_to_lookup_key()
    |> InformedEntity.facility_effect_to_types()
  end

  defp effect_to_lookup_key(nil), do: nil

  defp effect_to_lookup_key(string) do
    string
    |> String.upcase()
    |> String.replace(" ", "_")
  end

  @doc """
  Returns the combination atom for a given route_type and effect_name.

  When route_type is nil (facility/systemwide alerts), existing_combination is
  returned as a fallback before attempting a lookup, because nil route_type is
  intentional for those alert types and we don't want to reset a valid combination.
  """
  @spec combination_for(integer() | binary() | atom() | nil, binary() | nil, atom() | nil) ::
          atom() | nil
  def combination_for(route_type, effect_name, existing_combination \\ nil)

  def combination_for(nil, effect_name, existing_combination) do
    existing_combination ||
      GetKeyForModeEffect.get_value_of_key(
        :combination,
        nil,
        humanize_effect_name(nil, effect_name)
      )
  end

  def combination_for(route_type, effect_name, _existing_combination) do
    GetKeyForModeEffect.get_value_of_key(
      :combination,
      route_type,
      humanize_effect_name(route_type, effect_name)
    )
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

  def strip_recurrence_days_if_one_time(alert_data) do
    if alert_data.alert_timing in [:"one-time", "one-time"] do
      Map.put(alert_data, :recurrence_days, [])
    else
      alert_data
    end
  end

  def strip_banner_text_unless_enabled(alert_data) do
    if alert_data.view_banner do
      alert_data
    else
      Map.drop(alert_data, [:banner_text])
    end
  end

  def atomize_fields(alert_data) when is_struct(alert_data) do
    alert_data
    |> Map.from_struct()
    |> atomize_fields()
  end

  def atomize_fields(alert_data) when is_map(alert_data) do
    for {key, value} <- alert_data, into: %{} do
      value =
        if Enum.member?(@atomized_fields, key) do
          atomize_field(value)
        else
          value
        end

      {key, value}
    end
  end

  def atomize_field(value) when is_list(value) do
    Enum.map(value, &atomize_field/1)
  end

  def atomize_field(value) do
    case value do
      value when is_binary(value) -> String.to_existing_atom(value)
      value when is_atom(value) -> value
    end
  end
end
