defmodule AlertsUIWeb.ViewAlertsLive do
  @moduledoc """
  LiveView for presenting a list of current alerts.
  """
  use AlertsUIWeb, :live_view
  alias AlertsUI.Alerts
  alias AlertsUI.Models.{ActivePeriod, Effect}
  alias AlertsUIWeb.DateTimeHelpers
  alias AlertsUIWeb.FormComponents.Helpers.AlertData

  @ten_seconds_in_ms 10_000

  @impl true
  def mount(params, _session, socket) do
    Process.send_after(self(), :update, @ten_seconds_in_ms)

    with {alerts, meta} <- Alerts.list_all_paginated(params) do
      {:ok, assign(socket, page_title: "View Alerts", meta: meta, alerts: alerts, params: params)}
    end
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, @ten_seconds_in_ms)

    with {alerts, meta} <- Alerts.list_all_paginated(socket.assigns.params) do
      {:noreply, assign(socket, meta: meta, alerts: alerts)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    # default to timeline: current if parameters empty
    params =
      if params == %{} do
        %{
          "filters" => %{
            "4" => %{"field" => "timeline", "value" => "current"}
          }
        }
      else
        params
      end

    with {alerts, meta} <- Alerts.list_all_paginated(params) do
      {:noreply, assign(socket, meta: meta, alerts: alerts, params: params)}
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

  @impl true
  def handle_event("open_details", %{"alert_id" => alert_id}, socket) do
    alert_data = alert_id |> Integer.to_string() |> AlertData.build_alert_data()

    {:noreply, assign(socket, selected_alert_data: alert_data, selected_alert_id: alert_id)}
  end

  @impl true
  def handle_event("close_details", _, socket) do
    {:noreply, assign(socket, selected_alert_data: nil, selected_alert_id: nil)}
  end

  @impl true
  def handle_event("edit_alert", %{"alert_id" => alert_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/alerts/edit?alert_id=#{alert_id}")}
  end

  # Just stubbed until we have actions for these
  @impl true
  def handle_event("close_alert", _, socket) do
    {:noreply, assign(socket, selected_alert_data: nil, selected_alert_id: nil)}
  end

  @impl true
  def handle_event("duplicate_alert", _, socket) do
    {:noreply, assign(socket, selected_alert_data: nil, selected_alert_id: nil)}
  end

  def format_start_time(start_time_utc) do
    current_service_date =
      DateTime.now!("America/New_York")
      |> ActivePeriod.datetime_to_service_date()

    most_recent_start_of_service =
      DateTime.new!(
        current_service_date,
        ActivePeriod.start_of_service_time(),
        "America/New_York"
      )

    if start_time_utc && DateTime.compare(most_recent_start_of_service, start_time_utc) == :eq do
      "start of service"
    else
      DateTimeHelpers.friendly_date_time(start_time_utc)
    end
  end

  def format_end_time(_end_time_utc, :UNKNOWN), do: "further notice"

  def format_end_time(_end_time_utc, :ESTIMATED), do: "later today"

  def format_end_time(end_time_utc, :KNOWN) do
    if DateTime.compare(
         ActivePeriod.end_of_service_datetime_utc(DateTime.utc_now()),
         end_time_utc
       ) == :eq do
      "end of service"
    else
      DateTimeHelpers.friendly_date_time(end_time_utc)
    end
  end

  def format_end_time(_, _), do: ""

  defp format_effect_options do
    [{"All", ""}]
    |> Enum.concat(
      Effect.effect_details()
      |> Enum.map(&{format_effect(&1), &1})
    )
  end

  defp format_effect(nil), do: ""

  defp format_effect(effect) do
    effect
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", fn s -> String.capitalize(s) end)
  end

  defp format_service_type_options do
    [
      {"All", ""},
      {"Light Rail", 0},
      {"Subway", 1},
      {"Commuter Rail", 2},
      {"Bus", 3},
      {"Ferry", 4},
      {"Access", :access}
    ]
  end

  defp carat_icon(:left) do
    assigns = %{}

    ~H"""
    <.icon name="hero-chevron-left-solid" class="h-4 w-4" />
    """
  end

  defp carat_icon(:right) do
    assigns = %{}

    ~H"""
    <.icon name="hero-chevron-right-solid" class="h-4 w-4" />
    """
  end

  defp timeline_options, do: ["current", "future", "past", "all"]

  @spec clean_filter_params(map()) :: map()
  defp clean_filter_params(params), do: Map.drop(params, ["_target", "reset"])
end
