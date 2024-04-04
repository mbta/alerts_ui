defmodule AlertsUI.Models.RoutePattern do
  @moduledoc """
  Work with RoutePattern data structs.
  """

  alias MBTAV3API.RoutePatterns.RoutePattern, as: APIRoutePattern
  alias MBTAV3API.Stops.Stop

  @type stop_type :: :first | :last | :default

  @spec stops(APIRoutePattern.t()) :: [Stop.t()]
  def stops(%APIRoutePattern{stops: stops}), do: stops

  @spec contains_stop?(APIRoutePattern.t(), Stop.t() | Stop.id_t()) :: boolean()
  def contains_stop?(route_pattern, %Stop{id: stop_id}),
    do: contains_stop?(route_pattern, stop_id)

  def contains_stop?(%APIRoutePattern{stops: stops}, stop_id),
    do: Enum.find_value(stops, false, &(&1.id == stop_id))

  @spec stop_type(APIRoutePattern.t(), [Stop.id_t()], Stop.t() | Stop.id_t()) :: stop_type()
  def stop_type(route_pattern, affected_stop_ids, %Stop{id: stop_id}),
    do: stop_type(route_pattern, affected_stop_ids, stop_id)

  def stop_type(route_pattern, affected_stop_ids, stop_id) do
    stops =
      route_pattern
      |> stops()
      |> Enum.filter(fn %Stop{id: stop_id, parent_id: parent_id} ->
        Enum.member?(affected_stop_ids, stop_id) or Enum.member?(affected_stop_ids, parent_id)
      end)

    cond do
      first_stop?(stops, stop_id) ->
        :first

      last_stop?(stops, stop_id) ->
        :last

      true ->
        :default
    end
  end

  @spec first_stop?([Stop.t()], Stop.t() | Stop.id_t()) :: boolean()
  def first_stop?([], _), do: false
  def first_stop?(stops, %Stop{id: stop_id}), do: first_stop?(stops, stop_id)
  def first_stop?([%Stop{id: first_stop_id} | _], stop_id), do: first_stop_id == stop_id

  @spec last_stop?([Stop.t()], Stop.t() | Stop.id_t()) :: boolean()
  def last_stop?([], _), do: false
  def last_stop?(stops, %Stop{id: stop_id}), do: last_stop?(stops, stop_id)
  def last_stop?(stops, stop_id), do: List.last(stops).id == stop_id
end
