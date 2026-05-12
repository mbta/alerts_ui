defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.Selections do
  require Logger

  alias Phoenix.LiveView.AsyncResult

  use AlertsUIWeb, :html

  def selections_loading?(%AsyncResult{loading: true}), do: true
  def selections_loading?(_), do: false

  def assign_unwrapped_selections(assigns, default) do
    case assigns.selections do
      %AsyncResult{loading: [:selections]} ->
        IO.inspect("1 - DEFAULT")
        assign(assigns, :selections, default)

      %AsyncResult{ok?: true} ->
        IO.inspect("2 - #{inspect(assigns.selections)}")
        assign(assigns, :selections, assigns.selections.result)

      %AsyncResult{ok?: false} ->
        IO.inspect("3 - FAILURE #{inspect(assigns.selections)}")
        raise "oops"

      nil ->
        IO.inspect("4 - DEFAULT")
        assign(assigns, :selections, default)

      _ ->
        IO.inspect("5 - NADA")
        assigns
    end
  end
end
