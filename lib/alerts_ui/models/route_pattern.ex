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

  @spec stop_type(APIRoutePattern.t(), Stop.t() | Stop.id_t()) :: stop_type()
  def stop_type(route_pattern, %Stop{id: stop_id}), do: stop_type(route_pattern, stop_id)

  def stop_type(route_pattern, stop_id) do
    cond do
      first_stop?(route_pattern, stop_id) ->
        :first

      last_stop?(route_pattern, stop_id) ->
        :last

      true ->
        :default
    end
  end

  @spec first_stop?(APIRoutePattern.t(), Stop.t() | Stop.id_t()) :: boolean()
  def first_stop?(route_pattern, %Stop{id: stop_id}), do: first_stop?(route_pattern, stop_id)
  def first_stop?(%APIRoutePattern{stops: stops}, stop_id), do: List.first(stops).id == stop_id

  @spec last_stop?(APIRoutePattern.t(), Stop.t() | Stop.id_t()) :: boolean()
  def last_stop?(route_pattern, %Stop{id: stop_id}), do: last_stop?(route_pattern, stop_id)
  def last_stop?(%APIRoutePattern{stops: stops}, stop_id), do: List.last(stops).id == stop_id
end
