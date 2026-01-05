defmodule AlertsUIWeb.FormComponents.Helpers.DefaultSeverity do
  @moduledoc """
  Gives back the default severity given a mode and effect.
  """
  alias AlertsUI.Configs.ModeEffect
  alias AlertsUI.Models.InformedEntity
  alias MBTAV3API.Routes.Route

  @doc """
  Returns default severity given a mode type and effect
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
  @spec get_default_severity(
          InformedEntity.mode_atom_t() | :facility | :systemwide | Route.type_int() | nil,
          String.t() | nil
        ) ::
          integer() | nil

  def get_default_severity(service_type, effect_name) when is_integer(service_type) do
    route_type_name = InformedEntity.route_code_mapping(service_type)
    get_default_severity(route_type_name, effect_name)
  end

  def get_default_severity(_service_type, nil),
    do: nil

  def get_default_severity(:light_rail, effect_name),
    do: get_default_severity(:subway, effect_name)

  def get_default_severity(nil, effect_name),
    do: get_default_severity(:systemwide, effect_name)

  def get_default_severity(service_type, effect_name) do
    get_in(ModeEffect.mode_effect(), [service_type, effect_name, :default_severity])
  end
end
