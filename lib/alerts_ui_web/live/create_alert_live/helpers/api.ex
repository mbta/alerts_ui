defmodule AlertsUIWeb.CreateAlertLive.Helpers.API do
  @moduledoc """
  API access helpers.
  """

  def async_available(%{result: result} = async_value) do
    async_value.ok? && result
  end

  def async_available?(_), do: false
end
