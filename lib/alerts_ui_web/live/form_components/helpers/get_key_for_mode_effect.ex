defmodule AlertsUIWeb.FormComponents.Helpers.GetKeyForModeEffect do
  @moduledoc """
  Gives back the default severity given a mode and effect.
  """
  alias AlertsUI.Configs.ModeEffect
  alias AlertsUI.Models.InformedEntity
  alias MBTAV3API.Routes.Route

  @doc """
  Returns the value of a given key from the mode-effect table
  ## Examples
      iex> is_integer(DefaultSeverity.get_default_severity(nil, "Delay"))
      true
      iex> is_integer(DefaultSeverity.get_default_severity(:subway, nil))
      false
      iex> DefaultSeverity.get_default_severity(:light_rail, "Suspension")
      7
      iex> DefaultSeverity.get_default_severity(:bus, "Delay")
      4
  """
  @spec get_value_of_key(
          atom(),
          InformedEntity.mode_atom_t() | :facility | :systemwide | Route.type_int() | nil,
          String.t() | nil
        ) ::
          integer() | nil

  def get_value_of_key(key, service_type, effect_name) when is_integer(service_type) do
    route_type_name = InformedEntity.route_code_mapping(service_type)
    get_value_of_key(key, route_type_name, effect_name)
  end

  def get_value_of_key(_key, _service_type, nil),
    do: nil

  def get_value_of_key(key, :light_rail, effect_name),
    do: get_value_of_key(key, :subway, effect_name)

  def get_value_of_key(key, nil, effect_name),
    do: get_value_of_key(key, :systemwide, effect_name)

  def get_value_of_key(key, service_type, effect_name) do
    get_in(ModeEffect.mode_effect(), [service_type, effect_name, key])
  end
end
