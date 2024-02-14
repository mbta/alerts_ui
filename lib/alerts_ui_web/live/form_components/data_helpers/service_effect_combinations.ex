defmodule AlertsUIWeb.FormComponents.DataHelpers.ServiceEffectCombinations do
  @moduledoc """
  Gives a combination based on service type and effect
  """

  @spec get_combination(0 | 1 | 2 | 3 | 4 | nil, String.t() | nil) ::
          :R | :RDS | :RDT | :RDTS | :SR | nil
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
        "Stop Shoveling",
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
end
