defmodule AlertsUI.AlertBuilder do
  @moduledoc """
    Builds an alert from form data
  """

  alias AlertsUI.Activities
  alias AlertsUI.Models.{Cause, Effect, InformedEntity, RoutePattern}
  alias AlertsUI.Routes
  alias AlertsUIWeb.FormComponents.Helpers.ServiceEffectCombinations
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatterns
  alias MBTAV3API.RoutePatterns.RoutePattern, as: APIRoutePattern
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @end_of_service ~T[02:30:00]
  @type alert_data_t :: %{
          route_type: Route.type_int() | nil,
          direction: String.t(),
          route_ids: [Route.id_t()],
          stop_ids: [Stop.id_t()],
          child_stops_with_context: [stop_with_context_t()] | [],
          trip_ids: [String.t()],
          service_types: [Route.type_int()],
          active_period_start: DateTime.t() | nil,
          active_period_end_specifier: atom() | nil,
          active_period_end: DateTime.t() | nil,
          cause_detail: String.t(),
          url: String.t() | nil,
          image_url: String.t() | nil,
          image_alternative_text: String.t() | nil
        }
  @type direction_t :: 0 | 1
  @type stop_with_context_t :: {Stop.t(), Route.id_t(), direction_t(), RoutePattern.stop_type()}
  @type active_period_data_t :: %{
          active_period: [any()],
          active_period_start: DateTime.t(),
          active_period_end: DateTime.t() | nil,
          duration_certainty: atom()
        }

  @spec build_alert(map(), ServiceEffectCombinations.service_effect_combination()) ::
          map()
  def build_alert(alert_data, combination, current_timestamp \\ DateTime.utc_now()) do
    effect_name = Map.get(alert_data, :effect_name)
    effect_map = Effect.effect_map_by_name(effect_name)
    stop_ids = Map.get(alert_data, :stop_ids)
    direction_id = Map.get(alert_data, :direction)
    service_types = Map.get(alert_data, :service_types, [])

    route_type = Map.get(alert_data, :route_type)
    cause_detail = Map.get(alert_data, :cause_detail, "")
    cause = Cause.get_by_mode_and_detail(route_type, cause_detail)

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
      build_active_period(%{
        active_period_start: Map.get(alert_data, :active_period_start),
        active_period_end: Map.get(alert_data, :active_period_end),
        active_period_end_specifier: Map.get(alert_data, :active_period_end_specifier)
      })

    %{
      last_modified_timestamp: current_timestamp,
      header_text: Map.get(alert_data, :header_text),
      description_text: Map.get(alert_data, :description_text),
      url: Map.get(alert_data, :url),
      image_url: Map.get(alert_data, :image_url),
      image_alternative_text: Map.get(alert_data, :image_alternative_text),
      cause: cause,
      cause_detail: cause_detail,
      effect: Map.get(effect_map, :effect),
      effect_detail: Map.get(effect_map, :effect_detail),
      draft: Map.get(alert_data, :draft, false),
      informed_entity: build_informed_entities(combination, alert_data, effect_name)
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

  @spec build_active_period(%{
          active_period_start: NaiveDateTime.t() | nil,
          active_period_end: NaiveDateTime.t() | nil,
          active_period_end_specifier: atom() | nil
        }) :: active_period_data_t() | %{}
  defp build_active_period(%{active_period_start: nil}), do: %{}

  defp build_active_period(%{
         active_period_start: naive_start,
         active_period_end_specifier: :later_today
       }) do
    eastern_start = naive_start |> DateTime.from_naive!("America/New_York")
    utc_start = eastern_start |> Timex.Timezone.convert("Etc/UTC")
    # Sets the end date of the active period to the next instance of 2:30 AM.
    # Checks if start time is after 2:30am (Eastern). If true, end date is the next day. If false, end date is same day.
    end_date =
      if Time.after?(DateTime.to_time(eastern_start), @end_of_service) do
        Date.add(NaiveDateTime.to_date(naive_start), 1)
      else
        NaiveDateTime.to_date(naive_start)
      end

    utc_end =
      DateTime.new!(end_date, @end_of_service, "America/New_York")
      |> Timex.Timezone.convert("Etc/UTC")

    %{
      active_period_start: utc_start,
      active_period_end: utc_end,
      active_period: [%{start: utc_start, end: utc_end}],
      duration_certainty: :ESTIMATED
    }
  end

  defp build_active_period(%{
         active_period_start: naive_start,
         active_period_end_specifier: :further_notice
       }) do
    utc_start =
      naive_start |> eastern_naive_to_utc

    %{
      active_period_start: utc_start,
      active_period_end: nil,
      active_period: [%{start: utc_start, end: nil}],
      duration_certainty: :UNKNOWN
    }
  end

  defp build_active_period(%{
         active_period_start: naive_start,
         active_period_end_specifier: :end_of_service_today
       }) do
    eastern_start = naive_start |> DateTime.from_naive!("America/New_York")
    utc_start = eastern_start |> Timex.Timezone.convert("Etc/UTC")
    # Sets the end date of the active period to the next instance of 2:30 AM.
    # Checks if start time is after 2:30am (Eastern). If true, end date is the next day. If false, end date is same day.
    end_date =
      if Time.after?(DateTime.to_time(eastern_start), @end_of_service) do
        Date.add(NaiveDateTime.to_date(naive_start), 1)
      else
        NaiveDateTime.to_date(naive_start)
      end

    utc_end =
      DateTime.new!(end_date, @end_of_service, "America/New_York")
      |> Timex.Timezone.convert("Etc/UTC")

    %{
      active_period_start: utc_start,
      active_period_end: utc_end,
      active_period: [%{start: utc_start, end: utc_end}],
      duration_certainty: :KNOWN
    }
  end

  defp build_active_period(%{
         active_period_start: naive_start,
         active_period_end_specifier: :pick_a_date_and_time,
         active_period_end: naive_end
       }) do
    utc_start =
      naive_start |> eastern_naive_to_utc

    utc_end =
      naive_end |> eastern_naive_to_utc

    %{
      active_period_start: utc_start,
      active_period_end: utc_end,
      active_period: [%{start: utc_start, end: utc_end}],
      duration_certainty: :KNOWN
    }
  end

  defp eastern_naive_to_utc(naive_time),
    do:
      naive_time |> DateTime.from_naive!("America/New_York") |> Timex.Timezone.convert("Etc/UTC")

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

  @spec get_trips([String.t()]) :: [Trip.t()]
  defp get_trips(trip_ids) do
    trip_ids
    |> Enum.filter(&(&1 != "default"))
    |> Enum.map(&get_trip/1)
    |> Enum.reject(&is_nil/1)
  end

  @spec get_trip(String.t()) :: Trip.t() | nil
  defp get_trip(trip_id), do: SchedulesRepo.trip(trip_id)

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
end
