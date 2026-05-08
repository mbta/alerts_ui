defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.Selections do
  require Logger

  alias Phoenix.LiveView.AsyncResult

  use AlertsUIWeb, :html

  def selections_loading?(%AsyncResult{loading: true}), do: true
  def selections_loading?(_), do: false

  def assign_unwrapped_selections(assigns, default) do
    case assigns.selections do
      %AsyncResult{loading: [:selections]} ->
        Logger.warning("1 - DEFAULT")
        assign(assigns, :selections, default)

      %AsyncResult{ok?: true} ->
        Logger.warning("2 - #{inspect(assigns.selections)}")
        assign(assigns, :selections, assigns.selections.result)

      %AsyncResult{ok?: false} ->
        Logger.warning("3 - FAILURE #{inspect(assigns.selections)}")
        raise "oops"

      nil ->
        Logger.warning("4 - DEFAULT")
        assign(assigns, :selections, default)

      _ ->
        Logger.warning("4 - NADA")
        assigns
    end
  end
end
