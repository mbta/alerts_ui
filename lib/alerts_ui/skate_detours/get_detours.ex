defmodule AlertsUI.SkateDetours.GetDetours do
  @moduledoc """
  Functions for reading in a skate detour file and parsing it into skate detour structs
  """
  require Logger
  alias AlertsUI.Models.{RouteSegments, SkateDetour}

  def get_detours(with_route_segments? \\ false) do
    case read_data() do
      {:ok, data} ->
        parse_json(data, with_route_segments?)

      {:error, reason} ->
        Logger.error("Could not read Skate Detours" <> reason)
        {:error, reason}
    end
  end

  @spec parse_json(binary(), boolean()) :: list()
  defp parse_json("", _), do: []

  defp parse_json(data, with_route_segments?) do
    data
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&parse_detour(&1, with_route_segments?))
    # filter out text-only detours
    |> Enum.reject(&is_nil(&1.missed_stops))
  end

  @spec parse_detour(binary(), boolean()) :: SkateDetour.t()
  defp parse_detour(data, with_route_segments?) do
    # not parsing the route_segments because they're huge and we don't currently need them
    data = data |> Jason.decode!()

    detour = %SkateDetour{
      id: data["id"],
      route_id: data["route_id"],
      reason: data["reason"],
      nearest_intersection: Map.get(data, "nearest_intersection"),
      estimated_duration: data["estimated_duration"],
      activated_at: safe_datetime_from_unix(data["activated_at"]),
      updated_at: safe_datetime_from_unix(data["updated_at"]),
      autoclose_on: safe_datetime_from_unix(Map.get(data, "autoclose_on")),
      direction_id: data["direction_id"],
      missed_stops: Map.get(data, "missed_stops"),
      connection_points: Map.get(data, "connection_points"),
      missed_stops_text_only: Map.get(data, "missed_stops_text_only"),
      connection_points_text_only: Map.get(data, "connections_points_text_only")
    }

    if with_route_segments? do
      Map.merge(detour, %{route_segments: Map.get(data, "route_segments") |> parse_route_segments})
    else
      detour
    end
  end

  defp parse_route_segments(nil), do: nil

  defp parse_route_segments(data) do
    %RouteSegments{
      before_detour: Map.get(data, "before_detour"),
      after_detour: Map.get(data, "after_detour"),
      bypassed_segment: Map.get(data, "bypassed_segment"),
      detour_segment: Map.get(data, "detour_segment")
    }
    |> Map.from_struct()
  end

  @spec read_data() :: {:ok, binary()} | {:error, String.t()}
  def read_data do
    read_module = AlertsUI.config(:file_read_module)
    read_module.read()
  end

  defp safe_datetime_from_unix(datetime) when is_integer(datetime) do
    case DateTime.from_unix(datetime) do
      {:ok, datetime} -> datetime
      {:error, _reason} -> nil
    end
  end

  defp safe_datetime_from_unix(_), do: nil
end
