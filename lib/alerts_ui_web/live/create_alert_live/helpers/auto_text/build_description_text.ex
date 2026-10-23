defmodule AlertsUIWeb.CreateAlertLive.Helpers.AutoText.BuildDescriptionText do
  @moduledoc """
    Constructs auto-text for description from affected service.
  """
  alias AlertsUIWeb.CreateAlertLive.Helpers.AutoText.BuildAutoText
  alias AlertsUIWeb.CreateAlertLive.Helpers.SelectFormatter

  @spec affected_routes(BuildAutoText.t()) :: String.t()
  def affected_routes(%{routes: routes, effect_name: effect, route_type: route_type}) do
    routes =
      routes
      |> BuildAutoText.sort_routes()
      |> Enum.join("\n")

    "#{affected_route_term(effect)} #{route_term(route_type)}:\n#{routes}"
  end

  @spec affected_stops(BuildAutoText.t()) :: String.t()
  def affected_stops(%{stops: stops, effect_name: effect, route_type: 3}) do
    # Bus stops must be sorted by direction. Luckily the stop names
    # are already marked with the direction.
    outbound_stops = stops_by_direction(stops, effect, "outbound")
    inbound_stops = stops_by_direction(stops, effect, "inbound")
    "#{outbound_stops}\n\n#{inbound_stops}" |> String.trim()
  end

  def affected_stops(%{stops: stops, effect_name: effect, route_type: route_type}) do
    "#{affected_stop_term(effect)} #{stop_term(route_type)}:\n#{join(stops, route_type)}"
  end

  defp stops_by_direction(stops, effect, direction) do
    stops
    |> Enum.map(& &1.name)
    |> Enum.filter(&(String.contains?(&1, direction) || not (&1 =~ ~r/\(.*?\)/)))
    |> Enum.map(&String.replace(&1, " (#{direction})", ""))
    |> stops_text(direction, effect)
  end

  defp stops_text([], _, _), do: ""

  defp stops_text(stop_names, direction, effect) do
    stop_names = stop_names |> Enum.uniq() |> Enum.join("\n")
    "#{affected_stop_term(effect)} #{direction} stops:\n#{stop_names}"
  end

  @spec affected_trips(BuildAutoText.t()) :: String.t()
  def affected_trips(%{
        routes: [_route],
        schedules: schedules,
        effect_name: effect,
        route_type: route_type
      }) do
    schedules =
      Enum.map(schedules, fn schedule -> Map.put(schedule, :use_trip_id_in_name?, false) end)

    "#{affected_trip_term(effect)} trips:\n#{join(schedules, route_type)}"
  end

  def affected_trips(%{
        routes: routes,
        schedules: schedules,
        effect_name: effect,
        route_type: route_type
      }) do
    Enum.reduce(schedules, %{}, fn schedule, acc ->
      route = Enum.find(routes, fn route -> route.id == schedule.route_id end)
      route_name = SelectFormatter.name_for_option(route)

      trip_name =
        schedule
        |> Map.put(:use_trip_id_in_name?, false)
        |> SelectFormatter.name_for_option(route_type)

      direction_name = trip_direction_name(schedule.trip, route)

      if Map.has_key?(acc, {route_name, direction_name}) do
        Map.put(
          acc,
          {route_name, direction_name},
          acc[{route_name, direction_name}] <> "#{trip_name}\n"
        )
      else
        Map.put(acc, {route_name, direction_name}, "#{trip_name}\n")
      end
    end)
    |> Enum.map_join("\n\n", fn {{route_name, direction_name}, trips} ->
      "#{affected_trip_term(effect)} #{direction_name} trips on #{route_name}:\n#{String.trim(trips)}"
    end)
    |> String.trim()
  end

  @spec affected_direction(BuildAutoText.t()) :: String.t()
  def affected_direction(%{routes: [_route], direction: [_direction]} = autotext_data) do
    "Affected direction: #{BuildAutoText.direction_name(autotext_data)}"
  end

  def affected_direction(_), do: ""

  @spec affected_facilities(BuildAutoText.t()) :: String.t()
  def affected_facilities(%{facilities: []}), do: ""

  def affected_facilities(%{facilities: [_ | _] = facilities} = autotext_data) do
    facilities
    |> Enum.map(&affected_facility(Map.put(autotext_data, :facility, &1)))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  def affected_facility(%{facility: facility}) do
    facility.properties |> Enum.map_join(&get_service_text(&1))
  end

  defp get_service_text(%{name: "alternate-service-text", value: service_text}), do: service_text
  defp get_service_text(_), do: ""

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

  defp join(list, route_type) do
    Enum.map_join(list, "\n", &SelectFormatter.name_for_option(&1, route_type))
  end

  defp trip_direction_name(trip, route) do
    if Map.get(route, :direction_names) do
      String.downcase(route.direction_names[trip.direction_id])
    else
      Map.get(%{0 => "outbound", 1 => "inbound"}, trip.direction_id)
    end
  end
end
