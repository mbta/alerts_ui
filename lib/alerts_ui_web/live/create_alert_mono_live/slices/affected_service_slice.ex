defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.AffectedServiceSlice do
  @moduledoc """
  Slice that manages affected-service selection for single-route alerts:
  routes, stops, directions, trips, and service-date filtering. Asynchronously
  loads schedules and renders the route/stop/trip picker for the details step.
  """

  use AlertsUIWeb, :html
  alias AlertsUI.Models.ActivePeriod
  alias AlertsUIWeb.CreateAlertLive
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData
  alias AlertsUIWeb.CreateAlertMonoLive.Slice

  alias AlertsUIWeb.FormComponents.Helpers.SelectFormatter

  import Phoenix.LiveView, only: [start_async: 3]
  import Ecto.Changeset, only: [cast: 3, get_field: 2, change: 2]

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertData,
    only: [get_single_route_effect_names: 0, humanize_effect_name: 1]

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.Selections,
    only: [selections_loading?: 1]

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.Validation,
    only: [always_validate_required: 3]

  defstruct [
    :direction,
    :modal_date,
    :modal_date_search_term,
    :route_ids,
    :route_search_term,
    :single_route_id,
    :stop_names_and_ids,
    :stop_search_term,
    :trip_ids,
    :trip_search_term
  ]

  defmodule Selections do
    @moduledoc "Holds async-loaded route, stop, and schedule option lists for `AffectedServiceSlice`."

    alias AlertsUIWeb.CreateAlertMonoLive.Slices.AffectedServiceSlice

    defstruct available_routes: [],
              available_schedules: [],
              available_stops: [],
              direction_options: [],
              filter_title_value: nil,
              loading: false,
              on_filter_accept: &AffectedServiceSlice.on_filter_accept/1,
              on_filter_clear: &AffectedServiceSlice.on_filter_clear/1,
              route_id_options: [],
              selected_stops: [],
              service_dates: [],
              stop_id_options: [],
              today: nil,
              trip_id_options: []
  end

  defimpl Slice, for: __MODULE__ do
    alias AlertsUIWeb.CreateAlertMonoLive.Slices.AffectedServiceSlice

    def mount(_service_data, socket, _base_params) do
      socket
    end

    def extract(service_data, %AlertData{} = _alert_data, _params) do
      service_data
    end

    def transform(_service_data, changeset, _params, socket) do
      changeset
      |> AffectedServiceSlice.transform_changeset()
      |> AffectedServiceSlice.build_trip_information(socket)
    end

    def validate(_service_data, changeset, _params, socket) do
      if socket.assigns.submitted? do
        AffectedServiceSlice.validate_changeset(changeset)
      else
        changeset
      end
    end

    def assigns(_service_data, socket, params) do
      AffectedServiceSlice.async_assign_selections(socket, params)
    end
  end

  def build_trip_information(changeset, socket) do
    available_schedules = available_schedules_from_socket(socket)
    trip_ids = get_field(changeset, :trip_ids) || []
    route_type = get_field(changeset, :route_type)
    direction = get_field(changeset, :direction)

    # If selections aren't loaded yet (empty schedules) but trips are selected,
    # preserve existing trip_information_by_id rather than overwriting with empty map.
    if Enum.empty?(available_schedules) and Enum.any?(trip_ids) do
      changeset
    else
      trip_info =
        available_schedules
        |> Stream.filter(&(&1.trip.id in trip_ids))
        |> Stream.filter(fn s ->
          direction in [
            nil,
            "default",
            s.trip.direction_id,
            Integer.to_string(s.trip.direction_id)
          ]
        end)
        |> Enum.reduce(%{}, fn s, acc ->
          Map.put(acc, s.trip.id, %{
            direction_id: s.trip.direction_id,
            route_id: s.route.id,
            trip_name: SelectFormatter.name_for_option(s, route_type)
          })
        end)

      cast(changeset, %{trip_information_by_id: trip_info}, [:trip_information_by_id])
    end
  end

  defp available_schedules_from_socket(socket) do
    case Map.get(socket.assigns, :selections) do
      %Selections{available_schedules: schedules} -> schedules || []
      _ -> []
    end
  end

  def transform_changeset(changeset) do
    changeset
    |> ensure_default_direction()
    |> ensure_route_ids()
    # |> ensure_coherent_selections()
    # |> filter_empty_list_fields()
    |> ensure_stop_names_and_ids()
    |> ensure_trip_ids()
    |> filter_stops_by_direction()
    |> split_stop_names_and_ids()
    |> ensure_modal_date()
  end

  def validate_changeset(changeset) do
    normalized_single_route_effects =
      Enum.map(get_single_route_effect_names(), fn name ->
        name |> String.split(" ") |> Enum.map_join("_", &String.downcase/1)
      end)

    if get_field(changeset, :effect_name) in normalized_single_route_effects do
      always_validate_required(changeset, :single_route_id, "You must select a route")
    else
      always_validate_required(changeset, :route_ids, "You must select a route")
    end
  end

  def async_assign_selections(%{assigns: %{} = assigns} = socket, params) do
    if update_selections?(params) do
      update_selections(socket)
    else
      dont_update_selections(Map.get(assigns, :selections), socket)
    end
  end

  def async_assign_selections(socket, _params), do: socket

  defp update_selections(socket) do
    prev = prev(Map.get(socket.assigns, :selections))
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
    |> assign(:selections, %{prev | loading: true})
    |> start_async(:fetch_selections, fn ->
      available_routes = CreateAlertLive.get_routes(all_route_types)

      available_stops =
        CreateAlertLive.get_stops(
          route_ids,
          route_type,
          direction
        )

      available_schedules = available_schedules(route_ids, direction, modal_date)

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
        SelectFormatter.formatted_select_options(
          %SelectFormatter{
            options: available_stops,
            search_term: stop_search_term,
            route_type: route_type,
            values_to_keep: stop_names_and_ids,
            option_prefix: "stop-search"
          },
          true
        )

      trip_id_options =
        SelectFormatter.formatted_select_options(%SelectFormatter{
          schedules_by_route_name:
            get_schedules_by_route_type(
              available_schedules,
              route_ids
            ),
          search_term: trip_search_term,
          route_type: route_type,
          values_to_keep: trip_ids,
          option_prefix: "trip-search"
        })

      {filter_title_value, _} =
        service_dates()
        |> Enum.find({"All future trips", nil}, fn {_option, value} ->
          value == (modal_date || today())
        end)

      %Selections{
        available_routes: available_routes,
        available_stops: available_stops,
        available_schedules: available_schedules,
        direction_options: direction_options,
        filter_title_value: filter_title_value,
        route_id_options: route_id_options,
        stop_id_options: stop_id_options,
        service_dates: service_dates(),
        trip_id_options: trip_id_options
      }
    end)
  end

  defp dont_update_selections(nil, socket), do: assign(socket, :selections, %Selections{})
  defp dont_update_selections(_selections, socket), do: socket

  defp prev(%Selections{} = selections), do: selections
  defp prev(_), do: %Selections{}

  defp available_schedules(route_ids, direction, modal_date)
       when nil in [route_ids, direction, modal_date] do
    []
  end

  defp available_schedules(route_ids, direction, modal_date) do
    date = get_schedule_date(modal_date)

    CreateAlertLive.get_schedules_by_date(
      route_ids,
      direction,
      date
    )
  end

  defp get_schedule_date("default") do
    DateTime.now!("America/New_York") |> Calendar.strftime("%Y-%m-%d")
  end

  defp get_schedule_date(modal_date), do: modal_date

  @update_selection_targets [
    "direction",
    "stop_ids",
    "route_ids",
    "trip_ids",
    "modal_route_search_term",
    "route_search_term",
    "single_route_id",
    "stop_search_term",
    "trip_search_term"
  ]

  # update selections when a user interacts with one of our fields...
  defp update_selections?(%{"_target" => ["alert_data", field]})
       when field in @update_selection_targets,
       do: true

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

  defp ensure_default_direction(changeset) do
    case get_field(changeset, :direction) do
      nil -> cast(changeset, %{direction: "default"}, [:direction])
      _ -> changeset
    end
  end

  defp ensure_route_ids(changeset) do
    effect_name = get_field(changeset, :effect_name)

    normalized_single_route_effects =
      Enum.map(get_single_route_effect_names(), fn name ->
        name |> String.split(" ") |> Enum.map_join("_", &String.downcase/1)
      end)

    cond do
      effect_name in normalized_single_route_effects ->
        incoming_route_id = get_field(changeset, :single_route_id)
        cast(changeset, %{route_ids: [incoming_route_id]}, [:route_ids])

      get_field(changeset, :route_ids) == nil ->
        cast(changeset, %{route_ids: []}, [:route_ids])

      true ->
        changeset
    end
  end

  defp ensure_stop_names_and_ids(changeset) do
    if get_field(changeset, :stop_names_and_ids) in [nil, "default", ["default"]] do
      cast(changeset, %{stop_names_and_ids: []}, [:stop_names_and_ids])
    else
      changeset
    end
  end

  defp ensure_trip_ids(changeset) do
    trip_ids = get_field(changeset, :trip_ids)

    cond do
      trip_ids in [nil, "default", ["default"]] ->
        cast(changeset, %{trip_ids: []}, [:trip_ids])

      is_list(trip_ids) and "default" in trip_ids ->
        cast(changeset, %{trip_ids: List.delete(trip_ids, "default")}, [:trip_ids])

      true ->
        changeset
    end
  end

  defp filter_stops_by_direction(changeset) do
    marker =
      case get_field(changeset, :direction) do
        "0" -> ~r/inbound/
        "1" -> ~r/outbound/
        _ -> ~r/\A\Z/
      end

    stop_names_and_ids =
      changeset
      |> get_field(:stop_names_and_ids)
      |> Enum.filter(&(!(&1 =~ marker)))

    cast(
      changeset,
      %{stop_names_and_ids: stop_names_and_ids},
      [:stop_names_and_ids]
    )
  end

  defp split_stop_names_and_ids(changeset) do
    split_names_and_ids =
      get_field(changeset, :stop_names_and_ids)
      |> Enum.reduce(%{stop_names: [], stop_ids: []}, fn name_and_id, acc ->
        case name_and_id do
          "default" ->
            acc

          _ ->
            [stop_name, stop_id] = String.split(name_and_id, "|")
            stop_names = [stop_name | acc[:stop_names]]
            stop_ids = [stop_id | acc[:stop_ids]]

            %{stop_names: stop_names, stop_ids: stop_ids}
        end
      end)

    cast(changeset, split_names_and_ids, [:stop_names, :stop_ids])
  end

  def ensure_modal_date(changeset) do
    case get_field(changeset, :modal_date) do
      nil -> change(changeset, modal_date: today())
      _ -> changeset
    end
  end

  def default_selections(selections \\ %Selections{}) do
    %{selections | service_dates: service_dates(), loading: true, today: today()}
  end

  def service_dates do
    0..6
    |> Enum.to_list()
    |> Enum.map(fn i ->
      DateTime.now!("America/New_York")
      |> ActivePeriod.datetime_to_service_date()
      |> Date.add(i)
    end)
    |> Enum.map(fn date ->
      {Calendar.strftime(date, "%a %b %0d"), Date.to_iso8601(date)}
    end)
  end

  def today do
    DateTime.now!("America/New_York")
    |> ActivePeriod.datetime_to_service_date()
    |> Date.to_iso8601()
  end

  def default_filter_title do
    service_dates()
    |> Enum.find({"All future trips", nil}, fn {_option, value} ->
      value == today()
    end)
    |> elem(0)
  end

  def render(assigns) do
    ~H"""
    <div class="min-w-full self-start flex flex-col" id="service_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Affected service
      </.h5>
      <div class="flex flex-row flex-wrap mb-4 min-h-[38rem] md:min-h-[32rem]">
        <div class="mb-4 md:mb-0 w-full md:w-[25%] md:mr-8">
          <.filtered_select
            :if={filtered_select_for_route_type?(@form[:route_type].value)}
            label={if @form[:route_type].value in [0, 1, 2], do: "Lines", else: "Routes"}
            field={
              if humanize_effect_name(@form) in get_single_route_effect_names(),
                do: @form[:single_route_id],
                else: @form[:route_ids]
            }
            filter_field={@form[:route_search_term]}
            loading={selections_loading?(@selections)}
            no_results={Enum.empty?(@selections.route_id_options)}
            options={@selections.route_id_options}
            class="h-full"
            multiple={
              if humanize_effect_name(@form) in get_single_route_effect_names(), do: false, else: true
            }
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
          cancel_event_name="cancel_filter"
          accept_event_name="accept_filter"
          accept_button_text="Apply"
          target_id="#alert_form"
          container_class="md:!w-[25rem]"
        >
          <.filtered_select
            label="Upcoming dates"
            field={@form[:modal_date]}
            filter_field={@form[:modal_date_search_term]}
            options={
              filter_service_dates(
                service_dates(),
                @form[:modal_date_search_term].value,
                @form[:modal_date].value
              )
            }
            class="h-[32rem]"
            prompt="All future trips"
            multiple={false}
          />
        </.modal>
        <div
          :if={show_trips_input?(@form[:combination].value)}
          class="flex flex-col justify-start md:w-[25%] md:mr-8"
        >
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
            modal_filter_title={"Filter: #{@selections.filter_title_value || default_filter_title()}"}
            modal_filter_active={date_filter_active?(@form[:modal_date].value, today())}
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
              Enum.empty?(@selections.trip_id_options) &&
                !disable_trip_input?(@form[:route_ids].value)
            }
            class="min-w-full h-full"
            disabled={disable_trip_input?(@form[:route_ids].value)}
            prompt={if disable_trip_input?(@form[:route_ids].value), do: nil, else: "All Trips"}
          />
        </div>
        <div class="flex flex-col justify-start w-full md:w-[25%]">
          <.select
            :if={
              show_directions_input?(@form[:combination].value) &&
                !show_trips_input?(@form[:combination].value)
            }
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
            selected={@form[:stop_names_and_ids].value}
            filter_field={@form[:stop_search_term]}
            options={@selections.stop_id_options}
            loading={selections_loading?(@selections)}
            no_results={
              Enum.empty?(@selections.stop_id_options) &&
                !disable_stop_input?(@form[:route_ids].value)
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

  defp filter_service_dates(dates, nil, _selected), do: dates
  defp filter_service_dates(dates, "", _selected), do: dates

  defp filter_service_dates(dates, search_term, selected) do
    lower = String.downcase(search_term)

    Enum.filter(dates, fn {label, value} ->
      String.contains?(String.downcase(label), lower) || value == selected
    end)
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

  def on_filter_accept(socket) do
    async_assign_selections(socket, %{})
  end

  def on_filter_clear(socket) do
    {_, socket} =  AlertData.sync(socket.assigns.form.source, socket, %{
           "alert_data" => %{"modal_date" => today(), "modal_date_search_term" => nil}
         })

        async_assign_selections(socket, %{})

  end
end
