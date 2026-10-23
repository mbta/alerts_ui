defmodule AlertsUIWeb.CreateAlertLive.Slices.StopRouteServiceSlice do
  @moduledoc """
  Slice that handles stop and route selection for bus/subway/ferry/commuter-rail
  alerts. Asynchronously loads available stops, routes, and filter options, and
  renders the dual filtered-select UI with optional route-filter modal.
  """

  alias AlertsUI.Models.Alert
  alias AlertsUIWeb.CreateAlertHelpers
  alias AlertsUIWeb.CreateAlertLive.AlertData
  alias AlertsUIWeb.CreateAlertLive.Helpers.SelectFormatter
  alias AlertsUIWeb.CreateAlertLive.Slice

  import AlertsUIWeb.CreateAlertLive.Helpers.Validation,
    only: [always_validate_required: 3]

  import Ecto.Changeset
  import Phoenix.LiveView, only: [start_async: 3]

  use AlertsUIWeb, :html

  defstruct [
    :direction,
    :facility_ids,
    :modal_route_id,
    :modal_route_search_term,
    :original_direction_selections,
    :original_facility_selections,
    :original_route_selections,
    :original_stop_selections,
    :original_trip_selections,
    :route_ids,
    :route_search_term,
    :service_types,
    :stop_names_and_ids,
    :stop_search_term
  ]

  defmodule Selections do
    @moduledoc "Holds async-loaded route and stop option lists for `StopRouteServiceSlice`."

    alias AlertsUIWeb.CreateAlertLive.Slices.StopRouteServiceSlice

    defstruct available_filter_routes: nil,
              available_routes: nil,
              available_stops: nil,
              filter_title_value: "All routes",
              modal_route_id_options: [],
              on_filter_accept: &StopRouteServiceSlice.on_filter_accept/1,
              on_filter_clear: &StopRouteServiceSlice.on_filter_clear/1,
              retained_stops: [],
              route_id_options: [],
              selected_stops: [],
              selected_route_id: nil,
              show_stop_ids?: false,
              stop_id_options: [],
              loading: false,
              pending_auto_select_route_ids: nil
  end

  defimpl Slice, for: __MODULE__ do
    alias AlertsUIWeb.CreateAlertLive.Slices.StopRouteServiceSlice

    def mount(_service_data, socket, _base_params), do: socket

    def extract(service_data, %AlertData{} = _alert_data, _params) do
      service_data
    end

    def transform(_service_data, changeset, _params, _socket) do
      changeset |> add_stop_ids_to_changeset()
    end

    def validate(_service_data, changeset, _params, socket) do
      if socket.assigns.submitting? do
        changeset
        |> always_validate_required(:stop_names_and_ids, "Select stop(s)")
        |> maybe_validate_route()
      else
        changeset
      end
    end

    defp add_stop_ids_to_changeset(changeset) do
      stop_ids =
        get_field(changeset, :stop_names_and_ids)
        |> Alert.get_original_ids()

      cast(changeset, %{stop_ids: stop_ids}, [:stop_ids])
    end

    defp maybe_validate_route(changeset) do
      if changeset.errors === [] do
        changeset
        |> always_validate_required(:route_ids, "You must select a route")
      else
        changeset
      end
    end

    def assigns(_service_data, socket, params) do
      # update selections here
      StopRouteServiceSlice.async_assign_selections(socket, params)
    end
  end

  def async_assign_selections(%{assigns: %{} = assigns} = socket, params) do
    if update_selections?(params) do
      update_selections(socket, params)
    else
      dont_update_selections(Map.get(assigns, :selections), socket)
    end
  end

  def async_assign_selections(socket, _params), do: socket

  defp update_selections(
         socket,
         %{"_target" => ["alert_data", "route_search_term"]}
       ) do
    prev = prev(Map.get(socket.assigns, :selections))

    route_id_options =
      route_id_options(
        prev.available_routes,
        socket.assigns.form
      )

    socket
    |> assign(:selections, %{prev | route_id_options: route_id_options})
  end

  defp update_selections(
         socket,
         %{"_target" => ["alert_data", "stop_search_term"]}
       ) do
    prev = prev(Map.get(socket.assigns, :selections))

    stop_id_options =
      stop_id_options(
        prev.available_stops,
        socket.assigns.form
      )

    socket
    |> assign(:selections, %{prev | stop_id_options: stop_id_options})
  end

  defp update_selections(
         socket,
         %{"_target" => ["alert_data", "modal_route_search_term"]}
       ) do
    prev = prev(Map.get(socket.assigns, :selections))

    modal_route_id_options =
      modal_route_id_options(
        prev.available_filter_routes,
        socket.assigns.form
      )

    socket
    |> assign(:selections, %{prev | modal_route_id_options: modal_route_id_options})
  end

  defp update_selections(socket, params) do
    assigns = socket.assigns
    prev = prev(Map.get(assigns, :selections))

    auto_select_routes = match?(%{"_target" => ["alert_data", "stop_names_and_ids"]}, params)

    form = assigns.form
    modal_route_id = form[:modal_route_id].value
    route_type = form[:route_type].value
    stop_names_and_ids = form[:stop_names_and_ids].value || []

    stop_route_ids = stop_route_ids(modal_route_id)

    prev_selected_stops = prev_selected_stops(prev)

    route_type_for_filter =
      if route_type in [0, 1] do
        [0, 1]
      else
        route_type
      end

    socket
    |> assign(:selections, %{prev | loading: true})
    |> start_async(:fetch_selections, fn ->
      available_filter_routes = CreateAlertHelpers.get_routes(route_type_for_filter)

      available_stops = CreateAlertHelpers.get_stops_for_stop_route(stop_route_ids, route_type)

      stop_ids = Alert.get_original_ids(stop_names_and_ids)
      available_routes = CreateAlertHelpers.get_routes_by_stop(stop_ids, route_type)

      available_stop_ids = Enum.map(available_stops, fn stop -> stop.id end)

      # Get all the stops that were selected but are no longer included in `available_stops`
      # Then append them to the top of the list so that stops hidden by a route filter
      # are still tracked as selected.
      previously_selected_stops =
        Enum.filter(prev_selected_stops, fn stop -> stop.id not in available_stop_ids end)

      candidate_stops = previously_selected_stops ++ available_stops

      selected_stops = get_selected_stops(candidate_stops, stop_ids)

      modal_route_id_options =
        modal_route_id_options(available_filter_routes, form)

      route_id_options =
        route_id_options(available_routes, form)

      stop_id_options =
        stop_id_options(candidate_stops, form)

      filter_title_value = filter_title_value(modal_route_id, available_filter_routes)

      pending_auto_select_route_ids =
        if auto_select_routes, do: Enum.map(available_routes, & &1.id), else: nil

      %Selections{
        available_filter_routes: available_filter_routes,
        available_routes: available_routes,
        available_stops: candidate_stops,
        filter_title_value: filter_title_value,
        modal_route_id_options: modal_route_id_options,
        route_id_options: route_id_options,
        selected_route_id: modal_route_id,
        selected_stops: selected_stops,
        stop_id_options: stop_id_options,
        pending_auto_select_route_ids: pending_auto_select_route_ids
      }
    end)
  end

  defp dont_update_selections(nil, socket), do: assign(socket, :selections, %Selections{})
  defp dont_update_selections(_selections, socket), do: socket

  defp prev(%Selections{} = selections), do: selections
  defp prev(_), do: %Selections{}

  defp stop_route_ids(nil), do: nil
  defp stop_route_ids("default"), do: nil
  defp stop_route_ids(modal_route_id), do: [modal_route_id]

  defp prev_selected_stops(%Selections{selected_stops: stops}) when is_list(stops) do
    stops
  end

  defp prev_selected_stops(_prev), do: []

  defp filter_title_value(modal_route_id, _) when modal_route_id in [nil, ""] do
    "All routes"
  end

  defp filter_title_value(modal_route_id, available_filter_routes) do
    available_filter_routes
    |> Enum.find(&(&1.id == modal_route_id))
    |> case do
      nil -> "All routes"
      route -> SelectFormatter.name_for_option(route)
    end
  end

  defp modal_route_id_options(filter_routes, form) do
    SelectFormatter.formatted_select_options(%SelectFormatter{
      options: filter_routes,
      search_term: form[:modal_route_search_term].value,
      route_type: form[:route_type].value,
      values_to_keep: form[:modal_route_id].value |> List.wrap(),
      option_prefix: "route-filter"
    })
  end

  def stop_id_options(available_stops, form) do
    SelectFormatter.formatted_select_options(
      %SelectFormatter{
        options: available_stops,
        search_term: form[:stop_search_term].value,
        route_type: form[:route_type].value,
        values_to_keep: form[:stop_names_and_ids].value || [],
        option_prefix: "stop-selector"
      },
      true
    )
  end

  def route_id_options(available_routes, form) do
    SelectFormatter.formatted_select_options(%SelectFormatter{
      options: available_routes,
      search_term: form[:route_search_term].value,
      route_type: form[:route_type].value,
      values_to_keep: form[:route_ids].value || [],
      option_prefix: "route-selector"
    })
  end

  @update_selection_targets [
    "stop_names_and_ids",
    "route_ids",
    "route_search_term",
    "stop_search_term",
    "modal_route_search_term"
  ]

  defp update_selections?(%{"_target" => ["alert_data", field]})
       when field in @update_selection_targets,
       do: true

  # ...but not on any other user interaction...
  defp update_selections?(%{"_target" => _target}), do: false
  # ...also not on auto-route selection (which does not send a _target)...
  defp update_selections?(%{"alert_data" => %{"route_ids" => _ids}}), do: false
  # ...and always on mount, when there is no target, or if we pass in
  # %{} to force a rerender, say when a modal is accepted
  defp update_selections?(_), do: true

  def render(assigns) do
    ~H"""
    <div class="min-w-full flex flex-col" id="stop_route_service_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Affected service
      </.h5>
      <.modal
        id="routes-filter-modal"
        header_text="Filter by route"
        cancel_event_name="cancel_filter"
        accept_event_name="accept_filter"
        accept_button_text="Apply"
        target_id="#alert_form"
      >
        <.filtered_select
          label="Routes"
          field={@form[:modal_route_id]}
          filter_field={@form[:modal_route_search_term]}
          options={@selections.modal_route_id_options}
          loading={@selections.loading}
          no_results={Enum.empty?(@selections.modal_route_id_options)}
          class="h-[32rem]"
          prompt="All routes"
          multiple={false}
        />
      </.modal>

      <div class="md:flex md:flex-row gap-x-8 mb-4 h-[32rem]">
        <.filtered_select
          class="md:w-[25%]"
          field={@form[:stop_names_and_ids]}
          filter_field={@form[:stop_search_term]}
          selected={@form[:stop_names_and_ids].value}
          label="Stops"
          loading={@selections.loading && @first_async_load}
          first_async_load={@first_async_load}
          modal_filter_active={!(@selections.selected_route_id in [nil, "default"])}
          modal_filter_id="routes-filter-modal"
          modal_filter_title={"Filter: #{@selections.filter_title_value}"}
          no_results={Enum.empty?(@selections.stop_id_options)}
          options={@selections.stop_id_options}
          target_id="#alert_form"
        />

        <.filtered_select
          label="Impacted routes"
          field={@form[:route_ids]}
          filter_field={@form[:route_search_term]}
          loading={@selections.loading}
          no_results={
            Enum.empty?(@selections.route_id_options) &&
              !Enum.empty?(@form[:stop_names_and_ids].value || []) &&
              disable_routes_input?(@form)
          }
          disabled={disable_routes_input?(@form)}
          options={if @selections.loading, do: [], else: @selections.route_id_options}
          class="md:w-[25%]"
        />
      </div>
      <p :if={@show_stop_ids}>
        Selected stop ids: {(@form[:stop_names_and_ids].value || []) |> Enum.join(", ")} Selected route ids:{(@form[
                                                                                                                :route_ids
                                                                                                              ].value ||
                                                                                                                [])
        |> Enum.join(", ")}
      </p>
      <hr class="mt-4" />
    </div>
    """
  end

  @spec disable_routes_input?(map()) :: boolean()
  defp disable_routes_input?(form) do
    form[:stop_names_and_ids].value in [nil, []]
  end

  defp get_selected_stops(available_stops, stop_ids) do
    Enum.filter(available_stops, &(&1.id in stop_ids))
  end

  def on_filter_accept(socket) do
    async_assign_selections(socket, %{})
  end

  def on_filter_clear(socket) do
    {_, socket} =
      AlertData.sync(socket.assigns.form.source, socket, %{
        "alert_data" => %{"modal_route_id" => nil, "modal_route_search_term" => nil}
      })

    async_assign_selections(socket, %{})
  end
end
