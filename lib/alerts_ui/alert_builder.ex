defmodule AlertsUI.AlertBuilder do
  @moduledoc """
    Builds an alert from form data
  """
  alias AlertsUI.Models.{Effect, InformedEntity}
  alias AlertsUIWeb.FormComponents.Helpers.ServiceEffectCombinations

  @spec build_alert(map(), ServiceEffectCombinations.service_effect_combination()) :: map()
  def build_alert(alert_data, combination) do
    effect_map = Effect.effect_map_by_name(Map.get(alert_data, :effect_name, nil))

    route_ids = Map.get(alert_data, :route_ids, [])
    alert_data = Map.put(alert_data, :route_ids, add_combo_route_ids(route_ids))

    %{
      header_text: Map.get(alert_data, :header_text),
      description_text: Map.get(alert_data, :description_text),
      effect: Map.get(effect_map, :effect),
      effect_detail: Map.get(effect_map, :effect_detail),
      draft: Map.get(alert_data, :draft, false),
      informed_entity: build_informed_entities(combination, alert_data)
    }
  end

  defp build_informed_entities(nil, _), do: []

  defp build_informed_entities(:R, %{
         route_ids: route_ids,
         route_type: route_type,
         direction: direction
       }) do
    route_ids
    |> Enum.map(
      &(%{
          activities: ["BOARD", "EXIT", "RIDE"],
          route_id: &1,
          route_type: route_type
        }
        |> maybe_add_direction(direction))
    )
  end

  defp build_informed_entities(
         :RDS,
         %{stop_ids: [], route_ids: [_ | _]} = alert_data
       ),
       do: build_informed_entities(:R, alert_data)

  defp build_informed_entities(
         :RDS,
         %{
           stop_ids: [_ | _] = stop_ids,
           route_ids: route_ids,
           direction: direction,
           route_type: route_type
         }
       ) do
    stop_ids
    |> stop_route_pairs(route_ids)
    |> Enum.map(fn {stop_id, route_id} ->
      %{
        activities: ["BOARD", "EXIT", "RIDE"],
        route_id: route_id,
        route_type: route_type,
        stop_id: stop_id
      }
      |> maybe_add_direction(direction)
    end)
  end

  defp build_informed_entities(
         :RDT,
         %{trip_ids: []} = alert_data
       ) do
    build_informed_entities(:R, alert_data)
  end

  defp build_informed_entities(
         :RDT,
         %{
           trip_ids: [_ | _] = trip_ids,
           route_type: route_type,
           trip_information_by_id: trip_information_by_id
         }
       ) do
    trip_ids
    |> Enum.map(fn trip_id ->
      %{direction_id: direction_id, route_id: route_id} = trip_information_by_id[trip_id]

      %{
        activities: ["BOARD", "EXIT", "RIDE"],
        route_id: route_id,
        route_type: route_type,
        direction_id: direction_id,
        trip:
          build_trip(
            trip_id,
            direction_id,
            route_id
          )
      }
    end)
  end

  defp build_informed_entities(:RDTS, %{stop_ids: [], trip_ids: []} = alert_data),
    do: build_informed_entities(:R, alert_data)

  defp build_informed_entities(:RDTS, %{stop_ids: []} = alert_data),
    do: build_informed_entities(:RDT, alert_data)

  defp build_informed_entities(:RDTS, %{trip_ids: []} = alert_data),
    do: build_informed_entities(:RDS, alert_data)

  defp build_informed_entities(
         :RDTS,
         %{
           stop_ids: [_ | _] = stop_ids,
           trip_ids: [_ | _] = trip_ids,
           trip_information_by_id: trip_information_by_id
         } =
           alert_data
       ) do
    stop_ids
    |> Enum.flat_map(fn stop_id ->
      trip_ids
      |> Enum.map(fn trip_id ->
        %{direction_id: direction_id, route_id: route_id} = trip_information_by_id[trip_id]

        %{
          activities: ["BOARD", "EXIT", "RIDE"],
          route_id: route_id,
          route_type: alert_data.route_type,
          direction_id: direction_id,
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

  defp build_informed_entities(:SR, %{
         stop_ids: stop_ids,
         route_ids: route_ids,
         route_types_by_id: route_types_by_id
       }) do
    route_ids
    |> Enum.flat_map(fn route_id ->
      stop_ids
      |> Enum.map(fn stop_id ->
        %{
          activities: ["BOARD", "EXIT", "RIDE"],
          route_id: route_id,
          route_type: route_types_by_id[route_id],
          stop_id: stop_id
        }
      end)
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
  end

  defp stop_route_pairs(stop_ids, route_ids) do
    Enum.flat_map(stop_ids, fn stop_id ->
      Enum.map(route_ids, fn route_id -> {stop_id, route_id} end)
    end)
  end
end
