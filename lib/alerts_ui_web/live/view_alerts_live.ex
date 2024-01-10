defmodule AlertsUIWeb.ViewAlertsLive do
  @moduledoc """
  LiveView for presenting a list of current alerts.
  """
  use AlertsUIWeb, :live_view
  alias AlertsUI.Alerts
  alias AlertsUI.Models.Effect
  alias AlertsUI.Models.InformedEntity
  alias AlertsViewerWeb.DateTimeHelpers

  @impl true
  @spec mount(map(), any(), any()) :: {:ok, any()}
  def mount(params, _session, socket) do
    params =
      Map.merge(
        %Flop{
          page_size: 50
        },
        params
      )

    with {alerts, meta} <- Alerts.list_all_paginated(params) do
      {:ok, assign(socket, meta: meta, alerts: alerts)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    with {alerts, meta} <- Alerts.list_all_paginated(params) do
      {:noreply, assign(socket, meta: meta, alerts: alerts)}
    end
  end

  @impl true
  def handle_event("paginate-alerts", %{"page" => page}, socket) do
    flop = Flop.set_page(socket.assigns.meta.flop, page)

    with {alerts, meta} <- Alerts.list_all_paginated(flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts)}
    end
  end

  @impl true
  def handle_event("sort-alerts", %{"order" => order}, socket) do
    flop = Flop.push_order(socket.assigns.meta.flop, order)

    new_order_directions =
      flop.order_directions
      |> Enum.map(&if &1 == :desc, do: :desc_nulls_last, else: &1)
      |> Enum.map(&if &1 == :asc, do: :asc_nulls_first, else: &1)

    flop = Map.put(flop, :order_directions, new_order_directions)

    with {alerts, meta} <- Alerts.list_all_paginated(flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts)}
    end
  end

  @impl true
  def handle_event("update-filter", %{"reset" => ""} = params, socket) do
    params =
      params
      |> clean_filter_params()
      |> Map.replace("filters", %{})

    {:noreply, push_patch(socket, to: ~p"/alerts?#{params}")}
  end

  def handle_event("update-filter", params, socket) do
    params = clean_filter_params(params)
    {:noreply, push_patch(socket, to: ~p"/alerts?#{params}")}
  end

  defp clean_filter_params(params), do: Map.drop(params, ["_target", "reset"])

  defp format_effect_options do
    [{"All", ""}]
    |> Enum.concat(
      Effect.effect_details()
      |> Enum.map(
        &{&1
         |> String.replace("_", " ")
         |> String.split()
         |> Enum.map_join(" ", fn s -> String.capitalize(s) end), &1}
      )
    )
  end

  defp format_service_type_options do
    [{"All", ""}]
    |> Enum.concat(InformedEntity.route_type_mapping())
    |> Enum.map(fn {k, v} -> {k, v} end)
    |> Enum.concat([{"Access", :access}])
  end
end
