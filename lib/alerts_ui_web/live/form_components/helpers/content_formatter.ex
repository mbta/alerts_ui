defmodule AlertsUIWeb.FormComponents.Helpers.ContentFormatter do
  @moduledoc """
    various formatters for webpage content
  """

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
end
