defmodule AlertsUIWeb.FormComponents.Helpers.ContentFormatter do
  @moduledoc """
    various formatters for webpage content
  """

  #TODO general helper

  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertLive.Helpers.ServiceEffectCombinations

  @doc """
  Returns formatted string given a route atom
  ## Examples
      iex> ContentFormatter.route_atom_to_string(:commuter_rail)
      "Commuter Rail"
      iex> ContentFormatter.route_atom_to_string(:bus)
      "Bus"
  """
  @spec route_atom_to_string(atom()) :: String.t()
  def route_atom_to_string(:commuter_rail), do: "Commuter Rail"

  def route_atom_to_string(route_atom),
    do: route_atom |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()

  @doc """
  Returns service type string given route_type and/or combination
  ## Examples
      iex> ContentFormatter.route_atom_to_string(:commuter_rail)
      "Commuter Rail"
      iex> ContentFormatter.route_atom_to_string(:bus)
      "Bus"
  """
  @spec service_type_string(
          integer() | nil,
          ServiceEffectCombinations.service_effect_combination() | nil
        ) :: String.t()
  def service_type_string(route_type, combination \\ nil)
  def service_type_string(_route_type, :ACCESS), do: "Facility"

  def service_type_string(nil, nil), do: "Systemwide"

  def service_type_string(route_type, _) do
    route_type
    |> InformedEntity.route_code_mapping()
    |> route_atom_to_string
  end
end
