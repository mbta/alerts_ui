defmodule AlertsUI.AlertBuilder do
  @moduledoc """
    Builds an alert from form data
  """
  alias AlertsUI.Models.Effect

  @type route_information() :: %{route_id: String.t(), route_type: integer()}
  @type trip_information() :: %{route_id: String.t(), trip_id: String.t(), direction: integer()}

  @spec build_alert(map(), atom()) :: map()
  def build_alert(alert_data, combination) do
    effect_map = Effect.effect_map_by_name(Map.get(alert_data, :effect_name, nil))

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
           route_ids: [route_id],
           direction: direction,
           route_type: route_type
         }
       ) do
    stop_ids
    |> Enum.map(
      &(%{
          activities: ["BOARD", "EXIT", "RIDE"],
          route_id: route_id,
          route_type: route_type,
          stop_id: &1
        }
        |> maybe_add_direction(direction))
    )
  end

  defp build_informed_entities(
         :RDT,
         %{trip_ids: []} = alert_data
       ) do
    build_informed_entities(:R, alert_data)
  end

  defp build_informed_entities(
         :RDT,
         %{trip_ids: [_ | _] = trip_ids, route_type: route_type}
       ) do
    trip_ids
    |> Enum.map(fn trip_string ->
      trip_information = parse_trip_information(trip_string)

      %{
        activities: ["BOARD", "EXIT", "RIDE"],
        route_id: trip_information.route_id,
        route_type: route_type,
        direction_id: trip_information.direction,
        trip:
          build_trip(
            trip_information.trip_id,
            trip_information.direction,
            trip_information.route_id
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
         %{stop_ids: [_ | _] = stop_ids, trip_ids: [_ | _] = trip_ids} =
           alert_data
       ) do
    stop_ids
    |> Enum.map(fn stop_id ->
      trip_ids
      |> Enum.map(fn trip_string ->
        trip_information = parse_trip_information(trip_string)

        %{
          activities: ["BOARD", "EXIT", "RIDE"],
          route_id: trip_information.route_id,
          route_type: alert_data.route_type,
          direction_id: trip_information.direction,
          trip:
            build_trip(
              trip_information.trip_id,
              trip_information.direction,
              trip_information.route_id
            ),
          stop_id: stop_id
        }
      end)
    end)
    |> List.flatten()
  end

  defp build_informed_entities(:SR, %{stop_ids: stop_ids, route_ids: route_ids}) do
    route_ids
    |> Enum.map(fn route_string ->
      route_information = parse_route_information(route_string)

      stop_ids
      |> Enum.map(fn stop_id ->
        %{
          activities: ["BOARD", "EXIT", "RIDE"],
          route_id: route_information.route_id,
          route_type: route_information.route_type,
          stop_id: stop_id
        }
      end)
    end)
    |> List.flatten()
  end

  defp build_trip(trip_id, direction, route_id) do
    # MISSING- need start_time, start_date, schedule_relationship
    %{
      trip_id: trip_id,
      direction_id: direction,
      route_id: route_id
    }
  end

  @spec parse_trip_information(String.t()) :: trip_information()
  defp parse_trip_information(string) do
    [route_id, trip_id, direction] = String.split(string, ",")
    %{route_id: route_id, trip_id: trip_id, direction: direction |> String.to_integer()}
  end

  @spec parse_route_information(String.t()) :: route_information()
  defp parse_route_information(string) do
    [route_id, route_type] = String.split(string, ",")
    %{route_id: route_id, route_type: route_type |> String.to_integer()}
  end

  defp maybe_add_direction(informed_entity, direction) do
    informed_entity
    |> case do
      informed_entity when direction !== "default" ->
        Map.put(informed_entity, :direction_id, direction |> String.to_integer())

      informed_entity ->
        informed_entity
    end
  end
end
