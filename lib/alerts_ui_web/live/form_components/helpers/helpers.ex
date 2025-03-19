defmodule AlertsUIWeb.FormComponents.Helpers.Helpers do
  @moduledoc """
    Miscellaneous shared functions for AlertsUIWeb
  """

  def async_available?(assigns, key) do
    Map.get(assigns, key) && Map.get(assigns[key], :result) && assigns[key].ok? &&
      assigns[key].result
  end
end
