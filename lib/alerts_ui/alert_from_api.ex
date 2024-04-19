defmodule AlertsUI.AlertFromApi do
  @moduledoc """
    Builds an alert from API parameters
  """
  alias AlertsUI.Activities
  alias AlertsUI.Models.Effect

  def fill_in_alert(alert_data) do
    alert_data
    |> add_effect_from_detail
    |> add_activities
    |> fill_in_informed_entities
  end

  defp add_effect_from_detail(%{effect: _effect} = alert_data), do: alert_data

  defp add_effect_from_detail(%{effect_detail: effect_detail} = alert_data) do
    effect_tuple = Effect.effect_map_by_detail(effect_detail)
    Map.put_new(alert_data, :effect, effect_tuple.effect)
  end

  defp add_activities(alert_data) do
    effect_tuple = Effect.effect_map_by_detail(Map.get(alert_data, :effect_detail))
    new_activities = Activities.for_effect(effect_tuple.effect_name)

    new_informed_entity =
      alert_data.informed_entity
      |> Enum.map(fn informed_entity ->
        new_activties =
          case Map.get(informed_entity, :activities) do
            nil -> new_activities
            [_ | _] = activities -> Enum.map(activities, &String.to_atom(&1))
          end

        Map.put(informed_entity, :activities, new_activties)
      end)

    Map.put(alert_data, :informed_entity, new_informed_entity)
  end

  defp fill_in_informed_entities(alert_data) do
    new_informed_entity = Enum.map(alert_data.informed_entity, &fill_in_informed_entity(&1))
    Map.put(alert_data, :informed_entity, new_informed_entity)
  end

  defp fill_in_informed_entity(%{trip: trip} = informed_entity) do
    route_id = Map.get(trip, :route_id)
    direction_id = Map.get(trip, :direction_id)

    informed_entity
    |> Map.put_new(:route_id, route_id)
    |> Map.put_new(:direction_id, direction_id)
  end

  defp fill_in_informed_entity(informed_entity), do: informed_entity
end
