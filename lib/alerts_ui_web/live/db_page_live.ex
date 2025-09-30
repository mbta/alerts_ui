defmodule AlertsUIWeb.DBPageLive do
  @moduledoc """
  LiveView for viewing the full alerts DB table
  """

  use AlertsUIWeb, :live_view
  alias AlertsUI.Alerts
  alias Ecto.Adapters.SQL

  @ten_seconds_in_ms 10_000

  @impl true
  def mount(params, _session, socket) do
    Process.send_after(self(), :update, @ten_seconds_in_ms)

    with {alerts, meta} <- Alerts.list_all_paginated_by_creation_date(params) do
      {:ok,
       assign(socket, page_title: "Alerts DB Table", meta: meta, alerts: alerts, params: params)}
    end
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, @ten_seconds_in_ms)

    with {alerts, meta} <- Alerts.list_all_paginated_by_creation_date(socket.assigns.meta.flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts)}
    end
  end

  @impl true
  def handle_event("erase_db", _params, socket) do
    SQL.query(AlertsUI.Repo, "TRUNCATE alerts CASCADE;", [], timeout: :infinity)
    {:noreply, socket}
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

    with {alerts, meta} <- Alerts.list_all_paginated_by_creation_date(flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts)}
    end
  end
end
