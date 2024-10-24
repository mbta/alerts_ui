defmodule AlertsUI.AlertBuilder do
  @moduledoc """
    Builds an alert from form data

    All incoming times are naive datetimes created in the eastern timezone
    and need to be converted to UTC datetimes
  """

  alias AlertsUI.{ActivePeriodBuilder, Activities}
  alias AlertsUI.Models.{Cause, Effect, InformedEntity, RoutePattern, SeverityLevel}
  alias AlertsUI.Routes
  alias AlertsUIWeb.FormComponents.Helpers.ServiceEffectCombinations
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatterns
  alias MBTAV3API.RoutePatterns.RoutePattern, as: APIRoutePattern
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

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
          draft: boolean | nil,
          last_push_notification_timestamp: NaiveDateTime.t() | nil,
          notification_period_start: NaiveDateTime.t() | nil,
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
    service_types = Map.get(alert_data, :service_types, [])

    route_type = Map.get(alert_data, :route_type)
    cause_detail = Map.get(alert_data, :cause_detail, "")
    cause = Cause.get_by_mode_and_detail(route_type, cause_detail)

    severity = Map.get(alert_data, :severity)

    reminder_times =
      Map.get(alert_data, :reminder_times, [])
      |> Enum.map(&%{reminder_time: ActivePeriodBuilder.naive_eastern_datetime_to_utc(&1)})

    route_ids =
      alert_data
      |> Map.get(:route_ids, [])
      |> add_combo_route_ids()

    alert_data =
      alert_data
      |> Map.put(:route_ids, route_ids)
      |> Map.put(:stop_ids, add_child_stops(stop_ids, route_ids, direction_id))
      |> Map.put(
        :child_stops_with_context,
        child_stops_with_context(route_ids, direction_id, stop_ids)
      )
      |> Map.put(:service_types, expand_subway_service_types(service_types))

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
      draft: Map.get(alert_data, :draft, false),
      last_push_notification_timestamp:
        Map.get(alert_data, :last_push_notification_timestamp)
        |> ActivePeriodBuilder.naive_eastern_datetime_to_utc(),
      informed_entity: build_informed_entities(combination, alert_data, effect_name),
      notification_period_start:
        Map.get(alert_data, :notification_period_start)
        |> ActivePeriodBuilder.naive_eastern_datetime_to_utc(),
      severity: severity,
      severity_level: SeverityLevel.severity_level_by_severity(severity),
      reminder_times: reminder_times,
      current_time: current_time,
      recurrence_days: Map.get(alert_data, :recurrence_days)
    }
    |> Map.merge(active_period_map)
  end

  @spec add_combo_route_ids([Route.id_t()]) :: [Route.id_t()]

  defp add_combo_route_ids(route_ids) do
    route_ids
    |> Enum.flat_map(fn route_id ->
      combo_map = InformedEntity.route_to_combo_route_mapping()

      case combo_id = Map.get(combo_map, route_id, nil) do
        nil -> []
        _ -> [combo_id]
      end
    end)
    |> Enum.dedup()
    |> Enum.concat(route_ids)
    |> Enum.filter(&(&1 !== "default"))
  end

  defp add_child_stops(nil, _route_ids, _direction), do: nil
  defp add_child_stops([], _route_ids, _direction), do: []

  defp add_child_stops(stop_ids, route_ids, direction) do
    Enum.flat_map(route_ids, fn route_id ->
      get_stops(route_id, direction)
      |> Enum.filter(&(Map.get(&1, :parent_id) in stop_ids))
      |> Enum.map(& &1.id)
    end)
    |> Enum.concat(stop_ids)
    |> Enum.filter(&(&1 !== "default"))
  end

  defp get_stops(route_id, "default"), do: RoutePatterns.included_stops_by_route_id(route_id, [])

  defp get_stops(route_id, direction),
    do: RoutePatterns.included_stops_by_route_id(route_id, direction_id: direction)

  @spec child_stops_with_context([Route.id_t()], String.t(), [Stop.id_t()]) ::
          [
            stop_with_context_t()
          ]

  defp child_stops_with_context(route_ids, direction, parent_stop_ids) do
    route_ids
    |> Routes.expanding_green_line()
    |> Enum.flat_map(fn route_id ->
      route_type = Map.get(RoutesRepo.get(route_id) || %{}, :type)

      route_id
      |> get_route_patterns(direction)
      |> Enum.flat_map(fn route_pattern ->
        route_pattern_stops_with_context_for_parents(
          route_pattern,
          route_id,
          parent_stop_ids,
          route_type
        )
      end)
    end)
  end

  @spec get_route_patterns(Route.id_t(), String.t()) :: [APIRoutePattern.t()]
  defp get_route_patterns(route_id, direction) do
    opts =
      [include: "representative_trip.stops"]
      |> route_pattern_direction_opts(direction)

    RoutePatterns.by_route_id(route_id, opts)
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
    |> RoutePattern.stops()
    |> Enum.filter(fn stop ->
      stop.parent_id in parent_stop_ids and stop.vehicle_type == route_type
    end)
    |> Enum.map(fn child_stop ->
      {
        child_stop,
        route_id,
        route_pattern.direction_id,
        RoutePattern.stop_type(route_pattern, parent_stop_ids, child_stop)
      }
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

  # Only parent stops
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
    |> Enum.filter(&on_route?(&1, "default"))
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

  # Child stops
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
    |> Enum.filter(&(&1 !== "default"))
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

  # Only parent stops
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
    |> Enum.filter(&on_route?(&1, "default"))
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

  # Child stops
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
    if route_id in Routes.green_line_branch_ids() do
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
