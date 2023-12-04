defmodule AlertsUIWeb.ViewAlertsLive do
  @moduledoc """
  LiveView for presenting a list of current alerts.
  """
  use AlertsUIWeb, :live_view
  alias AlertsUI.Alerts
  alias AlertsUI.Models.ActivePeriod
  alias AlertsViewerWeb.DateTimeHelpers

  @impl true
  @spec mount(map(), any(), any()) :: {:ok, any()}
  def mount(params, _session, socket) do
    params = Map.merge(params, %{page_size: 50})

    with {:ok, {alerts, meta}} <- Alerts.list_all_paginated(params) do
      {:ok, assign(socket, meta: meta, alerts: alerts)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate-alerts", %{"page" => page}, socket) do
    flop = Flop.set_page(socket.assigns.meta.flop, page)

    with {:ok, {alerts, meta}} <- Alerts.list_all_paginated(flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts)}
    end
  end

  @impl true
  def handle_event("sort-alerts", %{"order" => order}, socket) do
    flop = Flop.push_order(socket.assigns.meta.flop, order)

    with {:ok, {alerts, meta}} <- Alerts.list_all_paginated(flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts)}
    end
  end
end
