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

    with {alerts, meta} <- Alerts.list_all_paginated(socket.assigns.meta.flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    # default to timeline: current if params don't contain timeline filter
    params =
      cond do
        params["filters"]["4"] ->
          params

        params["filters"] ->
          %{
            "filters" =>
              Map.put(params["filters"], "4", %{"field" => "timeline", "value" => "current"})
          }

        true ->
          %{"filters" => %{"4" => %{"field" => "timeline", "value" => "current"}}}
      end

    default_order_fields = lookup_end_time_order_fields_by_params(params)
    default_order_directions = lookup_end_time_order_directions_by_params(params)

    filters =
      params["filters"]
      |> Map.values()

    flop =
      socket.assigns.meta.flop
      |> Map.put(:order_by, default_order_fields)
      |> Map.put(:order_directions, default_order_directions)
      |> Map.put(:filters, filters)

    with {alerts, meta} <- Alerts.list_all_paginated(flop) do
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
  # Custom sort for the End column, given complicated sort expectations there
  def handle_event("sort-alerts", %{"order" => order}, socket)
      when order == "notification_period_end" do
    flop = socket.assigns.meta.flop

    # Need to mimic Flop.push_order in a custom way because push_order
    # updates the ordered fields AND direction, but takes too many liberties.
    # (e.g. defaults to asc, keeps the other sort fields, etc.)

    # If the existing flop metadata has notification_period_end,
    # then the directions need reversing. Otherwise, use default directions

    new_order_directions =
      if hd(flop.order_by) == :notification_period_end do
        flop.order_directions
        |> Enum.map(&reverse_order_direction(&1))
      else
        lookup_end_time_order_directions_by_params(socket.assigns.params)
      end

    order_fields = lookup_end_time_order_fields_by_params(socket.assigns.params)

    flop =
      flop
      |> Map.put(:order_by, order_fields)
      |> Map.put(:order_directions, new_order_directions)

    with {alerts, meta} <- Alerts.list_all_paginated(flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts)}
    end
  end

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
  def handle_event("open_details", %{"alert_id" => alert_id}, socket) when is_integer(alert_id) do
    alert_data = alert_id |> Integer.to_string() |> AlertData.build_alert_data()

    {:noreply, assign(socket, selected_alert_data: alert_data, selected_alert_id: alert_id)}
  end

  @impl true
  def handle_event("open_details", %{"alert_id" => _alert_id}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_details", _, socket) do
    {:noreply, assign(socket, selected_alert_data: nil, selected_alert_id: nil)}
  end

  @impl true
  def handle_event("cancelled_close_modal", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_alert", %{"alert_id" => alert_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/alerts/edit?alert_id=#{alert_id}")}
  end

  @impl true
  def handle_event("close_alert", %{"value" => alert_id}, socket) do
    alert_id |> Alerts.get_by_alert_id() |> Alerts.close()
    # refresh view so alert is displayed in correct timeline category
    Process.send(self(), :update, [])
    {:noreply, socket}
  end

  # Just stubbed until we have actions for these

  @impl true
  def handle_event("duplicate_alert", _, socket) do
    {:noreply, assign(socket, selected_alert_data: nil, selected_alert_id: nil)}
  end

  def lookup_end_time_order_fields_by_params(%{
        "filters" => %{"4" => %{"field" => "timeline", "value" => "past"}}
      }),
      do: [
        :active_period_end,
        :active_period_start
      ]

  def lookup_end_time_order_fields_by_params(_),
    do: [
      :notification_period_end,
      :active_period_end,
      :duration_certainty,
      :notification_period_start,
      :active_period_start
    ]

  def lookup_end_time_order_directions_by_params(%{
        "filters" => %{"4" => %{"field" => "timeline", "value" => "current"}}
      }),
      do: [:asc_nulls_last, :asc, :asc_nulls_last, :asc, :asc]

  def lookup_end_time_order_directions_by_params(%{
        "filters" => %{"4" => %{"field" => "timeline", "value" => "future"}}
      }),
      do: [:asc_nulls_last, :asc, :asc_nulls_last, :asc, :asc]

  def lookup_end_time_order_directions_by_params(%{
        "filters" => %{"4" => %{"field" => "timeline", "value" => "past"}}
      }),
      do: [:desc, :desc]

  def lookup_end_time_order_directions_by_params(%{
        "filters" => %{"4" => %{"field" => "timeline", "value" => _}}
      }),
      do: [:desc_nulls_first, :desc, :desc_nulls_first, :desc, :desc]

  def reverse_order_direction(:asc), do: :desc
  def reverse_order_direction(:desc), do: :asc
  def reverse_order_direction(:asc_nulls_last), do: :desc_nulls_first
  def reverse_order_direction(:desc_nulls_last), do: :asc_nulls_first
  def reverse_order_direction(:asc_nulls_first), do: :desc_nulls_last
  def reverse_order_direction(:desc_nulls_first), do: :asc_nulls_last

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
      adjusted_dt = adjusted_date_time(start_time_utc)

      DateTimeHelpers.friendly_date_time(adjusted_dt)
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
      adjusted_dt = adjusted_date_time(end_time_utc)

      DateTimeHelpers.friendly_date_time(adjusted_dt)
    end
  end

  def format_end_time(_, _), do: ""

  defp adjusted_date_time(nil), do: nil

  defp adjusted_date_time(utc_time) do
    adjusted_time = DateTime.shift_zone!(utc_time, "America/New_York")
    adjusted_dt_date = ActivePeriod.datetime_to_service_date_exclusive(adjusted_time)

    DateTime.new!(adjusted_dt_date, DateTime.to_time(adjusted_time), "America/New_York")
  end

  defp format_effect_options do
    [{"All", ""}]
    |> Enum.concat(
      Effect.effect_details()
      |> Enum.map(&{format_effect(&1), &1})
    )
  end

  def danger_text(active_period_end, closed_timestamp) do
    if DateTimeHelpers.will_be_ending_today?(active_period_end, closed_timestamp) do
      "text-danger"
    else
      ""
    end
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
    <span class="h-4 w-4">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="2"
        stroke="currentColor"
        class="w-4 h-4"
      >
        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5 8.25 12l7.5-7.5" />
      </svg>
    </span>
    """
  end

  defp carat_icon(:right) do
    assigns = %{}

    ~H"""
    <span class="h-4 w-4">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="2"
        stroke="currentColor"
        class="w-4 h-4"
      >
        <path stroke-linecap="round" stroke-linejoin="round" d="m8.25 4.5 7.5 7.5-7.5 7.5" />
      </svg>
    </span>
    """
  end

  defp sort_icon(:asc) do
    assigns = %{}

    ~H"""
    <.icon name="hero-arrow-up" class="ml-1 h-4 w-4" />
    """
  end

  defp sort_icon(:desc) do
    assigns = %{}

    ~H"""
    <.icon name="hero-arrow-down" class="ml-1 h-4 w-4" />
    """
  end

  defp sort_icon(nil) do
    assigns = %{}

    ~H"""
    <.icon name="hero-arrows-up-down" class="ml-1 h-4 w-4" />
    """
  end

  defp timeline_options, do: ["current", "future", "past", "all"]

  @spec clean_filter_params(map()) :: map()
  defp clean_filter_params(params), do: Map.drop(params, ["_target", "reset"])

  def timeline_filter_past?(%{
        "filters" => %{"4" => %{"field" => "timeline", "value" => timeline_filter}}
      }),
      do: timeline_filter == "past"
end
