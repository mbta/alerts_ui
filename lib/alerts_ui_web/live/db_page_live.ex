defmodule AlertsUIWeb.DBPageLive do
  @moduledoc """
  LiveView for viewing the full alerts DB table
  """

  use AlertsUIWeb, :live_view
  alias AlertsUI.Alerts

  @ten_seconds_in_ms 10_000

  @impl true
  def mount(params, _session, socket) do
    Process.send_after(self(), :update, @ten_seconds_in_ms)

    with alerts <- Alerts.list_all() do
      alerts = alerts |> Enum.sort_by(&(&1.alert_id |> Integer.parse() |> elem(0)))
      {:ok, assign(socket, page_title: "Alerts DB Table", alerts: alerts, params: params)}
    end
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, @ten_seconds_in_ms)

    with alerts <- Alerts.list_all() do
      alerts = alerts |> Enum.sort_by(&(&1.alert_id |> Integer.parse() |> elem(0)))
      {:noreply, assign(socket, alerts: alerts)}
    end
  end

  @impl true
  def handle_event("delete_alert", %{"value" => alert_id}, socket) do
    Alerts.delete(alert_id)

    # refresh view?
    Process.send(self(), :update, [])
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancelled_delete_modal", _, socket) do
    
    {:noreply, socket}
  end
end
