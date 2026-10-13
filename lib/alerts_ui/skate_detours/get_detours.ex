defmodule AlertsUI.SkateDetours.GetDetours do
  @moduledoc """
  Functions for reading in a skate detour file and parsing it into skate detour structs
  """
  require Logger
  alias AlertsUI.Models.SkateDetour

  def get_detours do
    case read_data() do
      {:ok, data} ->
        parse_json(data)

      {:error, reason} ->
        Logger.error("Could not read Skate Detours" <> reason)
        {:error, reason}
    end
  end

  @spec parse_json(binary()) :: list()
  defp parse_json(""), do: []

  defp parse_json(data) do
    data
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&parse_detour(&1))
    # filter out text-only detours
    |> Enum.reject(&is_nil(&1.missed_stops))
  end

  @spec parse_detour(binary()) :: SkateDetour.t()
  defp parse_detour(data) do
    # not parsing the route_segments because they're huge and we don't currently need them
    data = data |> Jason.decode!()

    %SkateDetour{
      id: data["id"],
      route_id: data["route_id"],
      reason: data["reason"],
      nearest_intersection: Map.get(data, "nearest_intersection"),
      estimated_duration: data["estimated_duration"],
      activated_at: DateTime.from_unix!(data["activated_at"]),
      updated_at: DateTime.from_unix!(data["updated_at"]),
      autoclose_on: safe_datetime_from_unix(Map.get(data, "autoclose_on")),
      direction_id: data["direction_id"],
      missed_stops: Map.get(data, "missed_stops"),
      connection_points: Map.get(data, "connection_points"),
      missed_stops_text_only: Map.get(data, "missed_stops_text_only"),
      connection_points_text_only: Map.get(data, "connections_points_text_only")
    }
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
