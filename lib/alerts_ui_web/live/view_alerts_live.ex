defmodule AlertsUIWeb.ViewAlertsLive do
  @moduledoc """
  LiveView for presenting a list of current alerts.
  """
  use AlertsUIWeb, :live_view
  alias AlertsUI.Alerts
  alias AlertsViewerWeb.DateTimeHelpers

  @impl true
  @spec mount(map(), any(), any()) :: {:ok, any()}
  def mount(params, _session, socket) do
    params =
      Map.merge(params, %Flop{
        page_size: 50,
        order_by: [:created_timestamp, :alert_id],
        order_directions: [:desc, :desc]
      })

    with {:ok, {alerts, meta}} <- Alerts.list_all_paginated(params) do
      {:ok, assign(socket, meta: meta, alerts: alerts)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  @spec handle_event(
          <<_::88, _::_*32>>,
          map(),
          atom()
          | %{
              :assigns =>
                atom()
                | %{
                    :meta => atom() | %{:flop => map(), optional(any()) => any()},
                    optional(any()) => any()
                  },
              optional(any()) => any()
            }
        ) :: {:noreply, any()}
  def handle_event("paginate-alerts", %{"page" => page}, socket) do
    flop = Flop.set_page(socket.assigns.meta.flop, page)

    with {:ok, {alerts, meta}} <- Alerts.list_all_paginated(flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts)}
    end
  end

  @impl true
  def handle_event("sort-alerts", %{"order" => order}, socket) do
    flop = Flop.push_order(socket.assigns.meta.flop, order)

    new_order_directions =
      flop.order_directions |> Enum.map(&if &1 == :desc, do: :desc_nulls_last, else: &1)

    flop = Map.put(flop, :order_directions, new_order_directions)

    with {:ok, {alerts, meta}} <- Alerts.list_all_paginated(flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts)}
    end
  end
end
