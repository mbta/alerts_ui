defmodule AlertsUIWeb.FormComponents.Helpers.Helpers do
  @moduledoc """
    Miscellaneous shared functions for AlertsUIWeb
  """

  def async_available?(assigns, key) do
    Map.get(assigns, key) && Map.get(assigns[key], :result) && assigns[key].ok? &&
      assigns[key].result
  end

  # Filter out the empty list fields from a map
  @spec filter_empty_list_fields(map()) :: map()
  def filter_empty_list_fields(map) do
    map
    |> Enum.reject(fn {_, v} -> v == [] end)
    |> Map.new()
  end
end
