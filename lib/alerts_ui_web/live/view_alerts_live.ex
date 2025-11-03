defmodule AlertsUIWeb.ViewAlertsLive do
  @moduledoc """
  LiveView for presenting a list of current alerts.
  """
  use AlertsUIWeb, :live_view
  use AlertsUI.Schema

  import AlertsUIWeb.FilterForm

  alias AlertsUI.Alerts
  alias AlertsUI.Models.{ActivePeriod, Alert}
  alias AlertsUIWeb.FormComponents.Helpers.{AlertData, DateTimeFormatters, DateTimeHelpers}
  alias AlertsUIWeb.FormComponents.Helpers.AutoText.BuildAutoText

  require Logger

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :timeline, :string
    field :multi_column_search, :string
    field :service_type, {:array, :string}
    field :service_type_search_term, :string
    field :routes, {:array, :string}
    field :routes_search_term, :string
    field :effects, {:array, :string}
    field :effects_search_term, :string
  end

  @ten_seconds_in_ms 10_000
  @fields ~w[timeline multi_column_search service_type service_type_search_term routes routes_search_term effects effects_search_term]a

  @modal_filter_fields ["service_type", "routes", "effects"]
  @other_filter_fields ["multi_column_search", "timeline"]
  @filter_fields @modal_filter_fields ++ @other_filter_fields

  @impl true
  def mount(params, _session, socket) do
    Process.send_after(self(), :update, @ten_seconds_in_ms)

    with {alerts, meta} <- Alerts.list_all_paginated(params) do
      filters = Map.get(params, "filter", %{"timeline" => "current"})

      form =
        cast(%__MODULE__{}, filters, @fields)
        |> Phoenix.Component.to_form()

      {:ok,
       assign(socket,
         alerts: alerts,
         filter_count: get_filter_count(filters),
         form: form,
         meta: meta,
         page_title: "View Alerts",
         params: params,
         scroll_to_top: false
       )}
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
    # default to timeline: current if params have no values
    # (eg no user input has occurred and we're probably in a fresh reload)

    # Process the params to construct the filters in the format Flop needs
    flop_filters =
      params
      |> Map.get("filter", [])
      |> Enum.reduce([], fn {k, v}, acc ->
        if v != "" do
          acc ++ [%{"field" => k, "value" => v}]
        else
          acc
        end
      end)

    timefield = Enum.find(flop_filters, fn %{"field" => k, "value" => _v} -> k == "timeline" end)
    timefield = if timefield, do: timefield, else: %{"field" => "timeline", "value" => "current"}

    flop_filters = if timefield, do: flop_filters, else: flop_filters ++ [timefield]

    default_order_fields = lookup_end_time_order_fields_by_params(timefield)
    default_order_directions = lookup_end_time_order_directions_by_params(timefield)

    # Flop gets updated
    flop =
      socket.assigns.meta.flop
      |> Flop.set_page(params["page"] || "1")
      |> Map.put(:order_by, default_order_fields)
      |> Map.put(:order_directions, default_order_directions)
      |> Map.put(:filters, flop_filters)

    # And here we build the form according to the params
    form =
      cast(%__MODULE__{}, Map.get(params, "filter", %{"timeline" => "current"}), @fields)
      |> Phoenix.Component.to_form()

    with {alerts, meta} <- Alerts.list_all_paginated(flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts, form: form, params: params)}
    end
  end

  @impl true
  def handle_event("paginate-alerts", %{"page" => page}, socket) do
    flop =
      Flop.set_page(socket.assigns.meta.flop, page)

    with {alerts, meta} <- Alerts.list_all_paginated(flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts, scroll_to_top: true)}
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

    timefield =
      Enum.find(socket.assigns.params, fn %{"field" => k, "value" => _v} -> k == "timeline" end)

    new_order_directions =
      if hd(flop.order_by) == :notification_period_end do
        flop.order_directions
        |> Enum.map(&reverse_order_direction(&1))
      else
        lookup_end_time_order_directions_by_params(timefield)
      end

    order_fields = lookup_end_time_order_fields_by_params(timefield)

    flop =
      flop
      |> Map.put(:order_by, order_fields)
      |> Map.put(:order_directions, new_order_directions)

    with {alerts, meta} <- Alerts.list_all_paginated(flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts, scroll_to_top: true)}
    end
  end

  def handle_event("sort-alerts", %{"order" => order}, socket) do
    flop = Flop.push_order(socket.assigns.meta.flop, order)

    new_order_directions =
      flop.order_directions
      |> Enum.map(&if &1 == :desc, do: :desc_nulls_last, else: &1)
      |> Enum.map(&if &1 == :asc, do: :asc_nulls_first, else: &1)

    flop =
      Map.put(flop, :order_directions, new_order_directions)

    with {alerts, meta} <- Alerts.list_all_paginated(flop) do
      {:noreply, assign(socket, meta: meta, alerts: alerts, scroll_to_top: true)}
    end
  end

  ### Filter handlers section ###

  # Drop any changes made while the modal was open. Revert to existing params
  @impl true
  def handle_event("cancel_filter_modal", _params, socket) do
    filters = Map.get(socket.assigns.params, "filter", %{"timeline" => "current"})

    form =
      cast(%__MODULE__{}, filters, @fields)
      |> to_form(action: :validate)

    socket = assign(socket, form: form, scroll_to_top: false)
    {:noreply, socket}
  end

  # On filter change, update the form and validate
  @impl true
  def handle_event("edit_filter", %{"view_alerts_live" => filter_selections}, socket) do
    params = clean_filter_params(filter_selections)

    filters =
      socket.assigns.params
      |> Map.get("filter", %{})
      |> Map.merge(params["filter"])

    form =
      cast(%__MODULE__{}, filters, @fields)
      |> to_form(action: :validate)

    socket =
      socket
      |> assign(form: form, scroll_to_top: false)
      # If any of the selections were adjusted server-side, push those changes back
      # to the client
      |> push_event("adjustSelections", filters)

    {:noreply, socket}
  end

  # On reset filter, if filter id is provided, then reset just that field
  @impl true
  def handle_event("reset_filter", %{"filter-id" => filter_id}, socket) do
    filters =
      socket.assigns.params
      |> Map.get("filter", %{"timeline" => "current"})
      |> Map.drop([filter_id])

    form =
      cast(%__MODULE__{}, filters, @fields)
      |> to_form(action: :validate)

    socket = assign(socket, form: form, scroll_to_top: false)
    {:noreply, socket}
  end

  # On reset filter, if filter id not provided, reset all fields in the modal
  @impl true
  def handle_event("reset_filter", _params, socket) do
    reset_filters =
      socket.assigns.params
      |> Map.get("filter", %{"timeline" => "current"})
      |> Map.take(@other_filter_fields)

    form =
      cast(%__MODULE__{}, reset_filters, @fields)
      |> to_form(action: :validate)

    socket = assign(socket, form: form, scroll_to_top: false)
    {:noreply, socket}
  end

  # Handle clicking the "Reset" button
  @impl true
  def handle_event("apply_filter", %{"reset" => ""}, socket) do
    socket = assign(socket, scroll_to_top: true)
    {:noreply, push_patch(socket, to: ~p"/alerts")}
  end

  # Handle submitting the modal filter or using the search bar
  def handle_event("apply_filter", %{"view_alerts_live" => filter_selections}, socket) do
    # Keep the other existing filters
    filters =
      socket.assigns.params
      |> Map.get("filter", %{})
      |> Map.merge(filter_selections)
      |> Map.filter(fn {_k, v} -> v != "" end)
      # Make sure 'default' and modal search terms don't get pushed to params
      |> remove_unused_params()

    params = %{"filter" => filters}

    socket =
      assign(socket,
        scroll_to_top: true,
        filter_count: get_filter_count(filters)
      )

    {:noreply, push_patch(socket, to: ~p"/alerts?#{params}")}
  end

  # Fallback handler
  def handle_event("apply_filter", _params, socket) do
    socket = assign(socket, scroll_to_top: false)
    {:noreply, socket}
  end

  # Handle submitting a timeline filter change
  def handle_event("update_timeline_filter", %{"value" => value}, socket) do
    filters =
      socket.assigns.params
      |> Map.get("filter", %{})
      |> Map.merge(%{"timeline" => value})

    params = %{"filter" => filters}
    socket = assign(socket, scroll_to_top: true)
    {:noreply, push_patch(socket, to: ~p"/alerts?#{params}")}
  end

  ### END Filter handlers section ###

  ### View Alerts handlers section ###

  @impl true
  def handle_event("open_details", %{"alert_id" => alert_id}, socket) when is_integer(alert_id) do
    alert_data = alert_id |> Integer.to_string() |> AlertData.build_alert_data()

    {:noreply,
     assign(socket,
       selected_alert_data: alert_data,
       selected_alert_id: alert_id,
       scroll_to_top: false
     )}
  end

  @impl true
  def handle_event("open_details", %{"alert_id" => _alert_id}, socket) do
    {:noreply, assign(socket, scroll_to_top: false)}
  end

  @impl true
  def handle_event("close_details", _, socket) do
    {:noreply,
     assign(socket, selected_alert_data: nil, selected_alert_id: nil, scroll_to_top: false)}
  end

  @impl true
  def handle_event("cancelled_close_modal", _params, socket) do
    {:noreply, assign(socket, scroll_to_top: false)}
  end

  @impl true
  def handle_event("edit_alert", %{"alert_id" => alert_id}, socket) do
    socket = assign(socket, scroll_to_top: false)
    {:noreply, push_navigate(socket, to: ~p"/alerts/edit?alert_id=#{alert_id}")}
  end

  @impl true
  def handle_event("duplicate_alert", %{"alert_id" => alert_id}, socket) do
    socket = assign(socket, scroll_to_top: true)
    {:noreply, push_navigate(socket, to: ~p"/alerts/duplicate?alert_id=#{alert_id}")}
  end

  @impl true
  def handle_event("close_alert", %{"value" => alert_id}, socket) do
    alert_id |> Alerts.get_by_alert_id() |> Alerts.close(socket.assigns.current_user)
    # refresh view so alert is displayed in correct timeline category
    Process.send(self(), :update, [])
    socket = assign(socket, scroll_to_top: false)
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "image-preview-size",
        %{"id" => "size-of-image", "image_preview_size" => image_preview_size},
        socket
      ) do
    {:noreply,
     assign(socket,
       scroll_to_top: false,
       selected_alert_data:
         Map.put(socket.assigns.selected_alert_data, :image_preview_size, image_preview_size)
     )}
  end

  ### END View Alerts handlers section ###

  ### Helpers section ###

  def lookup_end_time_order_fields_by_params(%{"field" => "timeline", "value" => "past"}),
    do: [
      :active_period_end,
      :active_period_start
    ]

  def lookup_end_time_order_fields_by_params(_),
    do: [
      :notification_period_end,
      :active_period_end,
      :duration_certainty,
      :active_period_start,
      :notification_period_start
    ]

  def lookup_end_time_order_directions_by_params(%{"field" => "timeline", "value" => "current"}),
    do: [:asc_nulls_last, :asc, :asc_nulls_last, :asc, :asc]

  def lookup_end_time_order_directions_by_params(%{"field" => "timeline", "value" => "future"}),
    do: [:asc_nulls_last, :asc, :asc_nulls_last, :asc, :asc]

  def lookup_end_time_order_directions_by_params(%{"field" => "timeline", "value" => "past"}),
    do: [:desc, :desc]

  def lookup_end_time_order_directions_by_params(%{"field" => "timeline", "value" => _}),
    do: [:desc_nulls_first, :desc, :desc_nulls_first, :desc, :desc]

  def reverse_order_direction(:asc), do: :desc
  def reverse_order_direction(:desc), do: :asc
  def reverse_order_direction(:asc_nulls_last), do: :desc_nulls_first
  def reverse_order_direction(:desc_nulls_last), do: :asc_nulls_first
  def reverse_order_direction(:asc_nulls_first), do: :desc_nulls_last
  def reverse_order_direction(:desc_nulls_first), do: :asc_nulls_last

  @spec clean_filter_params(map()) :: map()
  defp clean_filter_params(params) do
    nonempty_params = Map.filter(params, fn {k, v} -> v != "" || k == "multi_column_search" end)
    %{"filter" => nonempty_params}
  end

  @spec remove_unused_params(map()) :: map()
  defp remove_unused_params(params) do
    Map.filter(params, fn {k, v} -> k in @filter_fields && v != ["default"] end)
  end

  @spec get_filter_count(map()) :: integer
  defp get_filter_count(filters) do
    filters |> Map.drop(@other_filter_fields) |> Map.keys() |> length()
  end

  ### END Helpers section ###

  ### Frontend styling functions ###

  def format_timestamp(timestamp) do
    DateTimeFormatters.timestamp_date_time(timestamp)
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
      DateTimeFormatters.friendly_date_time(start_time_utc, :start)
    end
  end

  def format_end_time(_end_time_utc, :UNKNOWN), do: "further notice"

  def format_end_time(_end_time_utc, :ESTIMATED), do: "later today"

  def format_end_time(nil, :KNOWN), do: ""

  def format_end_time(end_time_utc, :KNOWN) do
    if DateTime.compare(
         ActivePeriod.end_of_service_datetime_utc(DateTime.utc_now()),
         end_time_utc
       ) == :eq do
      "end of service"
    else
      DateTimeFormatters.friendly_date_time(end_time_utc, :end)
    end
  end

  def format_end_time(_, _), do: ""

  def danger_text(active_period_end, closed_timestamp) do
    if DateTimeHelpers.will_be_ending_today?(active_period_end, closed_timestamp) do
      "text-danger"
    else
      ""
    end
  end

  @spec format_effect(nil | binary()) :: binary()
  def format_effect(nil), do: ""

  def format_effect(effect) do
    effect
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", fn s -> String.capitalize(s) end)
  end

  defp sort_icon(:asc) do
    assigns = %{}

    ~H"""
    <.icon name="hero-arrow-up" class="mx-1 h-4 w-4" />
    """
  end

  defp sort_icon(:desc) do
    assigns = %{}

    ~H"""
    <.icon name="hero-arrow-down" class="mx-1 h-4 w-4" />
    """
  end

  defp sort_icon(nil) do
    assigns = %{}

    ~H"""
    <.icon name="hero-arrows-up-down" class="mx-1 h-4 w-4" />
    """
  end

  @spec timeline_filter_past?(any()) :: boolean()
  def timeline_filter_past?(%{
        "filters" => %{"3" => %{"field" => "timeline", "value" => "past"}}
      }),
      do: true

  def timeline_filter_past?(_), do: false

  ### END Frontend styling section ###
end
