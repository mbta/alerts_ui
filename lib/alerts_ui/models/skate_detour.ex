defmodule AlertsUI.Models.RouteSegments do
  @moduledoc """
  Representation of the route segments from a Skate detour
  """
  defstruct [
    :before_detour,
    :after_detour,
    :bypassed_segment,
    :detour_segment
  ]

  @type t :: %__MODULE__{
          before_detour: [%{lat: float(), lon: float()}],
          after_detour: [%{lat: float(), lon: float()}],
          bypassed_segment: [%{lat: float(), lon: float()}],
          detour_segment: [%{lat: float(), lon: float()}]
        }
end

defmodule AlertsUI.Models.SkateDetour do
  @moduledoc """
  Representation of a detour from Skate
  """

  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Stop

  defstruct [
    :id,
    :route_id,
    :reason,
    :nearest_intersection,
    :estimated_duration,
    :activated_at,
    :updated_at,
    :autoclose_on,
    :direction_id,
    :missed_stops,
    :route_segments,
    :connection_points,
    :missed_stops_text_only,
    :connection_points_text_only
  ]

  @type t :: %__MODULE__{
          id: integer,
          route_id: Route.id_t(),
          reason: String.t(),
          nearest_intersection: String.t() | nil,
          estimated_duration: String.t(),
          activated_at: DateTime.t(),
          updated_at: DateTime.t(),
          autoclose_on: DateTime.t() | nil,
          direction_id: non_neg_integer,
          missed_stops: [Stop.id_t()] | nil,
          connection_points: [Stop.id_t()] | nil,
          route_segments: AlertsUI.Models.RouteSegments.t() | nil,
          missed_stops_text_only: String.t() | nil,
          connection_points_text_only: String.t() | nil
        }
end
