defmodule AlertsUI.AlertBuilder do
  @moduledoc """
    Builds an alert from form data

    All incoming times are naive datetimes created in the eastern timezone
    and need to be converted to UTC datetimes
  """

  alias AlertsUI.{ActivePeriodBuilder, Activities}
  alias AlertsUI.Helpers.Recurrence
  alias AlertsUI.Models.{ActivePeriod, Cause, Effect, InformedEntity, RoutePattern, SeverityLevel}
  alias AlertsUI.Routes
  alias AlertsUIWeb.FormComponents.Helpers.{SelectFormatter}
  alias AlertsUIWeb.CreateAlertLive.Helpers.{ServiceEffectCombinations}
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatterns
  alias MBTAV3API.RoutePatterns.RoutePattern, as: APIRoutePattern
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @green_line_branch_ids Routes.green_line_branch_ids()
  @special_combo_routes_map Routes.special_combo_routes_map()

  @type alert_data_t :: %{
          alert_id: String.t() | nil,
          route_type: Route.type_int() | nil,
          combination: atom(),
          facility_ids: [String.t()],
          direction: String.t(),
          route_ids: [Route.id_t()],
          stop_ids: [Stop.id_t()],
          stop_names_and_ids: [String.t()],
          stops_with_context: [stop_with_context_t()] | [],
          trip_ids: [String.t()],
          trip_information_by_id: trip_information_by_id_t(),
          service_types: [Route.type_int()],
          service_effect_text: String.t() | nil,
          alert_timing: atom(),
          active_period_end_specifier: atom() | nil,
          active_period_start_specifier: atom() | nil,
          active_period_start: NaiveDateTime.t() | nil,
          active_period_end: NaiveDateTime.t() | nil,
          active_period_start_date: Date.t() | nil,
          active_period_end_date: Date.t() | nil,
          active_period_start_time: Time.t() | nil,
          active_period_end_time: Time.t() | nil,
          cause: String.t() | atom() | nil,
          cause_detail: String.t() | nil,
          effect: String.t() | nil,
          effect_name: String.t() | nil,
          effect_detail: String.t() | nil,
          url: String.t() | nil,
          image_url: String.t() | nil,
          image_alternative_text: String.t() | nil,
          header_text: String.t(),
          description_text: String.t() | nil,
          banner_text: String.t() | nil,
          last_push_notification_timestamp: NaiveDateTime.t() | nil,
          notification_period_start: NaiveDateTime.t() | nil,
          notification_period_end: NaiveDateTime.t() | nil,
          notification_specifier: atom() | nil,
          severity: integer(),
          reminder_times: [NaiveDateTime.t()] | nil,
          recurrence_days: [atom()] | nil,
          route_types_by_id: %{optional(String.t()) => Route.type_int()},
          source: atom() | nil,
          closed_timestamp: NaiveDateTime.t() | nil,
          work_order_id: String.t() | nil,
          skate_detour_id: integer() | nil,
          status: nil | :open | :closed | :pending | :work_finished
        }
  @type direction_t :: 0 | 1
  @type stop_with_context_t :: {Stop.t(), Route.id_t(), direction_t(), RoutePattern.stop_type()}
  @type alert_changeset_params :: map()
  @type trip_information_by_id_t :: %{String.t() => trip_information_t()}
  @type trip_information_t :: %{
          direction_id: direction_t(),
          route_id: Route.id_t(),
          trip_name: String.t(),
          added_route_ids: [Route.id_t()]
        }

  @spec build_alert(
          alert_data_t(),
          ServiceEffectCombinations.service_effect_combination(),
          DateTime.t(),
          keyword()
        ) :: alert_changeset_params
  def build_alert(alert_data, combination, current_time \\ DateTime.utc_now(), options \\ []) do
    direct_from_alert_data_keys = [
      :header_text,
      :description_text,
      :service_effect_text,
      :banner_text,
      :url,
      :image_url,
      :image_alternative_text,
      :recurrence_days,
      :severity,
      :source,
      :created_timestamp,
      :closed_timestamp,
      :work_order_id,
      :skate_detour_id,
      :can_close_automatically
    ]

    Enum.reduce(direct_from_alert_data_keys, %{}, fn key, params ->
      Map.put(params, key, Map.get(alert_data, key, nil))
    end)
    |> Map.merge(%{current_time: current_time})
    |> Map.merge(recurrence_text(alert_data))
    |> Map.merge(last_push_notification_timestamp(alert_data, current_time))
    |> Map.merge(severity_level(alert_data))
    |> Map.merge(reminder_times(alert_data))
    |> Map.merge(plaintext_reminder_selections(alert_data))
    |> Map.merge(primary_service_type(alert_data))
    |> Map.merge(cause_and_effect(alert_data))
    |> Map.merge(original_selections(alert_data, combination, options))
    |> Map.merge(time_periods(alert_data, current_time, options))
    |> Map.merge(informed_entity(alert_data, combination, options))
    |> Map.merge(last_modified_timestamp(alert_data, current_time))
  end

  defp recurrence_text(alert_data) do
    recurrence_text =
      alert_data
      |> Map.get(:recurrence_days)
      |> Recurrence.recurrence_text_from_days()

    %{recurrence_text: recurrence_text}
  end

  defp last_modified_timestamp(%{last_modified_timestamp: last_modified_timestamp}, _)
       when not is_nil(last_modified_timestamp) do
    %{last_modified_timestamp: last_modified_timestamp}
  end

  defp last_modified_timestamp(_alert_data, current_time) do
    %{last_modified_timestamp: current_time}
  end

  defp last_push_notification_timestamp(%{notification_toggle: false} = alert_data, _current_time) do
    # if notification toggle is false, keep original LPNT (default to nil if there is no original)
    original_last_push_notification_timestamp =
      Map.get(alert_data, :last_push_notification_timestamp)

    %{last_push_notification_timestamp: original_last_push_notification_timestamp}
  end

  defp last_push_notification_timestamp(_alert_data, current_time) do
    # if notification toggle is true, LPNT is set to current time
    %{last_push_notification_timestamp: current_time}
  end

  defp primary_service_type(alert_data) do
    %{
      primary_service_type:
        primary_service_type(
          Map.get(alert_data, :route_type),
          Map.get(alert_data, :combination)
        )
    }
  end

  defp severity_level(alert_data) do
    severity_level =
      alert_data
      |> Map.get(:severity)
      |> SeverityLevel.severity_level_by_severity()

    %{severity_level: severity_level}
  end

  defp reminder_times(alert_data) do
    if Map.get(alert_data, :source) == :IBI do
      %{}
    else
      reminder_times =
        Map.get(alert_data, :reminder_times, [])
        |> Enum.map(
          &%{
            id: &1.id,
            reminder_time:
              ActivePeriodBuilder.naive_eastern_datetime_to_utc(reminder_time_value(&1))
          }
        )

      %{reminder_times: reminder_times}
    end
  end

  defp plaintext_reminder_selections(alert_data) do
    plaintext_reminder_selections =
      Map.get(alert_data, :reminder_times, [])
      |> Enum.map_join(", ", &Calendar.strftime(reminder_time_value(&1), "%Y-%m-%dT%H:%M:%S"))

    %{plaintext_reminder_selections: plaintext_reminder_selections}
  end

  defp reminder_time_value(rt), do: Map.get(rt, :reminder_time) || Map.get(rt, :time)

  defp cause_and_effect(alert_data) do
    route_type = Map.get(alert_data, :route_type)

    route_type =
      if is_nil(route_type) and Map.get(alert_data, :combination) == :ACCESS do
        :ACCESS
      else
        route_type
      end

    cause_detail = Map.get(alert_data, :cause_detail, "")
    cause = Map.get(alert_data, :cause, Cause.get_by_mode_and_detail(route_type, cause_detail))
    effect_name = Map.get(alert_data, :effect_name)
    # if `effect` is specified in `alert_data`, we bypass the call to `effect_map_by_name/1`
    # and pass along `effect_detail` as given
    {effect, effect_detail} =
      case {Map.get(alert_data, :effect), Map.get(alert_data, :effect_detail)} do
        {nil, _} ->
          effect_map = Effect.effect_map_by_name(effect_name)
          {Map.get(effect_map, :effect), Map.get(effect_map, :effect_detail)}

        {effect, effect_detail} ->
          {effect, effect_detail}
      end

    effect = maybe_modify_effect(effect_name, Map.get(alert_data, :stop_ids), effect)

    %{
      cause: cause,
      cause_detail: cause_detail,
      effect: effect,
      effect_detail: effect_detail,
      effect_name: effect_name
    }
  end

  defp maybe_modify_effect("Suspension", [], _), do: :NO_SERVICE
  defp maybe_modify_effect(_effect_name, _stop_ids, effect), do: effect

  def original_selections(alert_data, combination, options \\ []) do
    if Keyword.get(options, :no_original_selections) do
      original_selections_from_import(alert_data)
    else
      original_selections_from_form(alert_data, combination)
    end
  end

  defp original_selections_from_import(alert_data) do
    alert_data
    |> Map.put(
      :original_stop_selections,
      Map.get(alert_data, :stop_names_and_ids)
    )
    |> Map.take([
      :original_direction_selections,
      :original_route_selections,
      :original_stop_selections,
      :original_trip_selections,
      :original_facility_selections,
      :original_mode_selections
    ])
  end

  defp original_selections_from_form(alert_data, combination) do
    # used to generate original_direction_selections, original_route_selection, routes, etc.
    selected_routes = Map.get(alert_data, :route_ids, [])
    # direction_id needed for original_direction_selections, stops_with_context
    direction_id = Map.get(alert_data, :direction)

    # the original route and direction selections are meant to reflect the routes that the user
    # selected from the form, so we create them here before combo routes are
    # added to our list of routes

    original_direction_selections =
      if combination in [:RDS, :RDT, :RDTS] do
        [
          direction_name(selected_routes, pre_combo_routes(selected_routes), direction_id) <>
            "|" <> (direction_id || "")
        ]
      else
        nil
      end

    original_route_selections =
      (selected_routes || [])
      |> Enum.map(fn route_id ->
        matching_route = get_matching_route(route_id, pre_combo_routes(selected_routes))
        "#{SelectFormatter.name_for_option(matching_route)}|#{route_id}"
      end)

    original_stop_selections = Map.get(alert_data, :stop_names_and_ids, [])

    original_trip_selections =
      (Map.get(alert_data, :trip_information_by_id, %{}) || %{})
      |> Enum.map(fn {id, trip} ->
        "#{Map.get(trip, :trip_name, "")}|#{id}"
      end)

    original_facility_selections =
      case Map.get(alert_data, :facility_ids) do
        nil ->
          []

        [] ->
          []

        facility_ids ->
          %{effect_detail: effect_detail} =
            Effect.effect_map_by_name(alert_data.effect_name)

          facility_types = InformedEntity.facility_effect_to_types(effect_detail)

          FacilitiesRepo.get_by_type(facility_types, include: "stop")
          |> Enum.filter(&(&1.id in facility_ids))
          |> Enum.map(fn
            nil -> nil
            facility -> "#{SelectFormatter.name_for_option(facility)}|#{facility.id}"
          end)
          |> Enum.reject(&is_nil/1)
      end

    original_mode_selections = Map.get(alert_data, :service_types, [])

    %{
      original_direction_selections: original_direction_selections,
      original_route_selections: original_route_selections,
      original_stop_selections: original_stop_selections,
      original_trip_selections: original_trip_selections,
      original_facility_selections: original_facility_selections,
      original_mode_selections: original_mode_selections
    }
  end

  defp time_periods(alert_data, current_time, options) do
    active_period_map = active_periods(alert_data, current_time, options)
    # Notification period calculations are dependent on the processed active period values
    # especially for recurring alerts.
    # (In build_recurring_active_period, active_period_end is discarded if the alert is :until_further_notice
    # If we use alert_data here instead of the updated active_period_map, it will wrongfully set
    # a notification_period_end in this case, when it should actually be nil for :until_further_notice.)
    Map.merge(alert_data, active_period_map)
    |> notification_periods(current_time)
    |> Map.merge(active_period_map)
  end

  defp active_periods(alert_data, current_time, options) do
    if Keyword.get(options, :no_active_periods) do
      recurring = Map.get(alert_data, :alert_timing) == :recurring

      Map.take(
        alert_data,
        [
          :active_period_start,
          :active_period_end,
          :duration_certainty,
          :recurrence_start_time,
          :recurrence_end_time,
          :recurrence_days
        ]
      )
      |> Map.put(:recurring, recurring)
    else
      if Map.get(alert_data, :alert_timing) === :recurring do
        ActivePeriodBuilder.build_recurring_active_period(%{
          active_period_start_time: Map.get(alert_data, :active_period_start_time),
          active_period_end_time: Map.get(alert_data, :active_period_end_time),
          active_period_start_date: Map.get(alert_data, :active_period_start_date),
          active_period_end_date: Map.get(alert_data, :active_period_end_date),
          active_period_end_specifier: Map.get(alert_data, :active_period_end_specifier),
          recurrence_days: Map.get(alert_data, :recurrence_days)
        })
      else
        ActivePeriodBuilder.build_one_time_active_period(
          %{
            active_period_start: Map.get(alert_data, :active_period_start),
            active_period_end: Map.get(alert_data, :active_period_end),
            active_period_end_specifier: Map.get(alert_data, :active_period_end_specifier),
            active_period_start_specifier: Map.get(alert_data, :active_period_start_specifier)
          },
          current_time
        )
      end
    end
  end

  defp notification_periods(alert_data, current_time) do
    notification_period_start =
      if Map.get(alert_data, :notification_specifier) === :now do
        current_time
      else
        # if notification period has not been set, use active_period_start
        if Map.get(alert_data, :notification_period_start) do
          Map.get(alert_data, :notification_period_start)
          |> ensure_utc_or_nil()
        else
          Map.get(alert_data, :active_period_start)
          |> ensure_utc_or_nil()
        end
      end

    notification_period_end =
      cond do
        Map.get(alert_data, :notification_period_end) && Map.get(alert_data, :source) == :IBI ->
          Map.get(alert_data, :notification_period_end)
          |> ensure_utc_or_nil()

        Map.get(alert_data, :active_period_end_specifier) === :later_today ->
          ActivePeriod.end_of_service_datetime_utc(current_time)

        true ->
          Map.get(alert_data, :active_period_end)
          |> ensure_utc_or_nil()
      end

    %{
      notification_period_start: notification_period_start,
      notification_period_end: notification_period_end,
      notification_duration_certainty: Map.get(alert_data, :notification_duration_certainty)
    }
  end

  defp informed_entity(alert_data, combination, options) do
    if Keyword.get(options, :no_informed_entities) do
      %{informed_entity: nil}
    else
      service_types = Map.get(alert_data, :service_types, []) |> expand_subway_service_types()
      direction = Map.get(alert_data, :direction)

      selected_stop_ids = Map.get(alert_data, :stop_ids, [])
      selected_route_ids = Map.get(alert_data, :route_ids, [])

      routes =
        selected_route_ids
        |> pre_combo_routes()
        |> Enum.reject(&(&1 == %{}))
        |> add_combo_routes(direction)
        |> maybe_remove_green_line_routes(
          selected_route_ids,
          selected_stop_ids,
          alert_data.effect_name
        )

      route_ids = Enum.map(routes, & &1.id)

      route_types_by_id =
        routes
        |> Enum.reduce(%{}, fn route, acc ->
          Map.put(acc, route.id, route.type)
        end)

      stops_with_context =
        stops_with_context(
          routes,
          direction,
          selected_stop_ids
        )

      entity_data =
        Map.merge(alert_data, %{
          stops_with_context: stops_with_context,
          route_ids: route_ids,
          service_types: service_types,
          route_types_by_id: route_types_by_id
        })

      informed_entities =
        combination
        |> build_informed_entities(entity_data, Map.get(alert_data, :effect_name))
        |> maybe_add_boat_f1()
        |> Enum.uniq()

      %{informed_entity: informed_entities}
    end
  end

  @spec add_combo_routes([Route.t()], String.t()) :: [Route.t()]

  defp add_combo_routes(selected_routes, direction) do
    # For every route, make an API call to
    # get its route pattern, which gets `included`
    # with a "listed route" value of "false".
    # These are our combo routes

    combo_routes =
      selected_routes
      |> Enum.flat_map(fn original_route ->
        original_route.id
        |> get_route_patterns(direction, original_route.type)
        |> Enum.filter(&(&1.listed_route == false))
        |> Enum.map(& &1.route_id)
        |> Enum.reject(&is_nil/1)
        |> add_special_combo_routes(original_route.id)
      end)
      |> Enum.uniq()
      |> Enum.map(&RoutesRepo.get(&1, []))
      # filter out shuttle routes
      |> Enum.filter(&(&1.description !== :rail_replacement_bus))

    selected_routes ++ combo_routes
  end

  def add_special_combo_routes(route_ids, route_id) do
    added_routes = Map.get(@special_combo_routes_map, route_id, [])
    route_ids |> Enum.concat(added_routes)
  end

  defp maybe_remove_green_line_routes(routes, ["Green"], [_ | _] = selected_stop_ids, effect)
       when effect in ["Shuttle", "Suspension"] do
    # the intention here is to NOT include a green line route
    # for shuttle and suspension alerts if the user has
    # selected "Green" but one of the green line routes
    # only has 1 selected stop on it. This probably
    # means that the selected stop is a shared node
    # and the branch in question isn't actually closed.
    route_ids_to_remove =
      routes
      |> Enum.map(& &1.id)
      |> Enum.filter(fn
        route_id when route_id in @green_line_branch_ids ->
          {_, stops_on_route} = stops_on_route(route_id, "default")

          selected_stops_on_route =
            stops_on_route |> Enum.filter(&(&1.id in selected_stop_ids)) |> Enum.uniq() |> length

          selected_stops_on_route <= 1

        _route_id ->
          true
      end)

    Enum.reject(routes, &(&1.id in route_ids_to_remove))
  end

  defp maybe_remove_green_line_routes(routes, _selected_route_ids, _selected_stop_ids, _effect) do
    routes
  end

  # Special request that Boat-F1 be added to all Boat-F2H trip entities
  defp maybe_add_boat_f1(informed_entities) do
    f2h_entities =
      Enum.filter(informed_entities, fn entity -> Map.get(entity, :route_id) === "Boat-F2H" end)

    added_f1_entities =
      Enum.map(f2h_entities, fn entity ->
        f1_entity = %{entity | route_id: "Boat-F1"}
        f2h_trip = Map.get(entity, :trip)

        if f2h_trip != nil do
          %{f1_entity | trip: %{f2h_trip | route_id: "Boat-F1"}}
        else
          f1_entity
        end
      end)

    informed_entities |> Enum.concat(added_f1_entities)
  end

  @spec stops_with_context([Route.id_t()], String.t(), [Stop.id_t()]) ::
          [
            stop_with_context_t()
          ]

  defp stops_with_context(routes, direction, parent_stop_ids) do
    parent_stops =
      StopsRepo.all(["filter[id]": Enum.join(parent_stop_ids, ",")], [])
      |> Enum.into(%{}, fn stop -> {stop.id, stop} end)

    routes
    |> Enum.flat_map(fn route ->
      route_patterns =
        route.id
        # get relevant route patterns for the routes
        # so we can look at their representative trips
        |> get_route_patterns(direction, route.type)

      child_stops_context =
        route_patterns
        # remove route patterns for branches we don't want
        |> filtered_route_patterns(parent_stop_ids)
        |> Enum.flat_map(fn route_pattern ->
          route_pattern_stops_with_context_for_parents(
            # build list of stops we want to include
            route_pattern,
            route.id,
            parent_stop_ids,
            route.type
          )
        end)

      neighbor_stops =
        get_neighbor_stops(child_stops_context, route_patterns, parent_stop_ids, route)

      parent_stops_context =
        child_stops_context
        |> Enum.map(fn {child_stop, child_route, child_direction, child_stop_type} ->
          {parent_stops[child_stop.parent_id], child_route, child_direction, child_stop_type}
        end)
        |> Enum.reject(fn {stop, _, _, _} -> is_nil(stop) end)

      (child_stops_context ++ neighbor_stops ++ parent_stops_context)
      |> Enum.uniq()
    end)
  end

  defp get_neighbor_stops(child_stops_with_context, route_patterns, parent_stop_ids, route)
       when route.type in [0, 1, 2] do
    # in the case of Subway & CR, detect platforms at the nodes of branches that
    # need to be included in informed entities
    all_route_pattern_stops =
      route_patterns
      |> Enum.map(& &1.stops)

    Enum.map(child_stops_with_context, fn {child_stop, _, child_direction, _} ->
      # get all stops next to our selected stops
      get_neighbors_for_direction(all_route_pattern_stops, child_stop, child_direction)
    end)
    |> List.flatten()
    |> Enum.reject(fn {neighbor_stop, _direction} ->
      # if it's in our list of child stops already it's not a neighbor
      neighbor_stop.id in Enum.map(child_stops_with_context, fn {s, _, _, _} -> s.id end)
    end)
    |> Enum.filter(fn {neighbor_stop, _direction} ->
      # don't include neighbor stop if its parent isn't in our list of selected parent ids
      # (to avoid pulling in stops from stations we don't want to alert on)
      neighbor_stop.parent_id in parent_stop_ids
    end)
    |> Enum.map(fn {neighbor_stop, direction} ->
      {
        neighbor_stop,
        route.id,
        direction,
        if(direction == 0, do: :last, else: :first)
      }
    end)
  end

  defp get_neighbor_stops(_, _, _, _), do: []

  defp get_neighbors_for_direction(stops_list, stop, direction) when direction == 1 do
    # we have to reverse the route pattern list for inbound direction
    stops_list
    |> Enum.map(&Enum.reverse/1)
    |> get_neighbors(stop, direction)
  end

  defp get_neighbors_for_direction(stops_list, stop, direction) do
    get_neighbors(stops_list, stop, direction)
  end

  defp get_neighbors(stops_list, stop, direction) do
    stops_list
    |> Enum.map(fn stops ->
      index = Enum.find_index(stops, fn s -> s.id === stop.id end)

      if index && length(stops) >= index - 1 do
        Enum.at(stops, index + 1)
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.map(&{&1, direction})
  end

  @spec filtered_route_patterns([APIRoutePattern.t()], [Stop.id_t()]) :: [
          APIRoutePattern.t()
        ]
  defp filtered_route_patterns(route_patterns, parent_stop_ids) do
    # determines which route patterns to use in the case of a route with
    # multiple branches and thus multiple patterns (eg red line)
    # Uses 1 route pattern if only one has all the stops on it,
    # otherwise uses all of them.
    route_pattern_match =
      route_patterns
      |> Enum.filter(fn route_pattern ->
        stops_from_route_pattern = Enum.map(route_pattern.stops, & &1.id)
        parents_from_route_pattern = Enum.map(route_pattern.stops, & &1.parent_id)

        Enum.all?(parent_stop_ids, fn stop_id ->
          stop_id in (parents_from_route_pattern ++ stops_from_route_pattern)
        end)
      end)

    if Enum.empty?(route_pattern_match) do
      route_patterns
    else
      route_pattern_match
    end
  end

  @spec get_route_patterns(Route.id_t(), String.t(), integer()) :: [APIRoutePattern.t()]
  defp get_route_patterns(route_id, direction, 3) do
    opts =
      [include: "representative_trip.stops,route"]
      |> route_pattern_direction_opts(direction)

    RoutePatterns.by_route_id(route_id, opts)
  end

  # For subway, we only want canonical routes
  defp get_route_patterns(route_id, direction, route_type) when route_type in [0, 1] do
    opts =
      [include: "representative_trip.stops,route", "filter[canonical]": true]
      |> route_pattern_direction_opts(direction)

    route_id
    |> RoutePatterns.by_route_id(opts)
    |> Enum.reject(&String.contains?(&1.id, "Shuttle"))
  end

  defp get_route_patterns(route_id, direction, _route_type) do
    opts =
      [include: "representative_trip.stops,route"]
      |> route_pattern_direction_opts(direction)

    route_id
    |> RoutePatterns.by_route_id(opts)
    |> Enum.reject(&String.contains?(&1.id, "Shuttle"))
  end

  @spec route_pattern_direction_opts(keyword(), String.t()) :: keyword()
  defp route_pattern_direction_opts(opts, "default"), do: opts

  defp route_pattern_direction_opts(opts, direction),
    do: Keyword.put(opts, :direction_id, direction)

  @spec route_pattern_stops_with_context_for_parents(
          APIRoutePattern.t(),
          Route.id_t(),
          [
            Stop.id_t()
          ],
          Route.type_int()
        ) :: [
          stop_with_context_t()
        ]

  defp route_pattern_stops_with_context_for_parents(
         route_pattern,
         route_id,
         parent_stop_ids,
         route_type
       ) do
    route_pattern
    # get just stops from route pattern
    |> RoutePattern.stops()
    # filter out unwanted stops
    |> filter_route_pattern_stops(parent_stop_ids, route_type)
    # return stop along with important info (stop type determines activities)
    |> Enum.map(fn child_stop ->
      {
        child_stop,
        route_id,
        route_pattern.direction_id,
        RoutePattern.stop_type(route_pattern, parent_stop_ids, child_stop)
      }
    end)
  end

  defp filter_route_pattern_stops(stops, parent_stop_ids, 3) do
    # for bus, keep stops from route pattern that are in our parent_ids
    # or have a parent in our parent ids
    stops
    |> Enum.filter(fn stop ->
      stop.parent_id in parent_stop_ids or stop.id in parent_stop_ids
    end)
  end

  defp filter_route_pattern_stops(stops, parent_stop_ids, _route_type) do
    # for other modes, keep stops from route pattern whose
    # parent is in our list of parent ids
    # we were formerly checking that the stop vehicle type == the route type
    stops
    |> Enum.filter(fn stop ->
      stop.parent_id in parent_stop_ids
    end)
  end

  defp expand_subway_service_types(service_types) do
    service_types
    |> Enum.flat_map(fn service_type ->
      if service_type == 1 do
        [0, 1]
      else
        [service_type]
      end
    end)
    |> Enum.uniq()
  end

  @spec build_informed_entities(
          ServiceEffectCombinations.service_effect_combination() | nil,
          alert_data_t(),
          Effect.effect_name()
        ) ::
          [map()]
  # Systemwide, all service types
  def build_informed_entities(nil, %{service_types: []}, effect) do
    [
      %{
        activities: Activities.for_effect(effect),
        agency_id: "1"
      }
    ]
  end

  # Systemwide, specified service types
  def build_informed_entities(nil, %{service_types: service_types}, effect) do
    Enum.map(
      service_types,
      fn service_type ->
        %{
          activities: Activities.for_effect(effect),
          route_type: service_type,
          agency_id: "1"
        }
      end
    )
  end

  def build_informed_entities(:ACCESS, %{facility_ids: facility_ids}, effect_name) do
    %{effect_detail: effect_detail} = Effect.effect_map_by_name(effect_name)
    facility_types = InformedEntity.facility_effect_to_types(effect_detail)

    FacilitiesRepo.get_by_type(facility_types, include: "stop")
    |> Enum.filter(&(&1.id in facility_ids))
    |> Enum.flat_map(&build_facility_maps(&1, effect_name))
  end

  def build_informed_entities(
        :R,
        %{
          route_ids: route_ids,
          direction: direction,
          route_type: route_type,
          route_types_by_id: route_types_by_id
        },
        effect
      ) do
    route_ids
    |> Routes.expanding_green_line()
    |> Enum.map(
      &(%{
          activities: Activities.for_effect(effect),
          route_id: &1,
          route_type: route_type(route_types_by_id, &1, route_type),
          agency_id: Routes.agency_id(&1)
        }
        |> maybe_add_direction(direction))
    )
  end

  # No stops, treat like :R
  def build_informed_entities(:RDS, %{stop_ids: []} = alert_data, effect),
    do: build_informed_entities(:R, alert_data, effect)

  # Did not get stops from route patterns (fallback)
  def build_informed_entities(
        :RDS,
        %{
          stops_with_context: [],
          route_ids: route_ids,
          route_types_by_id: route_types_by_id,
          route_type: route_type,
          direction: direction,
          stop_ids: stop_ids
        },
        effect
      ) do
    stop_ids
    |> stop_route_pairs(route_ids)
    |> Enum.map(fn {stop_id, route_id} ->
      %{
        activities: Activities.for_effect(effect),
        route_id: route_id,
        route_type: route_type(route_types_by_id, route_id, route_type),
        agency_id: Routes.agency_id(route_id),
        stop_id: stop_id
      }
      |> maybe_add_direction(direction)
    end)
  end

  # Child stops from route pattern
  def build_informed_entities(
        :RDS,
        %{
          stops_with_context: [_ | _] = stops_with_context,
          route_types_by_id: route_types_by_id,
          route_type: route_type
        },
        effect
      ) do
    stops_with_context
    |> Enum.map(fn {%Stop{id: stop_id}, route_id, direction_id, stop_type} ->
      %{
        activities: Activities.for_effect(effect, stop_type),
        direction_id: direction_id,
        route_id: route_id,
        route_type: route_type(route_types_by_id, route_id, route_type),
        agency_id: Routes.agency_id(route_id),
        stop_id: stop_id
      }
    end)
    |> Enum.uniq()
  end

  def build_informed_entities(
        :RDT,
        %{trip_ids: []} = alert_data,
        effect
      ) do
    build_informed_entities(:R, alert_data, effect)
  end

  def build_informed_entities(
        :RDT,
        %{
          trip_ids: [_ | _] = trip_ids,
          route_type: route_type,
          trip_information_by_id: trip_information_by_id
        },
        effect
      ) do
    trip_ids
    |> Enum.flat_map(fn trip_id ->
      %{
        direction_id: direction_id,
        route_id: route_id,
        added_route_ids: added_route_ids
      } = trip_information_by_id[trip_id]

      entity = %{
        activities: Activities.for_effect(effect),
        route_id: route_id,
        route_type: route_type,
        agency_id: Routes.agency_id(route_id),
        trip:
          build_trip(
            trip_id,
            direction_id,
            route_id
          )
      }

      [entity] ++ build_alternate_route_entities(trip_id, entity, added_route_ids)
    end)
  end

  def build_informed_entities(:RDTS, %{stop_ids: [], trip_ids: []} = alert_data, effect),
    do: build_informed_entities(:R, alert_data, effect)

  def build_informed_entities(:RDTS, %{stop_ids: []} = alert_data, effect),
    do: build_informed_entities(:RDT, alert_data, effect)

  def build_informed_entities(:RDTS, %{trip_ids: []} = alert_data, effect),
    do: build_informed_entities(:RDS, alert_data, effect)

  # Did not get stops from route patterns (fallback)
  def build_informed_entities(
        :RDTS,
        %{
          stop_ids: [_ | _] = stop_ids,
          stops_with_context: [],
          trip_ids: [_ | _] = _trip_ids,
          route_type: route_type,
          route_ids: route_ids,
          trip_information_by_id: trip_information_by_id
        },
        effect
      ) do
    stop_ids
    |> stop_route_pairs(route_ids)
    |> Enum.flat_map(fn {stop_id, route_id} ->
      trip_information_by_id
      |> Enum.flat_map(fn {trip_id, info} ->
        entity = %{
          activities: Activities.for_effect(effect),
          route_id: route_id,
          route_type: route_type,
          agency_id: Routes.agency_id(route_id),
          trip:
            build_trip(
              trip_id,
              info.direction_id,
              route_id
            ),
          stop_id: stop_id
        }

        [entity] ++
          build_alternate_route_entities(trip_id, entity, info.added_route_ids)
      end)
    end)
    |> Enum.uniq()
  end

  # Child stops from route patterns
  def build_informed_entities(
        :RDTS,
        %{
          stops_with_context: [_ | _] = stops_with_context,
          trip_ids: [_ | _] = _trip_ids,
          route_type: route_type,
          trip_information_by_id: trip_information_by_id
        },
        effect
      ) do
    trip_directions = trip_directions(trip_information_by_id)

    stops_with_context
    |> Enum.filter(fn {_, _, stop_direction_id, _} ->
      Enum.member?(trip_directions, stop_direction_id)
    end)
    |> Enum.flat_map(fn {%Stop{id: stop_id}, route_id, _direction_id, _stop_type} ->
      trip_information_by_id
      |> Enum.flat_map(fn {trip_id, info} ->
        entity =
          %{
            activities: Activities.for_effect(effect),
            route_id: route_id,
            route_type: route_type,
            agency_id: Routes.agency_id(route_id),
            trip:
              build_trip(
                trip_id,
                info.direction_id,
                route_id
              ),
            stop_id: stop_id
          }

        [entity] ++
          build_alternate_route_entities(trip_id, entity, info.added_route_ids)
      end)
    end)
    |> Enum.uniq()
  end

  def build_informed_entities(
        :SR,
        %{
          stops_with_context: [_ | _] = stops_with_context,
          route_types_by_id: route_types_by_id,
          route_type: route_type
        },
        effect
      ) do
    stops_with_context
    |> Enum.filter(fn {%Stop{parent_id: parent_id, id: id}, route_id, _, _} ->
      id_to_use = if parent_id, do: parent_id, else: id
      on_route?({id_to_use, route_id}, "default")
    end)
    |> Enum.map(fn {%Stop{id: stop_id}, route_id, _direction_id, _stop_type} ->
      %{
        activities: Activities.for_effect(effect),
        route_id: route_id,
        route_type: route_type(route_types_by_id, route_id, route_type),
        agency_id: Routes.agency_id(route_id),
        stop_id: stop_id
      }
    end)
    |> Enum.uniq()
  end

  def build_informed_entities(
        :SR,
        %{
          stop_ids: stop_ids,
          route_ids: route_ids,
          route_types_by_id: route_types_by_id,
          route_type: route_type,
          stops_with_context: []
        },
        effect
      ) do
    route_ids = Routes.expanding_green_line(route_ids)

    stop_ids
    |> stop_route_pairs(route_ids)
    |> Enum.filter(&on_route?(&1, "default"))
    |> Enum.map(fn {stop_id, route_id} ->
      %{
        activities: Activities.for_effect(effect),
        route_id: route_id,
        route_type: route_type(route_types_by_id, route_id, route_type),
        agency_id: Routes.agency_id(route_id),
        stop_id: stop_id
      }
    end)
  end

  def build_informed_entities(_mode, _data, _effect), do: []

  @spec build_alternate_route_entities(
          Trip.id_t(),
          map(),
          [Route.id_t()]
        ) :: [map()]
  defp build_alternate_route_entities(trip_id, entity, added_route_ids) do
    added_route_ids
    |> Enum.map(fn route_id ->
      %{
        entity
        | route_id: route_id,
          trip: build_trip(trip_id, entity.trip.direction_id, route_id)
      }
    end)
  end

  @spec trip_directions(trip_information_by_id_t()) :: [Trip.direction_id_t()]
  defp trip_directions(trip_information_by_id) do
    trip_information_by_id
    |> Enum.map(fn {_trip_id, info} -> info.direction_id end)
    |> Enum.uniq()
  end

  defp build_trip(trip_id, direction_id, route_id) do
    %{
      trip_id: trip_id,
      direction_id: direction_id,
      route_id: route_id
    }
  end

  defp maybe_add_direction(informed_entity, nil), do: informed_entity
  defp maybe_add_direction(informed_entity, "default"), do: informed_entity

  defp maybe_add_direction(informed_entity, direction_id) do
    informed_entity
    |> Map.put(:direction_id, direction_id |> String.to_integer())
  end

  defp stop_route_pairs(stop_ids, route_ids) do
    Enum.flat_map(stop_ids, fn stop_id ->
      Enum.map(route_ids, fn route_id -> {stop_id, route_id} end)
    end)
  end

  defp build_facility_maps(
         %Facility{stop: %Stop{id: stop_id}, id: facility_id, properties: properties},
         effect
       ) do
    stop = StopsRepo.get!(stop_id)

    child_stop_ids =
      (stop.child_ids -- excluded_stops_from_facility_properties(properties)) |> Enum.uniq()

    # fallback for rare cases the stop has no child stops (eg fare vending machines)
    child_stop_ids = if Enum.empty?(child_stop_ids), do: [stop_id], else: child_stop_ids

    routes_from_children =
      child_stop_ids
      |> Enum.join(",")
      |> RoutesRepo.by_stop()

    routes_from_parent =
      RoutesRepo.by_stop(stop.id)

    # use route_ids from parent stop if none are associated with children
    routes_from_children =
      if Enum.empty?(routes_from_children), do: routes_from_parent, else: routes_from_children

    child_entities =
      build_facility_entities_from_routes(
        routes_from_children,
        child_stop_ids,
        facility_id,
        effect
      )

    parent_entities =
      build_facility_entities_from_routes(routes_from_parent, [stop.id], facility_id, effect)

    child_entities ++ parent_entities
  end

  defp build_facility_maps(%Facility{stop: nil, id: facility_id}, effect) do
    [
      %{
        activities: Activities.for_effect(effect),
        facility_id: facility_id
      }
    ]
  end

  defp build_facility_entities_from_routes(routes, stop_ids, facility_id, effect) do
    routes =
      routes
      |> Enum.filter(&(&1.description !== :rail_replacement_bus))
      |> Enum.map(&[id: &1.id, type: &1.type])
      |> Enum.uniq()

    stop_ids
    |> Enum.flat_map(fn stop_id ->
      Enum.map(routes, fn [id: route_id, type: route_type] ->
        %{
          activities: Activities.for_effect(effect),
          facility_id: facility_id,
          route_id: route_id,
          route_type: route_type,
          stop_id: stop_id
        }
      end)
    end)
  end

  @spec on_route?({Stop.id_t(), Route.id_t()}, String.t()) :: boolean()
  defp on_route?({stop_id, route_id}, direction) do
    case stops_on_route(route_id, direction) do
      {:ok, stops_on_route} ->
        Enum.find(stops_on_route, fn stop -> stop.id == stop_id end) != nil

      _ ->
        false
    end
  end

  @spec stops_on_route(Route.id_t(), String.t()) :: {:ok, [Stop.t()]} | {:error, any}
  defp stops_on_route(route_id, "default") do
    with {:ok, stops_0} <- stops_on_route(route_id, "0"),
         {:ok, stops_1} <- stops_on_route(route_id, "1") do
      {:ok, stops_0 ++ stops_1}
    end
  end

  defp stops_on_route(route_id, direction) do
    case StopsRepo.by_route(route_id, String.to_integer(direction)) do
      {:error, error} ->
        {:error, error}

      stops ->
        {:ok, stops}
    end
  end

  @spec route_type(%{String.t() => Route.type_int()}, Route.id_t(), Route.id_t()) ::
          Route.type_int()

  defp route_type(route_types_by_id, route_id, primary_route_type) do
    if route_id in @green_line_branch_ids do
      route_types_by_id[route_id] || route_types_by_id["Green"]
    else
      # if for any reason we don't have the route type in the map
      # use the primary route type. This will cover eg combo routes
      Map.get(route_types_by_id, route_id, primary_route_type)
    end
  end

  defp get_matching_route("Green", _), do: RoutesRepo.green_line()

  defp get_matching_route(route_id, routes) do
    Enum.find(routes, %{}, fn route -> Map.get(route, :id, "") == route_id end)
  end

  defp primary_service_type(nil, nil), do: "systemwide"
  defp primary_service_type(nil, :ACCESS), do: "access"
  defp primary_service_type(route_type, _combination), do: Integer.to_string(route_type)

  @spec excluded_stops_from_facility_properties([map()]) :: [String.t()]
  defp excluded_stops_from_facility_properties(properties) do
    Enum.reduce(properties, [], fn %{name: name, value: value}, acc ->
      if name == "excludes-stop", do: [maybe_integer_to_string(value) | acc], else: acc
    end)
  end

  @spec maybe_integer_to_string(integer() | String.t()) :: String.t()
  defp maybe_integer_to_string(value) when is_integer(value), do: Integer.to_string(value)
  defp maybe_integer_to_string(value), do: value

  defp direction_name(_, _, "default"), do: "Both"

  defp direction_name([route_id], routes, direction_id) when is_binary(direction_id) do
    matching_route = get_matching_route(route_id, routes)
    direction_map = Map.get(matching_route, :direction_names, %{0 => "Outbound", 1 => "Inbound"})
    direction_map[String.to_integer(direction_id)]
  end

  defp direction_name(_, _, nil), do: ""

  defp direction_name(_, _, direction_id) do
    Map.get(
      %{
        "0" => "Outbound",
        "1" => "Inbound"
      },
      direction_id,
      ""
    )
  end

  defp pre_combo_routes(selected_routes) do
    selected_routes
    |> Enum.filter(&(&1 !== "default"))
    |> Enum.uniq()
    |> Routes.expanding_green_line()
    |> Enum.map(&(RoutesRepo.get(&1, []) || %{}))
  end

  defp ensure_utc_or_nil(%NaiveDateTime{} = timestamp) do
    ActivePeriodBuilder.naive_eastern_datetime_to_utc(timestamp)
  end

  defp ensure_utc_or_nil(%DateTime{} = timestamp) do
    if timestamp.time_zone == "Etc/UTC" do
      timestamp
    else
      DateTime.shift_zone!(timestamp, "Etc/UTC")
    end
  end

  defp ensure_utc_or_nil(nil), do: nil
end
