defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.StopRouteServiceSlice do
  alias Phoenix.LiveView.AsyncResult

  alias AlertsUI.Models.Alert
  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertLive
  alias AlertsUIWeb.CreateAlertMonoLive.Helpers.SelectFormatter
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.FormComponents.AffectedService
  alias AlertsUIWeb.FormComponents.Helpers.ContentFormatter

  alias AlertsUIWeb.CreateAlertLive

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.API, only: [async_available?: 1]
  import AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertData, only: [humanize_effect_name: 1]

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.SelectFormatter,
    only: [formatted_select_options: 1]

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.Selections,
    only: [assign_unwrapped_selections: 2]

  import Phoenix.LiveView, only: [assign_async: 3]

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
    :stop_ids,
    :stop_search_term
  ]

  defmodule Selections do
    defstruct available_filter_routes: AsyncResult.loading(),
              available_routes: AsyncResult.loading(),
              available_stops: AsyncResult.loading(),
              filter_title_value: "All routes",
              disable_routes_input?: false,
              modal_route_id_options: [],
              retained_stops: [],
              route_id_options: [],
              selected_stops: [],
              selected_route_id: nil,
              show_stop_ids?: true,
              stop_id_options: [],
              loading: true
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

    def assigns(_service_data, socket, params) do
      # update selections here
      async_assign_selections(socket, params)
    end

    defp async_assign_selections(socket, params) do
      if update_selections?(params) do
        form = socket.assigns.form
        modal_route_search_term = form[:modal_route_search_term].value
        modal_route_id = form[:modal_route_id].value
        route_ids = form[:route_ids].value
        route_search_term = form[:route_search_term].value
        route_type = form[:route_type].value
        stop_ids = form[:stop_ids].value || []
        stop_search_term = form[:stop_search_term].value

        stop_route_ids =
          case modal_route_id do
            nil -> route_ids
            modal_route_id -> [modal_route_id]
          end

        selected_stops =
          case Map.get(socket.assigns, :selections) do
            nil -> []
            %AsyncResult{ok?: true} = async_ok -> async_ok.result.selected_stops
            %Selections{} = selections -> selections.selected_stops
          end

        assign_async(socket, :selections, fn ->
          available_filter_routes = CreateAlertLive.get_routes(route_type)
          available_stops = CreateAlertLive.get_stops_for_stop_route(stop_route_ids, route_type)
          available_routes = CreateAlertLive.get_routes_by_stop(stop_ids, route_type)

          modal_route_id_options =
            modal_route_id_options(
              available_filter_routes,
              modal_route_search_term,
              route_type,
              modal_route_id
            )

          route_id_options =
            route_id_options(
              available_routes,
              route_ids,
              route_search_term,
              route_type
            )

          stop_id_options =
            stop_id_options(
              available_stops,
              selected_stops,
              stop_search_term,
              route_type,
              stop_ids
            )

          selections = %Selections{
            available_filter_routes: available_filter_routes,
            available_routes: available_routes,
            available_stops: available_stops,
            modal_route_id_options: modal_route_id_options,
            route_id_options: route_id_options,
            selected_route_id: modal_route_id,
            selected_stops: selected_stops,
            stop_id_options: stop_id_options
          }

          {:ok, %{selections: selections}}
        end)
        |> assign(:selections, %Selections{})
      else
        case Map.get(socket.assigns, :selections) do
          nil ->
            assign(socket, :selections, %Selections{})

          _ ->
            socket
        end
      end
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
      # Available stops will only include the stops visible with the given route filter
      # And now just a list of stop ids
      available_stop_ids = Enum.map(available_stops, fn stop -> stop.id end)

      # Get all the stops that were selected but are no longer included in `available_stops`
      # Then append them to the top of the list
      previously_selected_stops =
        Enum.filter(selected_stops, fn stop -> stop.id not in available_stop_ids end)

      options = previously_selected_stops ++ available_stops

      SelectFormatter.formatted_select_options(%SelectFormatter{
        options: options,
        search_term: stop_search_term,
        route_type: route_type,
        values_to_keep: stop_ids,
        option_prefix: "stop-selector"
      })
    end

    defp route_id_options(
           available_routes,
           route_ids,
           route_search_term,
           route_type
         ) do
      SelectFormatter.formatted_select_options(%SelectFormatter{
        options: available_routes,
        search_term: route_search_term,
        route_type: route_type,
        values_to_keep: route_ids,
        option_prefix: "route-selector"
      })
    end

    @update_selection_targets [
      "stop_ids",
      "route_ids",
      "route_search_term",
      "stop_search_term",
      "modal_route_search_term"
    ]
    # update selections when a user interacts with one of our fields...
    defp update_selections?(%{"_target" => ["alert_data", field]})
         when field in @update_selection_targets,
         do: true

    # ...but not on any other user interaction...
    defp update_selections?(%{"_target" => _target}), do: false
    # ...and always on mount, when there is no target
    defp update_selections?(_), do: true
  end

  def render(assigns) do
    assigns = assign_unwrapped_selections(assigns, %Selections{loading: true})

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
        target_id="#alert_form"
      >
        <.filtered_select
          label="Routes"
          field={@form[:modal_route_id]}
          filter_field={@form[:modal_route_search_term]}
          options={@selections.modal_route_id_options}
          loading={Map.get(@selections, :loading, true)}
          no_results={Enum.empty?(@selections.modal_route_id_options)}
          class="h-[32rem]"
          prompt="All routes"
          multiple={false}
        />
      </.modal>

      <.filtered_select
        class="md:w-[25%]"
        field={@form[:stop_ids]}
        filter_field={@form[:stop_search_term]}
        selected={@form[:stop_ids].value}
        label="Stops"
        loading={Map.get(@selections, :loading, true)}
        modal_filter_active={@selections.selected_route_id}
        modal_filter_id="routes-filter-modal"
        modal_filter_title={"Filter: #{@selections.filter_title_value}"}
        no_results={Enum.empty?(@selections.stop_id_options)}
        options={@selections.stop_id_options}
        target_id="#alert_form"
      />

      <.filtered_select
        label="Impacted routes"
        field={@form[:route_ids]}
        filter_field={@form[:routes_search_term]}
        loading={Map.get(@selections, :loading, true)}
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
end
