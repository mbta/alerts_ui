defmodule AlertsUIWeb.CreateAlertLive.Helpers.ServiceEffectCombinations do
  @moduledoc """
  Gives a combination based on service type and effect
  """

  @type service_effect_combination() :: :R | :RDS | :RDT | :RDTS | :SR | :ACCESS

  @doc """
  Returns atom indicating service-effect combination for route type and effect
  ## Examples
      iex> ServiceEffectCombinations.required_fields(nil)
      []
      iex> ServiceEffectCombinations.required_fields(:ACCESS)
      ~w[facility_ids]a
      iex> ServiceEffectCombinations.required_fields(:R)
      ~w[route_ids]a
      iex> ServiceEffectCombinations.required_fields(:SR)
      ~w[route_ids stop_ids]a
      iex> ServiceEffectCombinations.required_fields(:RDT)
      ~w[route_ids direction trip_ids]a
  """

  @spec required_fields(service_effect_combination() | nil) :: [atom()]
  def required_fields(nil), do: []
  def required_fields(:ACCESS), do: ~w[facility_ids]a
  def required_fields(:R), do: ~w[route_ids]a
  def required_fields(:SR), do: ~w[route_ids stop_ids]a
  def required_fields(:RDS), do: ~w[route_ids direction stop_ids]a
  def required_fields(:RDT), do: ~w[route_ids direction trip_ids]a
  def required_fields(:RDTS), do: ~w[route_ids direction trip_ids stop_ids]a
end
