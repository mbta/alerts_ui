defmodule AlertsUIWeb.CreateAlertLive.Slices.AffectedServiceSlice do
  @moduledoc """
  Slice that manages affected-service selection for single-route alerts:
  routes, stops, directions, trips, and service-date filtering. Asynchronously
  loads schedules and renders the route/stop/trip picker for the details step.
  """

  alias AlertsUIWeb.CreateAlertLive.Slices.AffectedServiceSlice
  use AlertsUIWeb, :html
  alias AlertsUI.Alerts
  alias AlertsUI.Models.ActivePeriod
  alias AlertsUI.SkateDetours.GetDetours
  alias AlertsUIWeb.CreateAlertHelpers
  alias AlertsUIWeb.CreateAlertLive.AlertData
  alias AlertsUIWeb.CreateAlertLive.Helpers.GetKeyForModeEffect
  alias AlertsUIWeb.CreateAlertLive.Helpers.SelectFormatter
  alias AlertsUIWeb.CreateAlertLive.Slice

  alias Ecto.Changeset

  import Phoenix.LiveView, only: [push_event: 3, start_async: 3]

  import AlertsUIWeb.CreateAlertLive.Helpers.AlertDataHelpers,
    only: [get_single_route_effect_names: 0, humanize_effect_name: 1, humanize_effect_name: 2]

  import AlertsUIWeb.CreateAlertLive.Helpers.Validation,
    only: [always_validate_required: 3]

  @min_stops_message "Select 2 or more stops between which service is not running"

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
    :trip_search_term,
    :form_type,
    :skate_search_term,
    :skate_detour_id
  ]

  defmodule Selections do
    @moduledoc "Holds async-loaded route, stop, and schedule option lists for `AffectedServiceSlice`."

    alias AlertsUIWeb.CreateAlertLive.Slices.AffectedServiceSlice

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
    alias AlertsUI.SkateDetours.GetDetours
    alias AlertsUIWeb.CreateAlertLive.Slices.AffectedServiceSlice
    alias AlertsUIWeb.CreateAlertLive.Slices.AffectedServiceSlice.Selections

    def mount(service_data, socket, _base_params) do
      assign(
        socket,
        %{
          selections: %Selections{today: AffectedServiceSlice.today()},
          original_skate_id: service_data.skate_detour_id
        }
      )
    end

    def extract(service_data, _alert_data, _params) do
      # When editing or duplicating, we want to force the trip filter to "All Future Trips"
      if service_data.form_type in [:editing, :duplicating] do
        %{service_data | modal_date: nil}
      else
        service_data
      end
    end

    def transform(_service_data, changeset, params, socket) do
      changeset
      |> AffectedServiceSlice.apply_detour(socket, params)
      |> AffectedServiceSlice.transform_changeset(params)
      |> AffectedServiceSlice.build_trip_information(socket)
    end

    def validate(_service_data, changeset, _params, socket) do
      cond do
        socket.assigns.submitting? ->
          AffectedServiceSlice.validate_changeset(changeset)

        Map.get(socket.assigns, :stops_touched?, false) ->
          AffectedServiceSlice.validate_min_stops(changeset)

        true ->
          changeset
      end
    end

    def assigns(_service_data, socket, params) do
      socket =
        socket
        |> AffectedServiceSlice.clear_stops_touched_on_route_change(params)
        |> AffectedServiceSlice.async_assign_selections(params)

      form = socket.assigns.form

      bus_detour? =
        AffectedServiceSlice.bus_detour?(
          form[:route_type].value,
          form[:effect_name].value,
          socket.assigns.show_new_bus_detours
        )

      socket =
        if is_nil(socket.assigns.skate_detours.loading) and bus_detour? do
          AffectedServiceSlice.async_assign_detours(socket, params)
        else
          socket
        end

      # We do not want to let the user select both "All trips" and an individual trip
      # We push the data to the client (hooks.js) to filter for us
      maybe_needs_adjusting = %{
        stop_names_and_ids: socket.assigns.form[:stop_names_and_ids].value,
        trip_ids: socket.assigns.form[:trip_ids].value
      }

      push_event(socket, "adjustSelections", maybe_needs_adjusting)
    end
  end

  def apply_detour(changeset, socket, %{"_target" => ["alert_data", "skate_detour_id"]}) do
    detours = socket.assigns.skate_detours.result || []
    skate_detour_id = Changeset.get_field(changeset, :skate_detour_id)
    skate_detour = Enum.find(detours, &(&1.id == skate_detour_id))

    stops =
      socket.assigns.selections.available_stops
      |> Enum.filter(&(&1.id in skate_detour.missed_stops))
      |> Enum.map(&SelectFormatter.id_for_option(&1, true))

    changeset
    |> Changeset.cast(%{direction: Integer.to_string(skate_detour.direction_id)}, [:direction])
    |> Changeset.cast(%{stop_names_and_ids: stops}, [:stop_names_and_ids])
  end

  def apply_detour(changeset, _socket, _params) do
    changeset
  end

  def build_trip_information(changeset, socket) do
    available_schedules = available_schedules_from_socket(socket)
    trip_ids = Changeset.get_field(changeset, :trip_ids) || []
    route_type = Changeset.get_field(changeset, :route_type)
    direction = Changeset.get_field(changeset, :direction)

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
            route_id: s.route_id,
            trip_name: SelectFormatter.name_for_option(s, route_type),
            added_route_ids: s.added_route_ids
          })
        end)

      Changeset.cast(changeset, %{trip_information_by_id: trip_info}, [:trip_information_by_id])
    end
  end

  defp available_schedules_from_socket(socket) do
    case Map.get(socket.assigns, :selections) do
      %Selections{available_schedules: schedules} -> schedules || []
      _ -> []
    end
  end

  def transform_changeset(changeset, params) do
    # The select component renders the prompt option with value="default". When the user
    # selects "All future trips", the browser sends modal_date=default. Ecto would cast
    # "default" normally, and ensure_modal_date would then convert it to today(). We must
    # force nil into the changeset here so ensure_modal_date sees nil and passes it through.
    # ("" is also handled for robustness, though the browser always sends "default".)
    changeset =
      if get_in(params, ["alert_data", "modal_date"]) in ["", "default"] do
        Changeset.force_change(changeset, :modal_date, nil)
      else
        changeset
      end

    changeset
    |> ensure_default_direction()
    |> ensure_route_ids()
    |> clear_selections_on_change(params)
    |> ensure_stop_names_and_ids()
    |> ensure_trip_ids()
    |> filter_stops_by_direction()
    |> split_stop_names_and_ids()
    |> ensure_modal_date()
  end

  def validate_changeset(changeset) do
    # Validate route first
    changeset =
      changeset
      |> validate_route_required()

    # Only if route is valid do we then validate stops
    if changeset.errors != [] do
      changeset
    else
      changeset
      |> validate_min_stops()
      |> validate_stops_selected()
    end
  end

  defp validate_route_required(changeset) do
    normalized_single_route_effects =
      Enum.map(get_single_route_effect_names(), fn name ->
        name |> String.split(" ") |> Enum.map_join("_", &String.downcase/1)
      end)

    if Changeset.get_field(changeset, :effect_name) in normalized_single_route_effects do
      always_validate_required(changeset, :single_route_id, "You must select a route")
    else
      always_validate_required(changeset, :route_ids, "You must select a route")
    end
  end

  def validate_min_stops(changeset) do
    {route_type, effect_name} = parse_route_effect_from_changeset(changeset)

    min_stops = GetKeyForModeEffect.get_value_of_key(:min_stops, route_type, effect_name) || 1

    stop_count = changeset |> Changeset.get_field(:stop_names_and_ids, []) |> length()

    if min_stops > 1 and stop_count == 1 do
      Changeset.add_error(changeset, :stop_names_and_ids, @min_stops_message)
    else
      changeset
    end
  end

  # Some effects (i.e. Bypass) must have stops selected and cannot be 'All Stops'
  defp validate_stops_selected(changeset) do
    if allow_selecting_all_stops?(changeset) do
      changeset
    else
      always_validate_required(changeset, :stop_names_and_ids, "Select stop(s)")
    end
  end

  defp parse_route_effect_from_changeset(changeset) do
    route_type = Changeset.get_field(changeset, :route_type)
    effect_name = Changeset.get_field(changeset, :effect_name)
    humanized_effect_name = humanize_effect_name(route_type, effect_name)

    {route_type, humanized_effect_name}
  end

  def allow_selecting_all_stops?(changeset) do
    {route_type, effect_name} = parse_route_effect_from_changeset(changeset)

    GetKeyForModeEffect.get_value_of_key(:allow_all_stops?, route_type, effect_name)
  end

  @route_fields ["route_ids", "single_route_id"]

  # Changing the route clears the stop selection (see clear_selections_on_change/2),
  # so a prior blur on the old selection shouldn't keep validating the new one live —
  # require a fresh blur before showing the min-stops error again.
  def clear_stops_touched_on_route_change(socket, %{"_target" => ["alert_data", field]})
      when field in @route_fields do
    assign(socket, :stops_touched?, false)
  end

  def clear_stops_touched_on_route_change(socket, _params), do: socket

  def async_assign_selections(%{assigns: %{} = assigns} = socket, params) do
    if update_selections?(params) do
      update_selections(socket, params)
    else
      dont_update_selections(Map.get(assigns, :selections), socket)
    end
  end

  def async_assign_selections(socket, _params), do: socket

  def async_assign_detours(socket, _params) do
    single_route_id = socket.assigns.form[:single_route_id].value

    original_skate_id = Map.get(socket.assigns, :original_skate_id)

    Phoenix.LiveView.assign_async(socket, [:skate_detours, :used_detours], fn ->
      detours = GetDetours.get_detours() |> Enum.filter(&(&1.route_id == single_route_id))

      # if we have an existing id because we're editing, don't mark it as used
      used_detours =
        Alerts.get_matching_skate_ids(Enum.map(detours, & &1.id))
        |> Enum.reject(&(&1.skate_detour_id == original_skate_id))

      {:ok,
       %{
         skate_detours: detours,
         used_detours: used_detours
       }}
    end)
  end

  defp update_selections(
         socket,
         %{"_target" => ["alert_data", "route_search_term"]}
       ) do
    prev = prev(Map.get(socket.assigns, :selections))
    form = socket.assigns.form

    route_id_options = route_id_options(prev.available_routes, form)

    socket
    |> assign(:selections, %{prev | route_id_options: route_id_options})
  end

  defp update_selections(
         socket,
         %{"_target" => ["alert_data", "stop_search_term"]}
       ) do
    prev = prev(Map.get(socket.assigns, :selections))
    form = socket.assigns.form

    stop_id_options = stop_id_options(prev.available_stops, form)

    socket
    |> assign(:selections, %{prev | stop_id_options: stop_id_options})
  end

  defp update_selections(
         socket,
         %{"_target" => ["alert_data", "trip_search_term"]}
       ) do
    prev = prev(Map.get(socket.assigns, :selections))
    form = socket.assigns.form

    trip_id_options = trip_id_options(prev.available_schedules, prev.available_routes, form)

    socket
    |> assign(:selections, %{prev | trip_id_options: trip_id_options})
  end

  defp update_selections(socket, _params) do
    prev = prev(Map.get(socket.assigns, :selections))
    form = socket.assigns.form

    direction = form[:direction].value
    modal_date = form[:modal_date].value
    route_ids = form[:route_ids].value || []
    route_type = form[:route_type].value
    combination = form[:combination].value

    all_route_types = all_route_types(route_type)

    {filter_title_value, _} =
      service_dates()
      |> Enum.find({"All future trips", nil}, fn {_option, value} ->
        value == modal_date
      end)

    socket
    |> assign(:selections, %{prev | loading: true, filter_title_value: filter_title_value})
    |> start_async(:fetch_selections, fn ->
      available_routes = CreateAlertHelpers.get_routes(all_route_types)

      available_stops =
        CreateAlertHelpers.get_stops(
          route_ids,
          route_type,
          direction
        )

      available_schedules =
        if show_trips_input?(combination),
          do: available_schedules(route_ids, direction, modal_date),
          else: []

      direction_options =
        SelectFormatter.formatted_direction_options(
          route_ids,
          Map.new(available_routes, &{&1.id, &1.direction_names})
        )

      route_id_options = route_id_options(available_routes, form)

      stop_id_options = stop_id_options(available_stops, form)

      trip_id_options = trip_id_options(available_schedules, available_routes, form)

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

  defp route_id_options(
         available_routes,
         form
       ) do
    SelectFormatter.formatted_select_options(%SelectFormatter{
      options: available_routes,
      search_term: form[:route_search_term].value,
      route_type: form[:route_type].value,
      values_to_keep: form[:route_ids].value || [],
      option_prefix: "route-selector"
    })
  end

  defp stop_id_options(available_stops, form) do
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

  defp trip_id_options(available_schedules, available_routes, form) do
    SelectFormatter.formatted_select_options(%SelectFormatter{
      schedules_by_route_name:
        group_schedules_by_route_type(
          available_schedules,
          available_routes,
          form[:route_ids].value || []
        ),
      search_term: form[:trip_search_term].value,
      route_type: form[:route_type].value,
      values_to_keep: form[:trip_ids].value,
      option_prefix: "trip-selector"
    })
  end

  defp dont_update_selections(nil, socket), do: assign(socket, :selections, %Selections{})
  defp dont_update_selections(_selections, socket), do: socket

  defp prev(%Selections{} = selections), do: selections
  defp prev(_), do: %Selections{}

  defp available_schedules(route_ids, direction, _modal_date)
       when nil in [route_ids, direction] or route_ids == [] do
    []
  end

  defp available_schedules(route_ids, direction, modal_date) do
    date = get_schedule_date(modal_date)
    CreateAlertHelpers.get_schedules_by_date(route_ids, direction, date)
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
    "route_search_term",
    "single_route_id",
    "stop_search_term",
    "trip_search_term",
    "skate_search_term"
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

  defp group_schedules_by_route_type(available_schedules, available_routes, route_ids) do
    Enum.filter(available_schedules, fn schedule ->
      # If a line was selected and deselected, value here may be set to nil
      schedule.route_id in (route_ids || [])
    end)
    |> Enum.group_by(fn schedule ->
      route = Enum.find(available_routes, &(&1.id == schedule.route_id))
      SelectFormatter.name_for_option(route)
    end)
  end

  defp ensure_default_direction(changeset) do
    case Changeset.get_field(changeset, :direction) do
      nil -> Changeset.cast(changeset, %{direction: "default"}, [:direction])
      _ -> changeset
    end
  end

  defp ensure_route_ids(changeset) do
    effect_name = Changeset.get_field(changeset, :effect_name)

    normalized_single_route_effects =
      Enum.map(get_single_route_effect_names(), fn name ->
        name |> String.split(" ") |> Enum.map_join("_", &String.downcase/1)
      end)

    cond do
      effect_name in normalized_single_route_effects ->
        case Changeset.get_field(changeset, :single_route_id) do
          nil -> Changeset.cast(changeset, %{route_ids: []}, [:route_ids])
          route_id -> Changeset.cast(changeset, %{route_ids: [route_id]}, [:route_ids])
        end

      Changeset.get_field(changeset, :route_ids) == nil ->
        Changeset.cast(changeset, %{route_ids: []}, [:route_ids])

      true ->
        changeset
    end
  end

  defp clear_selections_on_change(changeset, %{"_target" => _target}) do
    changeset =
      if Changeset.changed?(changeset, :route_ids) do
        Changeset.cast(
          changeset,
          %{
            stop_names_and_ids: [],
            stop_ids: [],
            trip_ids: [],
            skate_detour_id: nil
          },
          [
            :stop_names_and_ids,
            :stop_ids,
            :trip_ids,
            :skate_detour_id
          ]
        )
      else
        changeset
      end

    # clear out direction if skate detour id is changed
    if Changeset.fetch_change(changeset, :skate_detour_id) == {:ok, nil} do
      Changeset.cast(changeset, %{direction: nil}, [:direction])
    else
      changeset
    end
  end

  defp clear_selections_on_change(changeset, _params), do: changeset

  defp ensure_stop_names_and_ids(changeset) do
    stop_names_and_ids = Changeset.get_field(changeset, :stop_names_and_ids)

    cond do
      stop_names_and_ids in [nil, "default", ["default"]] ->
        Changeset.cast(changeset, %{stop_names_and_ids: []}, [:stop_names_and_ids])

      is_list(stop_names_and_ids) and "default" in stop_names_and_ids ->
        Changeset.cast(
          changeset,
          %{stop_names_and_ids: List.delete(stop_names_and_ids, "default")},
          [:stop_names_and_ids]
        )

      true ->
        changeset
    end
  end

  defp ensure_trip_ids(changeset) do
    trip_ids = Changeset.get_field(changeset, :trip_ids)

    cond do
      trip_ids in [nil, "default", ["default"]] ->
        Changeset.cast(changeset, %{trip_ids: []}, [:trip_ids])

      is_list(trip_ids) and "default" in trip_ids ->
        Changeset.cast(changeset, %{trip_ids: List.delete(trip_ids, "default")}, [:trip_ids])

      true ->
        changeset
    end
  end

  defp filter_stops_by_direction(changeset) do
    marker =
      case Changeset.get_field(changeset, :direction) do
        "0" -> ~r/inbound/
        "1" -> ~r/outbound/
        _ -> ~r/\A\Z/
      end

    stop_names_and_ids =
      changeset
      |> Changeset.get_field(:stop_names_and_ids)
      |> Enum.filter(&(!(&1 =~ marker)))

    Changeset.cast(
      changeset,
      %{stop_names_and_ids: stop_names_and_ids},
      [:stop_names_and_ids]
    )
  end

  defp split_stop_names_and_ids(changeset) do
    split_names_and_ids =
      Changeset.get_field(changeset, :stop_names_and_ids)
      |> Enum.reduce(%{stop_names: [], stop_ids: []}, fn name_and_id, acc ->
        case String.split(name_and_id, "|") do
          ["default"] ->
            acc

          [_, "default"] ->
            acc

          [stop_name, stop_id] ->
            %{stop_names: [stop_name | acc[:stop_names]], stop_ids: [stop_id | acc[:stop_ids]]}
        end
      end)

    Changeset.cast(changeset, split_names_and_ids, [:stop_names, :stop_ids])
  end

  def ensure_modal_date(changeset) do
    case Changeset.get_field(changeset, :modal_date) do
      "default" ->
        Changeset.change(changeset, modal_date: today())

      _ ->
        changeset
    end
  end

  def default_selections(selections \\ %Selections{}) do
    %{selections | service_dates: service_dates(), loading: true, today: today()}
  end

  defp build_detour_options(
         %{ok?: true, result: skate_detours},
         %{ok?: true, result: used_detours},
         form
       ) do
    {outbound, inbound} = Enum.split_with(skate_detours, &(&1.direction_id == 0))

    [outbound_options, inbound_options] =
      Enum.map(
        [outbound, inbound],
        fn detour ->
          SelectFormatter.formatted_select_options(%SelectFormatter{
            options: detour,
            search_term: form[:skate_search_term].value,
            route_type: 3,
            values_to_keep: form[:skate_detour_id].value || [],
            option_prefix: "detour-selector"
          })
          |> Enum.map(fn option ->
            matching_detour =
              Enum.find(used_detours, &(&1.skate_detour_id == Keyword.get(option, :value)))

            disable_option_if_matching_used_detour(matching_detour, option)
          end)
        end
      )

    if Enum.empty?(skate_detours) do
      []
    else
      %{
        Inbound: inbound_options,
        Outbound: outbound_options
      }
      |> Enum.reject(fn {_k, v} -> Enum.empty?(v) end)
    end
  end

  defp build_detour_options(_, _, _), do: []

  defp disable_option_if_matching_used_detour(nil, option), do: option

  defp disable_option_if_matching_used_detour(matching_detour, option) do
    option
    |> Keyword.put(:title, "Already associated with alert #{matching_detour.alert_id}")
    |> Keyword.put(:disabled, true)
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

  @spec bus_detour?(integer(), binary(), boolean() | nil) :: boolean()
  def bus_detour?(3, "detour", true), do: true

  def bus_detour?(_, _, _), do: false

  def render(assigns) do
    form = assigns.form

    bus_detour? =
      bus_detour?(
        form[:route_type].value,
        form[:effect_name].value,
        assigns.show_new_bus_detours
      )

    single_route_effect? = humanize_effect_name(form) in get_single_route_effect_names()

    skate_id_selected? = bus_detour? and !is_nil(form[:skate_detour_id].value)

    disable_stop_input? =
      disable_stop_input?(form[:route_ids].value, skate_id_selected?)

    route_field =
      if single_route_effect?, do: form[:single_route_id], else: form[:route_ids]

    skate_detour_options =
      if bus_detour? do
        build_detour_options(assigns.skate_detours, assigns.used_detours, form)
      else
        []
      end

    send(self(), {:adjust_optgroups, %{data: optgroups_to_adjust(skate_detour_options)}})

    assigns =
      assign(assigns,
        all_detours_used?:
          length(assigns.used_detours.result || []) == length(assigns.skate_detours.result || []),
        single_route_effect?: single_route_effect?,
        route_field: route_field,
        detours_loading?: !is_nil(assigns.skate_detours.loading),
        disable_stop_input?: disable_stop_input?,
        bus_detour?: bus_detour?,
        skate_detour_options: skate_detour_options,
        skate_id_selected?: skate_id_selected?
      )

    ~H"""
    <div class="min-w-full self-start flex flex-col" id="service_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Affected service
      </.h5>
      <div class={[
        "flex flex-row flex-wrap min-h-[38rem] md:min-h-[32rem] gap-y-4",
        @route_field.errors != [] && "mb-9",
        @form[:stop_names_and_ids].errors != [] && "mb-14 md:mb-16",
        @route_field.errors === [] && @form[:stop_names_and_ids].errors === [] && "mb-4"
      ]}>
        <div class={[
          "md:mb-0 w-full md:w-[25%] md:mr-8",
          @route_field.errors != [] && "mb-10"
        ]}>
          <.filtered_select
            label={if @form[:route_type].value in [0, 1, 2], do: "Lines", else: "Routes"}
            field={@route_field}
            filter_field={@form[:route_search_term]}
            loading={@selections.loading && @first_async_load}
            no_results={Enum.empty?(@selections.route_id_options)}
            options={@selections.route_id_options}
            class="h-full"
            multiple={!@single_route_effect?}
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
            modal_filter_active={date_filter_active?(@form[:modal_date].value, today())}
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
          class="flex flex-col justify-start w-full md:w-[25%] md:mr-8"
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
            disabled={@disable_stop_input?}
            modal_filter_disabled={@form[:route_ids].value in [nil, []]}
            prompt={if @disable_stop_input?, do: "", else: "Both Directions"}
            target_id="#alert_form"
          />
          <.filtered_select
            field={@form[:trip_ids]}
            filter_field={@form[:trip_search_term]}
            options={if @selections.loading, do: [], else: @selections.trip_id_options}
            loading={@selections.loading}
            loads_based_on={[@route_field.id, @form[:direction].id]}
            no_results={
              Enum.empty?(@selections.trip_id_options) &&
                !disable_trip_input?(@form[:route_ids].value)
            }
            class="min-w-full h-full"
            disabled={disable_trip_input?(@form[:route_ids].value)}
            prompt={if disable_trip_input?(@form[:route_ids].value), do: nil, else: "All Trips"}
          />
        </div>
        <div :if={@bus_detour?} class="flex flex-col justify-start w-full md:w-[30%]">
          <.filtered_select
            label="Detours from Skate"
            field={@form[:skate_detour_id]}
            filter_field={@form[:skate_search_term]}
            options={
              cond do
                is_nil(@form[:single_route_id].value) ->
                  []

                Enum.empty?(@skate_detour_options) && @all_detours_used? ->
                  ["No active detours in Skate"]

                true ->
                  @skate_detour_options
              end
            }
            disabled={@all_detours_used?}
            class="h-full md:mr-6"
            loading={@detours_loading?}
            multiple={false}
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
            disabled={@disable_stop_input?}
            prompt={if @disable_stop_input?, do: "", else: "Both Directions"}
          />
          <div
            :if={show_stops_input?(@form[:combination].value)}
            id="stop_names_and_ids_selector_wrapper"
            class="contents"
            phx-hook="FocusOutPush"
            data-focusout-event="stop_selector_blur"
          >
            <.filtered_select
              label={if show_trips_input?(@form[:combination].value), do: "Stops", else: nil}
              field={@form[:stop_names_and_ids]}
              selected={@form[:stop_names_and_ids].value}
              filter_field={@form[:stop_search_term]}
              options={if @selections.loading, do: [], else: @selections.stop_id_options}
              loading={@selections.loading}
              loads_based_on={
                if show_trips_input?(@form[:combination].value),
                  do: [@form[:trip_ids].id, @form[:direction].id],
                  else: [@route_field.id, @form[:direction].id]
              }
              no_results={
                Enum.empty?(@selections.stop_id_options) &&
                  !@disable_stop_input?
              }
              class="min-w-full h-full"
              disabled={@disable_stop_input?}
              prompt={
                cond do
                  @disable_stop_input? ->
                    nil

                  !AffectedServiceSlice.allow_selecting_all_stops?(@form.source) ->
                    nil

                  true ->
                    "All Stops"
                end
              }
            />
          </div>
        </div>
      </div>
      <div
        :if={@skate_id_selected?}
        class="p-2 rounded-sm max-w-[48rem] text-bold"
      >
        <p>
          <.icon name="hero-information-circle-solid" /> Selecting a detour from Skate will
          automatically:
        </p>
        <ul class="list-disc ml-8">
          <li>Select a direction</li>
          <li>Select missed stops</li>
          <li>
            Set this alert to close when the detour is
            closed in Skate
          </li>
        </ul>
      </div>
      <p :if={@show_stop_ids}>
        Selected stop ids: {(@form[:stop_ids].value || []) |> Enum.join(", ")} Selected route ids: {(@form[
                                                                                                       :route_ids
                                                                                                     ].value ||
                                                                                                       [])
        |> Enum.join(", ")} Selected trip ids: {(@form[:trip_ids].value || []) |> Enum.join(", ")} Selected skate detour: {@form[
          :skate_detour_id
        ].value}
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

  defp disable_stop_input?(_, true), do: true
  defp disable_stop_input?(nil, _), do: true
  defp disable_stop_input?(route_ids, _) when is_list(route_ids), do: length(route_ids) !== 1
  defp disable_stop_input?(_, _), do: true

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

  def on_filter_accept(socket) do
    async_assign_selections(socket, %{})
  end

  def on_filter_clear(socket) do
    {_, socket} =
      AlertData.sync(socket.assigns.form.source, socket, %{
        "alert_data" => %{"modal_date" => today(), "modal_date_search_term" => nil}
      })

    async_assign_selections(socket, %{})
  end

  defp optgroups_to_adjust(skate_detour_options) do
    skate_detour_options
    |> Enum.map(fn {key, value} ->
      all_disabled? = Enum.all?(value, &Keyword.get(&1, :disabled, false))
      if all_disabled?, do: key
    end)
    |> Enum.reject(&is_nil/1)
  end
end
