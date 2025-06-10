defmodule AlertsUIWeb.FormComponents.Helpers.AutoText.BuildDescriptionText do
  @moduledoc """
    Constructs auto-text for description from affected service.
  """
  alias AlertsUIWeb.FormComponents.Helpers.AutoText.BuildAutoText
  alias AlertsUIWeb.FormComponents.Helpers.SelectFormatter

  @spec affected_routes(BuildAutoText.t()) :: String.t()
  def affected_routes(%{routes: routes, effect: effect, route_type: route_type}) do
    "#{affected_route_term(effect)} #{route_term(route_type)}:\n#{join(routes)}"
  end

  @spec affected_stops(BuildAutoText.t()) :: String.t()
  # TODO inbound/outbound
  def affected_stops(%{stops: stops, effect: effect, route_type: 3}) do
    "#{affected_stop_term(effect)} #{stop_term(3)}:\n#{join(stops)}"
  end

  def affected_stops(%{stops: stops, effect: effect, route_type: route_type}) do
    "#{affected_stop_term(effect)} #{stop_term(route_type)}:\n#{join(stops)}"
  end

  def affected_trips(%{routes: [_route], schedules: schedules, effect: effect}) do
    "#{affected_trip_term(effect)} trips:\n#{join(schedules)}"
  end

  def affected_trips(%{routes: _routes, schedules: schedules, effect: effect}) do
    Enum.reduce(schedules, %{}, fn schedule, acc ->
      route_name = SelectFormatter.name_for_option(schedule.route)
      trip_name = SelectFormatter.name_for_option(schedule)
      direction_name = trip_direction_name(schedule.trip, schedule.route)

      if Map.has_key?(acc, {route_name, direction_name}) do
        Map.put(
          acc,
          {route_name, direction_name},
          acc[{route_name, direction_name}] <> "#{trip_name}\n"
        )
      else
        Map.put(acc, {route_name, direction_name}, trip_name)
      end
    end)
    |> Enum.map_join("\n\n", fn {{route_name, direction_name}, trips} ->
      "#{affected_trip_term(effect)} #{direction_name} trips on #{route_name}:\n#{String.trim(trips)}"
    end)
    |> String.trim()
  end

  defp route_term(3), do: "routes"
  defp route_term(4), do: "ferries"
  defp route_term(_route_type), do: "lines"

  defp stop_term(3), do: "stops"
  defp stop_term(4), do: "docks"
  defp stop_term(_route_type), do: "stations"

  defp affected_stop_term(effect) when effect in ["Detour", "Multi-Route Detour", "Snow Route"] do
    "Skipped"
  end

  defp affected_stop_term(effect)
       when effect in ["Stop Closure", "Station Closure", "Dock Closure"] do
    "Closed"
  end

  defp affected_stop_term("Stop Move"), do: "Moved"
  defp affected_stop_term(_effect), do: "Affected"

  defp affected_trip_term("Delay"), do: "Delayed"
  defp affected_trip_term("Cancellation"), do: "Cancelled"
  defp affected_trip_term("Suspension"), do: "Suspended"
  defp affected_trip_term(_effect), do: "Affected"

  defp affected_route_term("Suspension"), do: "Suspended"
  defp affected_route_term(_effect), do: "Affected"

  defp join(list) do
    Enum.map_join(list, "\n", &SelectFormatter.name_for_option/1)
  end

  defp trip_direction_name(trip, route) do
    if Map.get(route, :direction_names) do
      String.downcase(route.direction_names[trip.direction_id])
    else
      Map.get(%{0 => "outbound", 1 => "inbound"}, trip.direction_id)
    end
  end
end
