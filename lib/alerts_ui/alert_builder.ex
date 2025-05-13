defmodule AlertsUI.AlertBuilder do
  @moduledoc """
    Builds an alert from form data

    All incoming times are naive datetimes created in the eastern timezone
    and need to be converted to UTC datetimes
  """

  alias AlertsUI.{ActivePeriodBuilder, Activities}
  alias AlertsUI.Models.{Cause, Effect, RoutePattern, SeverityLevel}
  alias AlertsUI.Routes
  alias AlertsUIWeb.FormComponents.Helpers.ServiceEffectCombinations
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Lines.Repo, as: LinesRepo
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatterns
  alias MBTAV3API.RoutePatterns.RoutePattern, as: APIRoutePattern
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @green_line_branch_ids Routes.green_line_branch_ids()

  @type alert_data_t :: %{
          route_type: Route.type_int() | nil,
          facility_id: String.t(),
          direction: String.t(),
          route_ids: [Route.id_t()],
          stop_ids: [Stop.id_t()],
          child_stops_with_context: [stop_with_context_t()] | [],
          trip_ids: [String.t()],
          service_types: [Route.type_int()],
          alert_timing: atom(),
          active_period_end_specifier: atom() | nil,
          active_period_start_specifier: atom() | nil,
          active_period_start: NaiveDateTime.t() | nil,
          active_period_end: NaiveDateTime.t() | nil,
          active_period_start_date: Date.t() | nil,
          active_period_end_date: Date.t() | nil,
          active_period_start_time: Time.t() | nil,
          active_period_end_time: Time.t() | nil,
          recurrence_days: atom() | nil,
          cause_detail: String.t(),
          url: String.t() | nil,
          image_url: String.t() | nil,
          image_alternative_text: String.t() | nil,
          header_text: String.t(),
          description_text: String.t(),
          banner_text: String.t() | nil,
          last_push_notification_timestamp: NaiveDateTime.t() | nil,
          notification_period_start: NaiveDateTime.t() | nil,
          notification_specifier: atom() | nil,
          severity: integer(),
          reminder_times: [NaiveDateTime.t()] | nil,
          recurrence_days: [atom()] | nil
        }
  @type direction_t :: 0 | 1
  @type stop_with_context_t :: {Stop.t(), Route.id_t(), direction_t(), RoutePattern.stop_type()}

  @spec build_alert(
          alert_data_t(),
          ServiceEffectCombinations.service_effect_combination(),
          DateTime.t()
        ) ::
          map()
  def build_alert(alert_data, combination, current_time \\ DateTime.utc_now()) do
    effect_name = Map.get(alert_data, :effect_name)
    effect_map = Effect.effect_map_by_name(effect_name)
    stop_ids = Map.get(alert_data, :stop_ids)
    direction_id = Map.get(alert_data, :direction)
    service_types = Map.get(alert_data, :service_types, []) |> expand_subway_service_types()

    route_type = Map.get(alert_data, :route_type)
    cause_detail = Map.get(alert_data, :cause_detail, "")
    cause = Cause.get_by_mode_and_detail(route_type, cause_detail)

    severity = Map.get(alert_data, :severity)

    reminder_times =
      Map.get(alert_data, :reminder_times, [])
      |> Enum.map(&%{reminder_time: ActivePeriodBuilder.naive_eastern_datetime_to_utc(&1)})

    original_route_selections = Map.get(alert_data, :route_ids, [])

    routes =
      original_route_selections
      |> Enum.filter(&(&1 !== "default"))
      |> Enum.uniq()
      |> Routes.expanding_green_line()
      |> Enum.map(&(RoutesRepo.get(&1, include: "line") || %{}))
      |> Enum.reject(&(&1 == %{}))
      |> add_combo_routes()

    route_ids = Enum.map(routes, & &1.id)
    child_stops_with_context = child_stops_with_context(routes, direction_id, stop_ids)

    alert_data =
      alert_data
      |> Map.put(:route_ids, route_ids)
      |> Map.put(
        :child_stops_with_context,
        child_stops_with_context
      )
      |> Map.put(:service_types, service_types)

    active_period_map =
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

    notification_period_start =
      if Map.get(alert_data, :notification_specifier) === :now do
        current_time
      else
        Map.get(alert_data, :notification_period_start)
        |> ActivePeriodBuilder.naive_eastern_datetime_to_utc()
      end

    %{
      header_text: Map.get(alert_data, :header_text),
      description_text: Map.get(alert_data, :description_text),
      banner_text: Map.get(alert_data, :banner_text),
      url: Map.get(alert_data, :url),
      image_url: Map.get(alert_data, :image_url),
      image_alternative_text: Map.get(alert_data, :image_alternative_text),
      cause: cause,
      cause_detail: cause_detail,
      effect: Map.get(effect_map, :effect),
      effect_detail: Map.get(effect_map, :effect_detail),
      effect_name: effect_name,
      last_push_notification_timestamp:
        Map.get(alert_data, :last_push_notification_timestamp)
        |> ActivePeriodBuilder.naive_eastern_datetime_to_utc(),
      informed_entity:
        build_informed_entities(combination, alert_data, effect_name)
        |> Enum.uniq(),
      original_route_selections: original_route_selections,
      notification_period_start: notification_period_start,
      severity: severity,
      severity_level: SeverityLevel.severity_level_by_severity(severity),
      reminder_times: reminder_times,
      current_time: current_time,
      recurrence_days: Map.get(alert_data, :recurrence_days)
    }
    |> Map.merge(active_period_map)
  end

  @spec add_combo_routes([Route.id_t()]) :: [Route.t()]

  defp add_combo_routes(selected_routes) do
    # For every route, get its line (if present) and make an API call to to
    # the line route to get any associated combo routes it has
    # We want to include combo routes with the informed entity
    # unless they're shuttle routes.
    selected_routes
    |> Enum.flat_map(fn original_route ->
      if Map.get(original_route, :line_id) in ["", nil] do
        []
      else
        original_route.line_id
       |> LinesRepo.get([])
       |> filtered_combo_routes()
      end ++ [original_route]
    end)
    |> Enum.uniq()
  end

  # excepting green line to keep it from pulling in all green line routes
  # when any is selected
  defp filtered_combo_routes(%{id: "line-Green"} = _line), do: []

  defp filtered_combo_routes(line) do
    # filter out shuttle routes unless they were part of the original selection
    Enum.filter(line.routes, &(&1.description !== :rail_replacement_bus))
  end

  @spec child_stops_with_context([Route.id_t()], String.t(), [Stop.id_t()]) ::
          [
            stop_with_context_t()
          ]

  defp child_stops_with_context(routes, direction, parent_stop_ids) do
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

      child_stops_context ++ neighbor_stops
    end)
  end

  defp get_neighbor_stops(child_stops_with_context, route_patterns, parent_stop_ids, route)
       when route.type in [0, 1, 2] do
    # in the case of Subway & CR, detect platforms at the nodes of branches that
    # need to be included in informed entities
    all_route_pattern_stops =
      route_patterns
      |> Enum.map(& &1.stops())

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
    # busses do not have canonical route patterns
    opts =
      [include: "representative_trip.stops"]
      |> route_pattern_direction_opts(direction)

    RoutePatterns.by_route_id(route_id, opts)
  end

  defp get_route_patterns(route_id, direction, _route_type) do
    opts =
      [include: "representative_trip.stops"]
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
  defp build_informed_entities(nil, %{service_types: []}, effect) do
    [
      %{
        activities: Activities.for_effect(effect),
        agency_id: "1"
      }
    ]
  end

  # Systemwide, specified service types
  defp build_informed_entities(nil, %{service_types: service_types}, effect) do
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

  defp build_informed_entities(:ACCESS, %{facility_id: facility_id}, effect) do
    [facility_id]
    |> Enum.map(&FacilitiesRepo.get/1)
    |> Enum.flat_map(&build_facility_maps(&1, effect))
  end

  defp build_informed_entities(
         :R,
         %{
           route_ids: route_ids,
           route_type: route_type,
           direction: direction
         },
         effect
       ) do
    route_ids
    |> Routes.expanding_green_line()
    |> Enum.map(
      &(%{
          activities: Activities.for_effect(effect),
          route_id: &1,
          route_type: route_type,
          agency_id: Routes.agency_id(&1)
        }
        |> maybe_add_direction(direction))
    )
  end

  # No stops, treat like :R
  defp build_informed_entities(:RDS, %{stop_ids: []} = alert_data, effect),
    do: build_informed_entities(:R, alert_data, effect)

  # Did not get stops from route patterns (fallback)
  defp build_informed_entities(
         :RDS,
         %{
           child_stops_with_context: [],
           route_ids: route_ids,
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
        route_type: route_type,
        agency_id: Routes.agency_id(route_id),
        stop_id: stop_id
      }
      |> maybe_add_direction(direction)
    end)
  end

  # Child stops from route pattern
  defp build_informed_entities(
         :RDS,
         %{
           child_stops_with_context: [_ | _] = child_stops_with_context,
           route_type: route_type
         },
         effect
       ) do
    child_stops_with_context
    |> Enum.map(fn {%Stop{id: stop_id}, route_id, direction_id, stop_type} ->
      %{
        activities: Activities.for_effect(effect, stop_type),
        direction_id: direction_id,
        route_id: route_id,
        route_type: route_type,
        agency_id: Routes.agency_id(route_id),
        stop_id: stop_id
      }
    end)
    |> Enum.uniq()
  end

  defp build_informed_entities(
         :RDT,
         %{trip_ids: []} = alert_data,
         effect
       ) do
    build_informed_entities(:R, alert_data, effect)
  end

  defp build_informed_entities(
         :RDT,
         %{
           trip_ids: [_ | _] = trip_ids,
           route_type: route_type,
           trip_information_by_id: trip_information_by_id
         },
         effect
       ) do
    trip_ids
    |> Enum.map(fn trip_id ->
      %{direction_id: direction_id, route_id: route_id} = trip_information_by_id[trip_id]

      %{
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
    end)
  end

  defp build_informed_entities(:RDTS, %{stop_ids: [], trip_ids: []} = alert_data, effect),
    do: build_informed_entities(:R, alert_data, effect)

  defp build_informed_entities(:RDTS, %{stop_ids: []} = alert_data, effect),
    do: build_informed_entities(:RDT, alert_data, effect)

  defp build_informed_entities(:RDTS, %{trip_ids: []} = alert_data, effect),
    do: build_informed_entities(:RDS, alert_data, effect)

  # Did not get stops from route patterns (fallback)
  defp build_informed_entities(
         :RDTS,
         %{
           stop_ids: [_ | _] = stop_ids,
           child_stops_with_context: [],
           trip_ids: [_ | _] = trip_ids,
           route_type: route_type,
           route_ids: route_ids
         },
         effect
       ) do
    trips = get_trips(trip_ids)

    stop_ids
    |> stop_route_pairs(route_ids)
    |> Enum.flat_map(fn {stop_id, route_id} ->
      trips
      |> Enum.map(fn %Trip{id: trip_id, direction_id: trip_direction_id} ->
        %{
          activities: Activities.for_effect(effect),
          route_id: route_id,
          route_type: route_type,
          agency_id: Routes.agency_id(route_id),
          trip:
            build_trip(
              trip_id,
              trip_direction_id,
              route_id
            ),
          stop_id: stop_id
        }
      end)
    end)
    |> Enum.uniq()
  end

  # Child stops from route patterns
  defp build_informed_entities(
         :RDTS,
         %{
           child_stops_with_context: [_ | _] = child_stops_with_context,
           trip_ids: [_ | _] = trip_ids,
           route_type: route_type
         },
         effect
       ) do
    trips = get_trips(trip_ids)
    trip_directions = trip_directions(trips)

    child_stops_with_context
    |> Enum.filter(fn {_, _, stop_direction_id, _} ->
      Enum.member?(trip_directions, stop_direction_id)
    end)
    |> Enum.flat_map(fn {%Stop{id: stop_id}, route_id, _direction_id, _stop_type} ->
      trips
      |> Enum.map(fn %Trip{id: trip_id, direction_id: trip_direction_id} ->
        %{
          activities: Activities.for_effect(effect),
          route_id: route_id,
          route_type: route_type,
          agency_id: Routes.agency_id(route_id),
          trip:
            build_trip(
              trip_id,
              trip_direction_id,
              route_id
            ),
          stop_id: stop_id
        }
      end)
    end)
    |> Enum.uniq()
  end

  defp build_informed_entities(
         :SR,
         %{
           child_stops_with_context: [_ | _] = child_stops_with_context,
           route_types_by_id: route_types_by_id
         },
         effect
       ) do
    child_stops_with_context
    |> Enum.filter(fn {%Stop{parent_id: parent_id}, route_id, _, _} ->
      on_route?({parent_id, route_id}, "default")
    end)
    |> Enum.map(fn {%Stop{id: stop_id}, route_id, _direction_id, _stop_type} ->
      %{
        activities: Activities.for_effect(effect),
        route_id: route_id,
        route_type: route_type(route_types_by_id, route_id),
        agency_id: Routes.agency_id(route_id),
        stop_id: stop_id
      }
    end)
    |> Enum.uniq()
  end

  defp build_informed_entities(
         :SR,
         %{
           stop_ids: stop_ids,
           route_ids: route_ids,
           route_types_by_id: route_types_by_id,
           child_stops_with_context: []
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
        route_type: route_type(route_types_by_id, route_id),
        agency_id: Routes.agency_id(route_id),
        stop_id: stop_id
      }
    end)
  end

  defp build_informed_entities(_mode, _data, _effect), do: []

  @spec get_trips([String.t()]) :: [Trip.t()]
  defp get_trips(trip_ids) do
    trip_ids
    |> Enum.filter(&(&1 != "default"))
    |> Enum.map(&get_trip/1)
    |> Enum.reject(&is_nil/1)
  end

  @spec get_trip(String.t()) :: Trip.t() | nil
  defp get_trip(trip_id) do
    SchedulesRepo.trip(trip_id)
  end

  @spec trip_directions([Trip.t()]) :: [Trip.direction_id_t()]
  defp trip_directions(trips) do
    trips
    |> Enum.map(fn %Trip{direction_id: direction_id} -> direction_id end)
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

    routes_from_children =
      Enum.flat_map(child_stop_ids, &RoutesRepo.by_stop/1)

    # use route_ids from parent stop if none are associated with children
    route_ids =
      if Enum.empty?(routes_from_children) do
        RoutesRepo.by_stop(stop.id)
      else
        routes_from_children
      end
      |> Enum.map(& &1.id)
      |> Enum.uniq()

    child_stop_ids
    |> Enum.flat_map(fn stop_id ->
      Enum.map(route_ids, fn route_id ->
        %{
          activities: Activities.for_effect(effect),
          facility_id: facility_id,
          route_id: route_id,
          stop_id: stop_id
        }
      end)
    end)
  end

  defp build_facility_maps(%Facility{stop: nil, id: facility_id}, effect) do
    [
      %{
        activities: Activities.for_effect(effect),
        facility_id: facility_id
      }
    ]
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

  @spec route_type(%{String.t() => Route.type_int()}, Route.id_t()) :: Route.type_int()

  defp route_type(route_types_by_id, route_id) do
    if route_id in @green_line_branch_ids do
      route_types_by_id[route_id] || route_types_by_id["Green"]
    else
      route_types_by_id[route_id]
    end
  end

  @spec excluded_stops_from_facility_properties([map()]) :: [String.t()]
  defp excluded_stops_from_facility_properties(properties) do
    Enum.reduce(properties, [], fn %{name: name, value: value}, acc ->
      if name == "excludes-stop", do: [maybe_integer_to_string(value) | acc], else: acc
    end)
  end

  @spec maybe_integer_to_string(integer() | String.t()) :: String.t()
  defp maybe_integer_to_string(value) when is_integer(value), do: Integer.to_string(value)
  defp maybe_integer_to_string(value), do: value
end
