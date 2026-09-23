defmodule AlertsUIWeb.DetoursViewerController do
  @moduledoc """
  Simple controller to list detours straight from bucket (minus their route segments)
  """
  use AlertsUIWeb, :controller
  alias AlertsUI.SkateDetours.GetDetours

  def index(conn, _params) do
    detours =
      GetDetours.get_detours()
      |> Enum.map(
        &Map.drop(&1, [:route_segments, :missed_stops_text_only, :connection_points_text_only])
      )
      |> Enum.map(&Map.from_struct(&1))

    list_of_routes_with_detours =
      Enum.map(detours, &String.to_integer(&1.route_id))
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.join(", ")

    encoded_detours =
      detours
      |> Jason.encode!()
      |> Jason.Formatter.pretty_print()

    text(
      conn,
      ["Routes with detours: #{list_of_routes_with_detours}", "Raw detours:", encoded_detours]
      |> Enum.join("\n")
    )
  end
end
