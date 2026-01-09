defmodule AlertsUIWeb.FormComponents.Helpers.DefaultCause do
  @moduledoc """
  Gives back the default cause detail given a mode and effect.
  Only single tracking actually has one right now so this usually gives back an empty string.
  """
  alias AlertsUI.Configs.ModeEffect
  alias AlertsUI.Models.InformedEntity
  alias MBTAV3API.Routes.Route

  @doc """
  Returns default cause detail given a mode type and effect
  ## Examples
      iex> is_nil(DefaultCause.get_default_cause(nil, "Delay"))
      true
      iex> is_nil(DefaultCause.get_default_cause(:subway, nil))
      true
      iex> is_nil(DefaultCause.get_default_cause(:subway, "Delay"))
      true
      iex> is_nil(DefaultCause.get_default_cause(:subway, "Single Tracking"))
      false
  """
  @spec get_default_cause(
          InformedEntity.mode_atom_t() | :facility | :systemwide | Route.type_int() | nil,
          String.t() | nil
        ) ::
          String.t()

  def get_default_cause(service_type, effect_name) when is_integer(service_type) do
    route_type_name = InformedEntity.route_code_mapping(service_type)
    get_default_cause(route_type_name, effect_name)
  end

  def get_default_cause(_service_type, nil),
    do: ""

  def get_default_cause(:light_rail, effect_name),
    do: get_default_cause(:subway, effect_name)

  def get_default_cause(nil, effect_name),
    do: get_default_cause(:systemwide, effect_name)

  def get_default_cause(service_type, effect_name) do
    get_in(ModeEffect.mode_effect(), [service_type, effect_name, :default_cause]) || ""
  end
end
