defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.Selections do
  require Logger

  alias Phoenix.LiveView.AsyncResult

  use AlertsUIWeb, :html

  def selections_loading?(%AsyncResult{loading: true}), do: true
  def selections_loading?(_), do: false

  def assign_unwrapped_selections(assigns, default \\ %{}) do
    case assigns.selections do
      %AsyncResult{loading: [:selections]} ->
        assign(assigns, :selections, default)

      %AsyncResult{ok?: true} ->
        assign(assigns, :selections, assigns.selections.result)

      %AsyncResult{ok?: false} ->
        raise "oops"

      nil ->
        assign(assigns, :selections, default)

      _ ->
        assigns
    end
  end
end
