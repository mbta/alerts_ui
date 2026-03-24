defmodule AlertsUIWeb.DBPageLive do
  @moduledoc """
  LiveView for viewing the full alerts DB table
  """

  use AlertsUIWeb, :live_view
  alias AlertsUI.Alerts
  alias AlertsUIWeb.Helpers

  @ten_seconds_in_ms 10_000

  @impl true
  def mount(params, _session, socket) do
    Process.send_after(self(), :update, @ten_seconds_in_ms)

    with {alerts, meta} <- Alerts.list_all_paginated_by_id(params) do
      {:ok,
       assign(socket,
         page_title: "Alerts DB Table",
         meta: meta,
         alerts: alerts,
         params: params,
         show_informed_entity: false
       )}
    end
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, @ten_seconds_in_ms)

    with {alerts, meta} <- Alerts.list_all_paginated_by_id(socket.assigns.meta.flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts)}
    end
  end

  @impl true
  def handle_event("delete_alert", %{"value" => alert_id}, socket) do
    Alerts.delete(alert_id)

    Process.send(self(), :update, [])
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancelled_delete_modal", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate-alerts", %{"page" => page}, socket) do
    flop = Flop.set_page(socket.assigns.meta.flop, page)

    with {alerts, meta} <- Alerts.list_all_paginated_by_id(flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts)}
    end
  end

  @impl true
  def handle_event("toggle_informed_entity", _, socket) do
    {:noreply, assign(socket, show_informed_entity: !socket.assigns.show_informed_entity)}
  end
end
