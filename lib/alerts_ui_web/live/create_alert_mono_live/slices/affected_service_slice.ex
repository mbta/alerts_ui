defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.AffectedServiceSlice do
  use AlertsUIWeb, :html
  alias AlertsUI.Models.Alert
  alias AlertsUIWeb.CreateAlertLive
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.FormComponents.Helpers.SelectFormatter

  import Phoenix.LiveView, only: [assign_async: 3]
  import AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertData,
    only: [get_single_route_effect_names: 0]
  import AlertsUIWeb.CreateAlertMonoLive.Helpers.Selections,
    only: [selections_loading?: 1, assign_unwrapped_selections: 2]
  import AlertsUIWeb.CreateAlertMonoLive.Helpers.Time,
    only: [today: 0]

  defstruct [
    :direction,
    :modal_date,
    :modal_date_search_term,
    :route_ids,
    :single_route_id,
    :stop_names_and_ids,
    :stop_search_term,
    :trip_ids,
    :trip_search_term,
  ]

  defmodule Selections do
    defstruct [
      available_routes: [],
      available_schedules: [],
      available_stops: [],
      direction_options: [],
      filter_title_value: "FILTER TITLE VALUE",
      loading: false,
      modal_options: [],
      route_id_options: [],
      stop_id_options: [],
      stop_selections: [],
      today: nil,
      trip_id_options: []
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

    def assigns(_service_data, socket, params) do
      # update selections here
      async_assign_selections(socket, params)
    end

    defp async_assign_selections(socket, params) do
      if update_selections?(params) do
        # prep work:
        # modal date -> nil
        # routes
        # stops
        # schedules
        form = socket.assigns.form

        direction = form[:direction].value
        modal_date = form[:modal_date].value
        route_ids = form[:route_ids].value || []
        route_search_term = form[:route_search_term].value
        route_type = form[:route_type].value
        stop_names_and_ids = form[:stop_names_and_ids].value || []
        stop_search_term = form[:stop_search_term].value
        trip_ids = form[:trip_ids].value || []
        trip_search_term = form[:trip_search_term].value

        all_route_types = all_route_types(route_type)

        socket
        |> assign_async(:selections, fn ->
          available_routes = CreateAlertLive.get_routes(all_route_types)

          available_stops = CreateAlertLive.get_stops(
            route_ids,
            route_type,
            direction
          )

          available_schedules = CreateAlertLive.get_schedules_by_date(
            route_ids,
            direction,
            modal_date
          )

          direction_options =
            SelectFormatter.formatted_direction_options(
              route_ids,
              Map.new(available_routes, &{&1.id, &1.direction_names})
            )

          route_id_options =
            SelectFormatter.formatted_select_options(%SelectFormatter{
              options: available_routes,
              search_term: route_search_term,
              route_type: route_type,
              values_to_keep: route_ids,
              option_prefix: "route-search"
            })

          stop_id_options =
            SelectFormatter.formatted_select_options(%SelectFormatter{
              options: available_stops,
              search_term: stop_search_term,
              route_type: route_type,
              values_to_keep: stop_names_and_ids,
              option_prefix: "stop-search"
            })

          trip_id_options =
            SelectFormatter.formatted_select_options(%SelectFormatter{
              schedules_by_route_name: get_schedules_by_route_type(
                available_schedules,
                route_ids
              ),
              search_term: trip_search_term,
              route_type: route_type,
              values_to_keep: trip_ids,
              option_prefix: "trip-search"
            })

          selections = %Selections{
            available_routes: available_routes,
            available_stops: available_stops,
            available_schedules: available_schedules,
            direction_options: direction_options,
            route_id_options: route_id_options,
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

    @update_selection_targets [
      "stop_ids",
      "route_ids",
      "trip_ids",
      "modal_route_search_term",
      "route_search_term",
      "stop_search_term",
      "trip_search_term"
    ]

    @update_selection_targets ["stop_ids", "route_ids", "route_search_term", "stop_search_term", "modal_route_search_term"]
    # update selections when a user interacts with one of our fields...
    defp update_selections?(%{"_target" => ["alert_data", field]}) when field in @update_selection_targets, do: true
    # ...but not on any other user interaction...
    defp update_selections?(%{"_target" => _target}), do: false
    # ...and always on mount, when there is no target
    defp update_selections?(_), do: true

    defp all_route_types(0), do: [0, 1]
    defp all_route_types(1), do: [0, 1]
    defp all_route_types(2), do: [2]
    defp all_route_types(3), do: [3]
    defp all_route_types(4), do: [4]
    defp all_route_types(_), do: []

    defp get_schedules_by_route_type(available_schedules, route_ids) do
      Enum.filter(available_schedules, fn schedule ->
        # If a line was selected and deselected, value here may be set to nil
        schedule.route.id in (route_ids || [])
      end)
      |> Enum.group_by(&SelectFormatter.name_for_option(&1.route))
    end
  end

  def render(assigns) do
    assigns = assign_unwrapped_selections(assigns, %Selections{loading: true})

    ~H"""
    <div class="min-w-full self-start flex flex-col" id="service_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Affected service
      </.h5>
      <div class="mb-4 md:mb-0 w-full md:w-[25%] md:mr-8">
        <.filtered_select
          :if={filtered_select_for_route_type?(@form[:route_type].value)}
          label={if @form[:route_type].value in [0, 1, 2], do: "Lines", else: "Routes"}
          field={
            if @form[:effect_name].value in get_single_route_effect_names(),
              do: @form[:single_route_id],
              else: @form[:route_ids]
          }
          filter_field={@form[:route_search_term]}
          loading={selections_loading?(@selections)}
          no_results={Enum.empty?(@selections.route_id_options)}
          options={@selections.route_id_options}
          class="h-full"
          multiple={if @form[:effect_name].value in get_single_route_effect_names(), do: false, else: true}
        />
        <.toggle_checkgroup
          :if={!filtered_select_for_route_type?(@form[:route_type].value)}
          label={if @form[:route_type].value in [0, 1, 2], do: "Lines", else: "Routes"}
          field={@form[:route_ids]}
          options={@selections.route_id_options}
          icon_type={icon_type(@form[:route_type].value)}
          class="flex-col"
          button_class="min-w-full"
          show_icons={true}
        />
      </div>

      <.modal
        :if={show_trips_input?(@form[:combination].value)}
        id="dates-filter-modal"
        header_text="Filter by day"
        cancel_event_name="cancelled_modal"
        accept_event_name="accepted_dates_modal"
        accept_button_text="Apply"
        target_id="#alert_form"
        container_class="md:!w-[25rem]"
      >
        <.filtered_select
          label="Upcoming dates"
          field={@form[:modal_date]}
          filter_field={@form[:modal_date_search_term]}
          options={@selections.modal_options}
          class="h-[32rem]"
          prompt="All future trips"
          multiple={false}
        />
      </.modal>
      <div :if={show_trips_input?(@form[:combination].value)} class="flex flex-col justify-start md:w-[25%] md:mr-8">
        <.select
          :if={show_directions_input?(@form[:combination].value)}
          label={
            cond do
              show_trips_input?(@form[:combination].value) -> "Trips"
              show_stops_input?(@form[:combination].value) -> "Stops"
              true -> "Direction"
            end
          }
          field={@form[:direction]}
          modal_filter_id="dates-filter-modal"
          modal_filter_title={"Filter: #{@selections.filter_title_value}"}
          modal_filter_active={date_filter_active?(@form[:modal_date].value, @selections.today)}
          options={@selections.direction_options}
          disabled={disable_stop_input?(@form[:route_ids].value)}
          modal_filter_disabled={@form[:route_ids].value in [nil, []]}
          prompt={if disable_stop_input?(@form[:route_ids].value), do: "", else: "Both Directions"}
          target_id="#alert_form"
        />
        <.filtered_select
          field={@form[:trip_ids]}
          filter_field={@form[:trip_search_term]}
          options={@selections.trip_id_options}
          loading={selections_loading?(@selections)}
          no_results={
            Enum.empty?(@selections.trip_id_options) && !disable_trip_input?(@form[:route_ids].value)
          }
          class="min-w-full h-full"
          disabled={disable_trip_input?(@form[:route_ids].value)}
          prompt={if disable_trip_input?(@form[:route_ids].value), do: nil, else: "All Trips"}
        />
      </div>
      <div class="flex flex-col justify-start w-full md:w-[25%]">
        <.select
          :if={show_directions_input?(@form[:combination].value) && !show_trips_input?(@form[:combination].value)}
          label={if show_stops_input?(@form[:combination].value), do: "Stops", else: "Direction"}
          field={@form[:direction]}
          options={@selections.direction_options}
          disabled={disable_stop_input?(@form[:route_ids].value)}
          prompt={if disable_stop_input?(@form[:route_ids].value), do: "", else: "Both Directions"}
        />
        <.filtered_select
          :if={show_stops_input?(@form[:combination].value)}
          label={if show_trips_input?(@form[:combination].value), do: "Stops", else: nil}
          field={@form[:stop_names_and_ids]}
          selected={@selections.stop_selections}
          filter_field={@form[:stop_search_term]}
          options={@selections.stop_id_options}
          loading={selections_loading?(@selections)}
          no_results={
            Enum.empty?(@selections.stop_id_options) && !disable_stop_input?(@form[:route_ids].value)
          }
          class="min-w-full h-full"
          disabled={disable_stop_input?(@form[:route_ids].value)}
          prompt={
            if disable_stop_input?(@form[:route_ids].value),
              do: nil,
              else: "All Stops"
          }
        />
      </div>
      <p :if={false}>
        Selected stop ids: {(@form[:stop_ids].value || []) |> Enum.join(", ")} Selected route ids: {(@form[
                                                                                                       :route_ids
                                                                                                     ].value ||
                                                                                                       [])
        |> Enum.join(", ")} Selected trip ids: {(@form[:trip_ids].value || []) |> Enum.join(", ")}
      </p>
      <hr class="mt-4" />
    </div>
    """
  end

  defp date_filter_active?(filter_value, today) when filter_value == today, do: false
  defp date_filter_active?(_, _), do: true

  defp icon_type(route_type) do
    case route_type do
      2 -> :commuter_rail
      4 -> :ferry
      _ -> nil
    end
  end

  defp disable_stop_input?(nil), do: true
  defp disable_stop_input?(route_ids) when is_list(route_ids), do: length(route_ids) !== 1
  defp disable_stop_input?(_route_ids), do: true

  defp disable_trip_input?(route_ids) when is_list(route_ids), do: Enum.empty?(route_ids)
  defp disable_trip_input?(_route_ids), do: true

  defp show_trips_input?(combination) do
    combination in [:RDT, :RDTS]
  end

  defp show_stops_input?(combination) do
    combination in [:RDS, :RDTS]
  end

  defp show_directions_input?(combination) do
    combination in [:RDS, :RDTS, :RDS, :RDT]
  end

  defp filtered_select_for_route_type?(route_type) do
    Enum.member?([2, 3, 4], route_type)
  end
end
