defmodule AlertsUI.AlertBuilder do
  @moduledoc """
    Builds an alert from form data
  """

  alias AlertsUI.Activities
  alias AlertsUI.Models.{Activity, Effect, InformedEntity, RoutePattern}
  alias AlertsUI.Routes
  alias AlertsUIWeb.FormComponents.Helpers.ServiceEffectCombinations
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatterns
  alias MBTAV3API.RoutePatterns.RoutePattern, as: APIRoutePattern
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @type alert_data_t :: %{
          route_type: Route.type_int(),
          direction: String.t(),
          route_ids: [Route.id_t()],
          stop_ids: [Stop.id_t()],
          child_stops_with_context: [stop_with_context_t()] | [],
          trip_ids: [String.t()]
        }
  @type direction_t :: 0 | 1
  @type stop_with_context_t :: {Stop.t(), Route.id_t(), direction_t(), RoutePattern.stop_type()}

  @spec build_alert(map(), ServiceEffectCombinations.service_effect_combination()) ::
          map()
  def build_alert(alert_data, combination) do
    effect_name = Map.get(alert_data, :effect_name)
    effect_map = Effect.effect_map_by_name(effect_name)
    stop_ids = Map.get(alert_data, :stop_ids)
    direction_id = Map.get(alert_data, :direction)

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

    %{
      header_text: Map.get(alert_data, :header_text),
      description_text: Map.get(alert_data, :description_text),
      effect: Map.get(effect_map, :effect),
      effect_detail: Map.get(effect_map, :effect_detail),
      draft: Map.get(alert_data, :draft, false),
      informed_entity: build_informed_entities(combination, alert_data, effect_name)
    }
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
      |> Enum.filter(&(&1.parent_id in stop_ids))
      |> Enum.map(& &1.id)
    end)
    |> Enum.concat(stop_ids)
    |> Enum.filter(&(&1 !== "default"))
  end

  defp get_stops(route_id, "default"), do: RoutePatterns.included_stops_by_route_id(route_id, [])

  defp get_stops(route_id, direction),
    do: RoutePatterns.included_stops_by_route_id(route_id, direction_id: direction)

  @spec child_stops_with_context([Route.id_t()], String.t(), [Stop.id_t()]) :: [
          stop_with_context_t()
        ]
  defp child_stops_with_context(route_ids, direction, parent_stop_ids) do
    route_ids
    |> Routes.expanding_green_line()
    |> Enum.flat_map(fn route_id ->
      route_id
      |> get_route_patterns(direction)
      |> Enum.flat_map(fn route_pattern ->
        route_pattern_stops_with_context_for_parents(route_pattern, route_id, parent_stop_ids)
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

  @spec route_pattern_stops_with_context_for_parents(APIRoutePattern.t(), Route.id_t(), [
          Stop.id_t()
        ]) :: [
          stop_with_context_t()
        ]
  defp route_pattern_stops_with_context_for_parents(route_pattern, route_id, parent_stop_ids) do
    route_pattern
    |> RoutePattern.stops()
    |> Enum.filter(&(&1.parent_id in parent_stop_ids))
    |> Enum.map(fn child_stop ->
      {
        child_stop,
        route_id,
        route_pattern.direction_id,
        RoutePattern.stop_type(route_pattern, child_stop)
      }
    end)
  end

  @spec build_informed_entities(
          ServiceEffectCombinations.service_effect_combination() | nil,
          alert_data_t(),
          Effect.effect_name()
        ) ::
          [map()]
  defp build_informed_entities(nil, _, _), do: []

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

  defp build_informed_entities(:RDS, %{child_stops_with_context: []} = alert_data, effect),
    do: build_informed_entities(:R, alert_data, effect)

  defp build_informed_entities(
         :RDS,
         %{
           child_stops_with_context: [_ | _] = child_stops_with_context,
           direction: direction,
           route_type: route_type
         },
         effect
       ) do
    child_stops_with_context
    |> child_stops_with_context_by_parent_id()
    |> Enum.reduce([], fn {parent_stop_id, child_stops_with_context}, acc ->
      child_stop_informed_entities =
        Enum.map(child_stops_with_context, fn {%Stop{id: stop_id}, route_id, direction_id,
                                               stop_type} ->
          %{
            activities: Activities.for_effect(effect, stop_type),
            direction_id: direction_id,
            route_id: route_id,
            route_type: route_type,
            agency_id: Routes.agency_id(route_id),
            stop_id: stop_id
          }
        end)

      parent_stop_informed_entities =
        child_stop_informed_entities
        |> all_route_ids()
        |> Enum.map(fn route_id ->
          %{
            activities: combined_activities(child_stop_informed_entities),
            route_id: route_id,
            route_type: route_type,
            agency_id: Routes.agency_id(route_id),
            stop_id: parent_stop_id
          }
          |> maybe_add_direction(direction)
        end)

      acc ++ parent_stop_informed_entities ++ child_stop_informed_entities
    end)
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
           stop_ids: [_ | _] = stop_ids,
           trip_ids: [_ | _] = trip_ids,
           trip_information_by_id: trip_information_by_id
         } =
           alert_data,
         effect
       ) do
    stop_ids
    |> Enum.flat_map(fn stop_id ->
      trip_ids
      |> Enum.filter(&(&1 !== "default"))
      |> Enum.map(fn trip_id ->
        %{direction_id: direction_id, route_id: route_id} = trip_information_by_id[trip_id]

        %{
          activities: Activities.for_effect(effect),
          route_id: route_id,
          route_type: alert_data.route_type,
          agency_id: Routes.agency_id(route_id),
          trip:
            build_trip(
              trip_id,
              direction_id,
              route_id
            ),
          stop_id: stop_id
        }
      end)
    end)
  end

  defp build_informed_entities(
         :SR,
         %{
           stop_ids: stop_ids,
           route_ids: route_ids,
           route_types_by_id: route_types_by_id
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

  @spec child_stops_with_context_by_parent_id([stop_with_context_t()]) :: %{
          Stop.id_t() => [stop_with_context_t()]
        }
  defp child_stops_with_context_by_parent_id(child_stops_with_context) do
    Enum.group_by(child_stops_with_context, fn {%Stop{parent_id: parent_id}, _, _, _} ->
      parent_id
    end)
  end

  @spec combined_activities([map()]) :: [Activity.activity()]
  defp combined_activities(child_stop_informed_entities) do
    child_stop_informed_entities
    |> Enum.flat_map(& &1.activities)
    |> Enum.uniq()
  end

  @spec all_route_ids([map()]) :: [Route.id_t()]
  defp all_route_ids(child_stop_informed_entities) do
    child_stop_informed_entities
    |> Enum.map(& &1.route_id)
    |> Enum.uniq()
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
