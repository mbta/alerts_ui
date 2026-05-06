defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.StopRouteServiceSlice do
  alias Phoenix.LiveView.AsyncResult

  alias AlertsUI.Models.Alert
  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertLive
  alias AlertsUIWeb.CreateAlertMonoLive.Helpers.SelectFormatter
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.FormComponents.AffectedService
  alias AlertsUIWeb.FormComponents.Helpers.ContentFormatter

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.API, only: [async_available?: 1]
  import AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertData, only: [humanize_effect_name: 1]

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.SelectFormatter,
    only: [formatted_select_options: 1]

  use AlertsUIWeb, :html

  defstruct [
    :direction,
    :facility_ids,
    :original_direction_selections,
    :original_facility_selections,
    :original_route_selections,
    :original_stop_selections,
    :original_trip_selections,
    :route_ids,
    :service_types
  ]


  defmodule Selections do
    defstruct [
      available_filter_routes: AsyncResult.loading(),
      available_routes: AsyncResult.loading(),
      available_stops: AsyncResult.loading(),
      filter_title_value: "All routes",
      disable_routes_input?: true,
      modal_route_id_options: [],
      retained_stops: [],
      route_id_options: [],
      selected_stops: [],
      selected_route_id: nil,
      show_stop_ids?: true,
      stop_id_options: []
    ]
  end

  defimpl Slice, for: __MODULE__ do
    def extract(service_data, %Alert{} = alert, _params) do
      struct(service_data, Map.from_struct(alert))
    end

    def transform(_service_data, changeset, _params) do
      changeset
    end

    def validate(_service_data, changeset, _params) do
      changeset
    end

    def assigns(_service_data, socket, _params) do
      # update selections here
      assign_selections(socket)
    end

    defp assign_selections(socket) do
      assign(socket, :selections, %Selections{})
    end

    defp get_selections(route_type, stop_ids) do
      %Selections{
        available_filter_routes: CreateAlertLive.get_routes(route_type),
        available_routes: CreateAlertLive.get_routes_by_stop(stop_ids, route_type),
        available_stops: CreateAlertLive.get_stops_by_route_id()
      }
    end

    defp fetch_filter_routes(route_type) do
      CreateAlertLive.get_routes(route_type)
    end

    defp fetch_routes(route_type, stop_ids) do
      CreateAlertLive.get_routes_by_stop(stop_ids, route_type)
    end

    defp fetch_stops(route_type, route_ids) do
      CreateAlertLive.get_stops_for_stop_route(route_ids, route_type)
    end
  end

  def render(
        %{
          form: form,
          selections: %Selections{
            available_filter_routes: available_filter_routes,
            available_routes: available_routes,
            available_stops: available_stops,
            selected_stops: selected_stops,
            selected_route_id: selected_route_id
          }
        } = assigns
      ) do
    # Route filter
    route_type = form[:route_type].value
    modal_route_search_term = form[:modal_route_search_term].value
    modal_route_id = form[:modal_route_id].value || ""
    filter_routes = Map.get(available_filter_routes, :result) || []

    modal_route_id_options =
      modal_route_id_options(
        filter_routes,
        modal_route_search_term,
        route_type,
        modal_route_id
      )

    # Stop selector
    stop_search_term = form[:stop_search_term].value
    stop_ids = form[:stop_ids].value || []

    # Yeah this is weird. Basically, available_stops might be filtered down by route and sorted by stop order,
    # so we have to carefully preserve already selected stops.
    stop_id_options =
      stop_id_options(
        available_stops,
        selected_stops,
        stop_search_term,
        route_type,
        stop_ids
      )

    retained_stops = AffectedService.extract_selections(form, stop_id_options)

    # Impacted routes selector
    route_search_term = form[:route_search_term].value
    route_ids = form[:route_ids].value || []

    route_id_options =
      route_id_options(
        available_routes,
        route_ids,
        route_search_term,
        route_type
      )

    assigns =
      assign(assigns,
        route_id_options: route_id_options,
        stop_id_options: stop_id_options,
        modal_route_id_options: modal_route_id_options,
        retained_stops: retained_stops
      )

    ~H"""
    <div class="min-w-full flex flex-col" id="stop_route_service_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Affected service
      </.h5>
      <.modal
        id="routes-filter-modal"
        header_text="Filter by route"
        cancel_event_name="cancelled_modal"
        accept_event_name="accepted_routes_modal"
        accept_button_text="Apply"
        target_id="#service_form"
      >
        <.filtered_select
          label="Routes"
          field={@form[:modal_route_id]}
          filter_field={@form[:modal_route_search_term]}
          options={@selections.modal_route_id_options}
          loading={@selections.available_filter_routes.loading}
          no_results={Enum.empty?(@modal_route_id_options)}
          class="h-[32rem]"
          prompt="All routes"
          multiple={false}
        />
      </.modal>

      <.filtered_select
        class="md:w-[25%]"
        field={@form[:stop_ids]}
        filter_field={@form[:stop_search_term]}
        selected={@selections.retained_stops}
        label="Stops"
        loading={Map.get(@selections.available_stops, :loading, true)}
        modal_filter_active={@selections.selected_route_id}
        modal_filter_id="routes-filter-modal"
        modal_filter_title={"Filter: #{@selections.filter_title_value}"}
        no_results={Enum.empty?(@selections.stop_id_options)}
        options={@selections.stop_id_options}
        target_id="#service_form"
      />

      <.filtered_select
        label="Impacted routes"
        field={@form[:route_ids]}
        filter_field={@form[:routes_search_term]}
        loading={Map.get(@selections.available_routes, :loading, true)}
        no_results={Enum.empty?(@selections.route_id_options) && @selections.disable_routes_input?}
        disabled={@selections.disable_routes_input?}
        options={@selections.route_id_options}
        class="md:w-[25%]"
      />
      <p :if={@selections.show_stop_ids?}>
        Selected stop ids: {(@form[:stop_ids].value || []) |> Enum.join(", ")}
      </p>
      <hr class="mt-4" />
    </div>
    """
  end

  def render(%{form: form} = assigns) do
    assign(assigns, :selections, %Selections{}) |> render()
  end

  @spec disable_routes_input?(map()) :: boolean()
  defp disable_routes_input?(%{form: form}) do
    form[:stop_ids].value in [nil, []]
  end

  defp get_selected_stops(nil, _), do: nil
  defp get_selected_stops(_, nil), do: nil

  defp get_selected_stops(available_stops, stop_ids) do
    Enum.filter(available_stops, &(&1.id in stop_ids))
  end

  defp get_selected_routes(nil, _), do: nil
  defp get_selected_routes(_, nil), do: nil

  defp get_selected_routes(available_routes, route_ids) do
    available_routes
    |> Enum.reduce([], fn {route_id, route}, acc ->
      if route_id in route_ids do
        acc ++ List.wrap(route)
      else
        acc
      end
    end)
    |> List.flatten()
  end

  defp modal_route_id_options(
         filter_routes,
         modal_route_search_term,
         route_type,
         modal_route_id
       ) do
    SelectFormatter.formatted_select_options(%SelectFormatter{
      options: filter_routes,
      search_term: modal_route_search_term,
      route_type: route_type,
      values_to_keep: modal_route_id |> List.wrap(),
      option_prefix: "route-filter"
    })
  end

  def stop_id_options(
        available_stops,
        selected_stops,
        stop_search_term,
        route_type,
        stop_ids
      ) do
    # Yeah this is weird. Basically, available_stops might be filtered down by route and sorted by stop order,
    # so we have to carefully preserve already selected stops.
    if async_available?(available_stops) do
      # Available stops will only include the stops visible with the given route filter
      # And now just a list of stop ids
      available_stop_ids = Enum.map(available_stops.result, fn stop -> stop.id end)

      # Get all the stops that were selected but are no longer included in `available_stops`
      # Then append them to the top of the list
      previously_selected_stops =
        Enum.filter(selected_stops, fn stop -> stop.id not in available_stop_ids end)

      options = previously_selected_stops ++ available_stops.result

      SelectFormatter.formatted_select_options(%SelectFormatter{
        options: options,
        search_term: stop_search_term,
        route_type: route_type,
        values_to_keep: stop_ids,
        option_prefix: "stop-selector"
      })
    else
      []
    end
  end

  defp route_id_options(
         available_routes,
         route_ids,
         route_search_term,
         route_type
       ) do
    SelectFormatter.formatted_select_options(%SelectFormatter{
      options: Map.get(available_routes, :result, []) || [],
      search_term: route_search_term,
      route_type: route_type,
      values_to_keep: route_ids,
      option_prefix: "route-selector"
    })
  end
end
