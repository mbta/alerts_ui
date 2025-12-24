defmodule AlertsUIWeb.FormComponents.Helpers.ServiceEffectCombinations do
  @moduledoc """
  Gives a combination based on service type and effect
  """

  alias AlertsUI.Configs.ModeEffect
  alias AlertsUI.Models.InformedEntity
  alias MBTAV3API.Routes.Route

  @type service_effect_combination() :: :R | :RDS | :RDT | :RDTS | :SR | :ACCESS

  @doc """
  Returns atom indicating service-effect combination for route type and effect
  ## Examples
      iex> ServiceEffectCombinations.get_combination(nil, "Detour")
      nil
      iex> ServiceEffectCombinations.get_combination(:bus, nil)
      nil
      iex> ServiceEffectCombinations.get_combination(:light_rail, "Delay")
      :RDS
      iex> ServiceEffectCombinations.get_combination(:subway, "Station Closure")
      :SR
      iex> ServiceEffectCombinations.get_combination(:subway, "Extra Service")
      :R
      iex> ServiceEffectCombinations.get_combination(:commuter_rail, "Suspension")
      :RDS
      iex> ServiceEffectCombinations.get_combination(:commuter_rail, "Delay")
      :RDTS
      iex> ServiceEffectCombinations.get_combination(:commuter_rail, "Cancellation")
      :RDT
      iex> ServiceEffectCombinations.get_combination(:commuter_rail, "Station Closure")
      :SR
      iex> ServiceEffectCombinations.get_combination(:commuter_rail, "Schedule Change")
      :R
      iex> ServiceEffectCombinations.get_combination(:bus, "Stop Move")
      :SR
      iex> ServiceEffectCombinations.get_combination(:bus, "Extra Service")
      :R
      iex> ServiceEffectCombinations.get_combination(:ferry, "Shuttle")
      :RDS
      iex> ServiceEffectCombinations.get_combination(:ferry, "Delay")
      :RDTS
      iex> ServiceEffectCombinations.get_combination(:ferry, "Cancellation")
      :RDT
      iex> ServiceEffectCombinations.get_combination(:ferry, "Dock Closure")
      :SR
      iex> ServiceEffectCombinations.get_combination(:ferry, "Extra Service")
      :R
      iex> ServiceEffectCombinations.get_combination(:facility, "Elevator Closure")
      :ACCESS
      iex> ServiceEffectCombinations.get_combination(1, "Station Closure")
      :SR
      iex> ServiceEffectCombinations.required_fields(nil)
      []
      iex> ServiceEffectCombinations.required_fields(:R)
      ~w[route_ids]a
      iex> ServiceEffectCombinations.required_fields(:SR)
      ~w[route_ids stop_ids]a
      iex> ServiceEffectCombinations.required_fields(:RDT)
      ~w[route_ids direction trip_ids]a
  """

  @spec get_combination(InformedEntity.mode_atom_t() | Route.type_int() | nil, String.t() | nil) ::
          service_effect_combination() | nil

  def get_combination(service_type, effect_name) when is_integer(service_type) do
    route_type_name = InformedEntity.route_code_mapping(service_type)
    get_combination(route_type_name, effect_name)
  end

  def get_combination(service_type, effect_name) when is_nil(service_type) or is_nil(effect_name),
    do: nil

  def get_combination(:light_rail, effect_name), do: get_combination(:subway, effect_name)

  def get_combination(service_type, effect_name) do
    get_in(ModeEffect.mode_effect(), [service_type, effect_name, :combination])
  end

  @spec required_fields(service_effect_combination() | nil) :: [atom()]
  def required_fields(nil), do: []
  def required_fields(:ACCESS), do: ~w[facility_id]a
  def required_fields(:R), do: ~w[route_ids]a
  def required_fields(:SR), do: ~w[route_ids stop_ids]a
  def required_fields(:RDS), do: ~w[route_ids direction stop_ids]a
  def required_fields(:RDT), do: ~w[route_ids direction trip_ids]a
  def required_fields(:RDTS), do: ~w[route_ids direction trip_ids stop_ids]a
end
