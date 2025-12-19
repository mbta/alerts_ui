defmodule AlertsUIWeb.FormComponents.Helpers.ServiceEffectCombinations do
  @moduledoc """
  Gives a combination based on service type and effect
  """

  alias MBTAV3API.Routes.Route

  @type service_effect_combination() :: :R | :RDS | :RDT | :RDTS | :SR | :ACCESS

  @doc """
  Returns atom indicating service-effect combination for route type and effect
  ## Examples
      iex> ServiceEffectCombinations.get_combination(nil, "Detour")
      nil
      iex> ServiceEffectCombinations.get_combination(3, nil)
      nil
      iex> ServiceEffectCombinations.get_combination(0, "Delay")
      :RDS
      iex> ServiceEffectCombinations.get_combination(1, "Station Closure")
      :SR
      iex> ServiceEffectCombinations.get_combination(1, "Extra Service")
      :R
      iex> ServiceEffectCombinations.get_combination(2, "Suspension")
      :RDS
      iex> ServiceEffectCombinations.get_combination(2, "Delay")
      :RDTS
      iex> ServiceEffectCombinations.get_combination(2, "Cancellation")
      :RDT
      iex> ServiceEffectCombinations.get_combination(2, "Station Closure")
      :SR
      iex> ServiceEffectCombinations.get_combination(2, "Schedule Change")
      :R
      iex> ServiceEffectCombinations.get_combination(3, "Cancellation")
      :RDS
      iex> ServiceEffectCombinations.get_combination(3, "Stop Move")
      :SR
      iex> ServiceEffectCombinations.get_combination(3, "Extra Service")
      :R
      iex> ServiceEffectCombinations.get_combination(4, "Shuttle")
      :RDS
      iex> ServiceEffectCombinations.get_combination(4, "Delay")
      :RDTS
      iex> ServiceEffectCombinations.get_combination(4, "Cancellation")
      :RDT
      iex> ServiceEffectCombinations.get_combination(4, "Dock Closure")
      :SR
      iex> ServiceEffectCombinations.get_combination(4, "Extra Service")
      :R
      iex> ServiceEffectCombinations.required_fields(nil)
      []
      iex> ServiceEffectCombinations.required_fields(:R)
      ~w[route_ids]a
      iex> ServiceEffectCombinations.required_fields(:SR)
      ~w[route_ids stop_ids]a
      iex> ServiceEffectCombinations.required_fields(:RDT)
      ~w[route_ids direction trip_ids]a
  """

  @spec get_combination(Route.type_int() | nil, String.t() | nil) ::
          service_effect_combination() | nil
  def get_combination(service_type, effect_name) when is_nil(service_type) or is_nil(effect_name),
    do: nil

  # Light Rail
  def get_combination(0, effect_name), do: get_combination(1, effect_name)

  # Subway
  def get_combination(1, effect_name) do
    cond do
      effect_name in ["Delay", "Service Change", "Shuttle", "Suspension"] -> :RDS
      effect_name in ["Station Closure", "Station Issue"] -> :SR
      effect_name in ["Extra Service", "Schedule Change"] -> :R
    end
  end

  # Commuter Rail
  def get_combination(2, effect_name) do
    cond do
      effect_name in ["Suspension"] -> :RDS
      effect_name in ["Delay", "Service Change", "Shuttle", "Track Change"] -> :RDTS
      effect_name in ["Cancellation"] -> :RDT
      effect_name in ["Station Closure", "Station Issue"] -> :SR
      effect_name in ["Extra Service", "Schedule Change"] -> :R
    end
  end

  # Bus
  def get_combination(3, effect_name) do
    cond do
      effect_name in [
        "Cancellation",
        "Delay",
        "Detour",
        "Service Change",
        "Snow Route",
        "Suspension"
      ] ->
        :RDS

      effect_name in ["Multi-Route Detour", "Stop Closure", "Stop Move"] ->
        :SR

      effect_name in ["Extra Service", "Schedule Change"] ->
        :R
    end
  end

  # Ferry
  def get_combination(4, effect_name) do
    cond do
      effect_name in ["Shuttle", "Suspension"] -> :RDS
      effect_name in ["Delay", "Service Change"] -> :RDTS
      effect_name in ["Cancellation"] -> :RDT
      effect_name in ["Dock Closure", "Dock Issue"] -> :SR
      effect_name in ["Extra Service", "Schedule Change"] -> :R
    end
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
