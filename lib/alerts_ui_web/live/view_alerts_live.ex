defmodule AlertsUIWeb.ViewAlertsLive do
  @moduledoc """
  LiveView for presenting a list of current alerts.
  """
  use AlertsUIWeb, :live_view
  use AlertsUI.Schema

  import AlertsUIWeb.FilterForm

  alias AlertsUI.Alerts
  alias AlertsUI.Models.{ActivePeriod, Alert}
  alias AlertsUIWeb.CreateAlertLive.Helpers.AlertDataHelpers
  alias AlertsUIWeb.FormComponents.Helpers.{AlertDataBuilder, DateTimeFormatters, DateTimeHelpers}
  alias AlertsUIWeb.FormComponents.Helpers.AutoText.BuildAutoText
  alias AlertsUIWeb.UserHelpers

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

  @fields ~w[timeline multi_column_search service_type service_type_search_term routes routes_search_term effects effects_search_term]a

  @modal_filter_fields ["service_type", "routes", "effects"]
  @other_filter_fields ["multi_column_search", "timeline"]
  @filter_fields @modal_filter_fields ++ @other_filter_fields

  @impl true
  def mount(params, _session, socket) do
    # subscribe to changes in the alerts listing
    if connected?(socket) do
      Phoenix.PubSub.subscribe(AlertsUI.PubSub, "alerts")
      Phoenix.PubSub.subscribe(AlertsUI.PubSub, "paginating")
    end

    filters = Map.get(params, "filter", %{"timeline" => "current"})
    params = params |> Map.put("filter", filters)

    form =
      cast(%__MODULE__{}, filters, @fields)
      |> Phoenix.Component.to_form()

    {:ok,
     assign(socket,
       filter_count: get_filter_count(filters),
       form: form,
       meta: %Flop.Meta{},
       page_title: "View Alerts",
       params: params,
       scroll_to_top: false,
       send_all_clear?: false,
       alerts: [],
       loading: false,
       current_url: "",
       current_close_modal: nil
     )}
  end

  @impl true
  def handle_info({:alerts_updated}, socket) do
    send(self(), {:paginate_start})

    # Whenever an alert is edited or added/deleted, list all the alerts again.
    with {alerts, meta} <- Alerts.list_all_paginated(socket.assigns.meta.flop) do
      send(self(), {:paginate_end})

      {:noreply, assign(socket, meta: meta, alerts: alerts)}
    end
  end

  @impl true
  def handle_info({:paginate_start}, socket) do
    {:noreply, assign(socket, loading: true)}
  end

  @impl true
  def handle_info({:paginate_end}, socket) do
    {:noreply, assign(socket, loading: false)}
  end

  @impl true
  def handle_params(_params, _url, %{transport_pid: nil} = socket) do
    # if this is the dead mount and the socket is not connected
    # we don't need to make the expensive list_all_paginated call
    {:noreply, assign(socket, loading: true)}
  end

  @impl true
  def handle_params(%{"alert_id" => alert_id}, _url, socket) do
    # adding an "alert_id" param opens the details modal if the alert exists
    socket = push_patch(socket, to: ~p"/alerts")

    alert = alert_id |> Alerts.get_by_alert_id()

    if is_nil(alert) do
      {:noreply, socket}
    else
      alert_data =
        alert
        |> AlertDataBuilder.build_alert_data()
        |> AlertDataHelpers.normalize_effect_name()

      {:noreply,
       assign(socket,
         selected_alert_data: alert_data,
         selected_alert_id: alert_id,
         scroll_to_top: false,
         send_all_clear?: not is_nil(alert_data.last_push_notification_timestamp)
       )}
    end
  end

  def handle_params(params, url, socket) do
    # default to timeline: current if params have no values
    # (eg no user input has occurred and we're probably in a fresh reload)
    filters = get_filters(params, "current")
    params = params |> Map.put("filter", filters)
    timefield = filters["timeline"]
    # Process the params to construct the filters in the format Flop needs
    flop_filters = extract_flop_filters(filters)

    default_order_fields = lookup_end_time_order_fields_by_params(timefield)
    default_order_directions = lookup_end_time_order_directions_by_params(timefield)

    order_fields =
      if params["order_by"] in ["", nil] do
        default_order_fields
      else
        order_by = String.to_existing_atom(params["order_by"])
        order_fields = Enum.filter(default_order_fields, &(&1 != order_by))
        [order_by | order_fields]
      end

    order_directions =
      order_directions(
        hd(order_fields),
        params["order_direction"],
        timefield,
        default_order_directions
      )

    # Flop gets updated
    flop =
      socket.assigns.meta.flop
      |> Flop.set_page(params["page"] || "1")
      |> Map.put(:page_size, 50)
      |> Map.put(:filters, flop_filters)
      |> Map.put(:order_by, order_fields)
      |> Map.put(:order_directions, order_directions)

    # And here we build the form according to the params
    form =
      cast(%__MODULE__{}, Map.get(params, "filter", %{"timeline" => "current"}), @fields)
      |> Phoenix.Component.to_form()

    with {alerts, meta} <- Alerts.list_all_paginated(flop) do
      send(self(), {:paginate_end})
      current_url = url |> String.split("?") |> hd

      {:noreply,
       assign(socket,
         meta: meta,
         alerts: alerts,
         form: form,
         params: params,
         current_url: current_url
       )}
    end
  end

  @impl true
  def handle_event("paginate_start", _params, socket) do
    {:noreply, assign(socket, loading: true)}
  end

  @impl true
  def handle_event("paginate-alerts", %{"page" => page}, socket) do
    flop =
      Flop.set_page(socket.assigns.meta.flop, page)

    with {alerts, meta} <- Alerts.list_all_paginated(flop) do
      send(self(), {:paginate_end})

      params = Map.merge(socket.assigns.params, %{"page" => page})

      {:noreply,
       socket
       |> assign(meta: meta, alerts: alerts, scroll_to_top: true)
       |> push_patch(to: ~p"/alerts?#{params}")}
    end
  end

  def handle_event("sort-alerts", %{"order" => order}, socket) do
    params =
      put_order_in_params(socket, order)
      |> Map.delete("page")

    socket = assign(socket, scroll_to_top: true)
    {:noreply, push_patch(socket, to: ~p"/alerts?#{params}")}
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

  # Reset only the text filter
  @impl true
  def handle_event("reset_text_filter", _params, socket) do
    handle_event("apply_filter", %{"view_alerts_live" => %{"multi_column_search" => ""}}, socket)
  end

  # Reset only the modal filters
  @impl true
  def handle_event("reset_modal_filters", _params, socket) do
    handle_event(
      "apply_filter",
      %{
        "view_alerts_live" =>
          @modal_filter_fields |> Enum.reduce(%{}, fn name, acc -> Map.put(acc, name, "") end)
      },
      socket
    )
  end

  # On reset filter, if filter id is provided, then reset just that field
  @impl true
  def handle_event("reset_filter", %{"filter-id" => filter_id}, socket) do
    filters = Map.drop(socket.assigns.form.params, [filter_id])

    form =
      cast(%__MODULE__{}, filters, @fields)
      |> to_form(action: :validate)

    socket =
      assign(socket,
        params: socket.assigns.params |> Map.merge(%{"filter" => filters}),
        form: form,
        scroll_to_top: false
      )

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

  # This is for all of the search bars inside the "Filters" modal
  @impl true
  def handle_event("reset_search_filter", %{"name" => name}, socket) do
    # The name will come back as i.e. "affected_service[route_search_term]" but we only want "route_search_term"
    search_filter_name = hd(Regex.run(~r/\[(.*?)\]/, name, capture: :all_but_first))

    updated_form =
      socket.assigns.form.params
      |> Map.merge(%{search_filter_name => ""})

    form =
      cast(%__MODULE__{}, updated_form, @fields)
      |> to_form(action: :validate)

    socket =
      socket
      |> assign(form: form)

    {:noreply, socket}
  end

  # Handle clicking the "Reset" button
  @impl true
  def handle_event("apply_filter", %{"reset" => ""}, socket) do
    socket = assign(socket, filter_count: 0, scroll_to_top: true)
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

    # Remove 'page' to go back to the first page with the new applied filter
    params = Map.merge(Map.drop(socket.assigns.params, ["page"]), %{"filter" => filters})

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
    alert = alert_id |> Integer.to_string() |> Alerts.get_by_alert_id()

    if is_nil(alert) do
      {:noreply, socket}
    else
      alert_data =
        alert
        |> AlertDataBuilder.build_alert_data()
        |> AlertDataHelpers.normalize_effect_name()

      {:noreply,
       assign(socket,
         selected_alert_data: alert_data,
         selected_alert_id: alert_id,
         scroll_to_top: false,
         send_all_clear?: not is_nil(alert_data.last_push_notification_timestamp)
       )}
    end
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
  def handle_event("all_clear_checkbox", %{"value" => send_all_clear?}, socket) do
    {:noreply, assign(socket, send_all_clear?: send_all_clear?)}
  end

  @impl true
  def handle_event("all_clear_checkbox", %{}, socket) do
    {:noreply, assign(socket, send_all_clear?: false)}
  end

  @impl true
  def handle_event("cancelled_close_modal", _params, socket) do
    {:noreply, assign(socket, scroll_to_top: false, current_close_modal: nil)}
  end

  @impl true
  def handle_event("edit_alert", %{"alert_id" => alert_id}, socket) do
    socket = assign(socket, scroll_to_top: false)

    {:noreply, push_navigate(socket, to: form_path_edit(alert_id))}
  end

  @impl true
  def handle_event("duplicate_alert", %{"alert_id" => alert_id}, socket) do
    socket = assign(socket, scroll_to_top: true)

    {:noreply, push_navigate(socket, to: form_path_duplicate(alert_id))}
  end

  @impl true
  def handle_event("close_alert", %{"value" => alert_id}, socket) do
    alert_id
    |> Alerts.get_by_alert_id()
    |> Alerts.close(socket.assigns.current_user, socket.assigns.send_all_clear?)

    socket =
      assign(socket, scroll_to_top: false, selected_alert_data: nil, selected_alert_id: nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "image-preview-size",
        %{"id" => "size-of-image", "image_preview_size" => image_preview_size},
        %{assigns: %{selected_alert_data: selected_alert_data}} = socket
      )
      when is_map(selected_alert_data) do
    {:noreply,
     assign(socket,
       scroll_to_top: false,
       selected_alert_data: Map.put(selected_alert_data, :image_preview_size, image_preview_size)
     )}
  end

  @impl true
  def handle_event("image-preview-size", _data, socket), do: {:noreply, socket}

  @impl true
  def handle_event(
        "opening_close_modal",
        %{"send_all_clear?" => send_all_clear?, "alert_id" => alert_id},
        socket
      ) do
    {:noreply, assign(socket, send_all_clear?: send_all_clear?, current_close_modal: alert_id)}
  end

  ### END View Alerts handlers section ###

  ### Helpers section ###

  defp get_filters(params, default_timeline),
    do:
      params
      |> Map.get("filter", %{})
      |> Map.put_new("timeline", default_timeline)

  defp get_timeline(params),
    do:
      params
      |> get_filters("current")
      |> Map.get("timeline")

  defp extract_flop_filters(filters),
    do:
      filters
      |> Enum.map(fn
        {_, ""} -> nil
        {k, v} -> %{"field" => k, "value" => v}
      end)
      |> Enum.filter(&(&1 != nil))

  defp current_order_param(flop),
    do:
      flop.order_by
      |> hd()
      |> Atom.to_string()

  defp opposite_current_direction_param(flop),
    do:
      flop.order_directions
      |> hd()
      |> reverse_order_direction()
      |> stringify_order_direction()

  defp default_direction_param(timeline),
    do:
      timeline
      |> lookup_end_time_order_directions_by_params()
      |> hd()
      |> stringify_order_direction()

  def lookup_end_time_order_fields_by_params("past"),
    do: [
      :active_period_end,
      :active_period_start,
      # As a final deterministic deciding factor, just in case.
      :integer_alert_id
    ]

  def lookup_end_time_order_fields_by_params(_),
    do: [
      :notification_period_end,
      :active_period_end,
      :duration_certainty,
      :active_period_start,
      :notification_period_start,
      # As a final deterministic deciding factor, just in case.
      :integer_alert_id
    ]

  def lookup_end_time_order_directions_by_params("current"),
    do: [:asc_nulls_last, :asc, :asc_nulls_last, :asc, :asc, :asc]

  def lookup_end_time_order_directions_by_params("future"),
    do: [:asc_nulls_last, :asc, :asc_nulls_last, :asc, :asc, :asc]

  def lookup_end_time_order_directions_by_params("past"),
    do: [:desc, :desc, :asc]

  def lookup_end_time_order_directions_by_params(_),
    do: [:desc_nulls_first, :desc, :desc_nulls_first, :desc, :desc, :asc]

  def reverse_order_direction(:asc), do: :desc
  def reverse_order_direction(:desc), do: :asc
  def reverse_order_direction(:asc_nulls_last), do: :desc_nulls_first
  def reverse_order_direction(:desc_nulls_last), do: :asc_nulls_first
  def reverse_order_direction(:asc_nulls_first), do: :desc_nulls_last
  def reverse_order_direction(:desc_nulls_first), do: :asc_nulls_last

  def stringify_order_direction(:asc), do: "asc"
  def stringify_order_direction(:desc), do: "desc"
  def stringify_order_direction(:asc_nulls_last), do: "asc"
  def stringify_order_direction(:desc_nulls_last), do: "desc"
  def stringify_order_direction(:asc_nulls_first), do: "asc"
  def stringify_order_direction(:desc_nulls_first), do: "desc"

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

  @spec put_order_in_params(map(), String.t()) :: map()
  defp put_order_in_params(socket, order) do
    current_order = current_order_param(socket.assigns.meta.flop)
    opposite_current_direction = opposite_current_direction_param(socket.assigns.meta.flop)
    timeline = get_timeline(socket.assigns.params)
    default_direction = default_direction_param(timeline)

    {order, direction} =
      cond do
        order == current_order ->
          {order, opposite_current_direction}

        order in ["active_period_end", "notification_period_end"] ->
          {order, default_direction}

        true ->
          {order, "asc"}
      end

    socket.assigns.params
    |> Map.merge(%{"order_by" => order, "order_direction" => direction})
  end

  defp order_directions(:active_period_end, "asc", _, directions),
    do: directions |> Enum.map(&reverse_order_direction/1)

  defp order_directions(:active_period_end, _, _, directions),
    do: directions

  defp order_directions(:notification_period_end, "asc", "all", directions),
    do: directions |> Enum.map(&reverse_order_direction/1)

  defp order_directions(:notification_period_end, _, "all", directions),
    do: directions

  defp order_directions(:notification_period_end, "desc", _, directions),
    do: directions |> Enum.map(&reverse_order_direction/1)

  defp order_directions(:notification_period_end, _, _, directions),
    do: directions

  defp order_directions(_, direction, _, _),
    do: [String.to_existing_atom(direction || "asc")]

  def form_path_new do
    "/alerts/new"
  end

  def form_path_edit(alert_id) do
    "/alerts/edit/#{alert_id}"
  end

  def form_path_duplicate(alert_id) do
    "/alerts/duplicate/#{alert_id}"
  end

  ### END Helpers section ###

  ### Frontend styling functions ###
  def safe_format_timestamp(timestamp, certainty \\ :KNOWN, opts \\ %{}) do
    format_timestamp(timestamp, certainty, opts)
  rescue
    exception ->
      Logger.error("Error formatting time: #{Exception.message(exception)}")
      "ERROR"
  end

  defp format_timestamp(timestamp, certainty, opts)

  defp format_timestamp(_, :UNKNOWN, %{
         can_close_automatically: true,
         primary_service_type: "access",
         effect_name: "Elevator Closure"
       }),
       do: "When work order is closed in Trapeze"

  defp format_timestamp(_, :UNKNOWN, %{
         can_close_automatically: true,
         primary_service_type: "access",
         effect_name: "Escalator Closure"
       }),
       do: "When work order is closed in Trapeze"

  defp format_timestamp(timestamp, _, _) do
    DateTimeFormatters.timestamp_date_time(timestamp)
  end

  def safe_format_start_time(start_time_utc) do
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
  rescue
    exception ->
      Logger.error("Error formatting start time: #{Exception.message(exception)}")
      "ERROR"
  end

  def safe_format_end_time(end_time_utc, certainty, opts \\ %{}) do
    format_end_time(end_time_utc, certainty, opts)
  rescue
    exception ->
      Logger.error("Error formatting end time: #{Exception.message(exception)}")
      "ERROR"
  end

  defp format_end_time(end_time_utc, certainty, opts)

  defp format_end_time(end_time_utc, :KNOWN, _) do
    if DateTime.compare(
         ActivePeriod.end_of_service_datetime_utc(DateTime.utc_now()),
         end_time_utc
       ) == :eq do
      "end of service"
    else
      DateTimeFormatters.friendly_date_time(end_time_utc, :end)
    end
  end

  defp format_end_time(_, _, %{
         can_close_automatically: true,
         primary_service_type: "access",
         effect_name: "Elevator Closure"
       }),
       do: "from Trapeze"

  defp format_end_time(_, _, %{
         can_close_automatically: true,
         primary_service_type: "access",
         effect_name: "Escalator Closure"
       }),
       do: "from Trapeze"

  defp format_end_time(_, :UNKNOWN, _), do: "further notice"
  defp format_end_time(_, :ESTIMATED, _), do: "later today"
  defp format_end_time(_, _, _), do: ""

  def danger_text(active_period_end, closed_timestamp) do
    if DateTimeHelpers.will_be_ending_today?(active_period_end, closed_timestamp) do
      "text-text-danger"
    else
      ""
    end
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
        "filter" => %{"timeline" => "past"}
      }),
      do: true

  def timeline_filter_past?(_), do: false

  ### END Frontend styling section ###
end
