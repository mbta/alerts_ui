defmodule AlertsUI.Models.EnhancedSchedule do
  @moduledoc """
  Representation of schedules with a couple added convenience fields. Used only in frontend.
  """

  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.{Schedule, Trip}
  alias MBTAV3API.Stops.Stop

  defstruct Map.keys(Schedule.__struct__()) ++ [use_trip_id_in_name?: false, last_stop_name: ""]

  @type t :: %__MODULE__{
          route: Route.t(),
          trip: Trip.t(),
          stop: Stop.t(),
          arrival_time: DateTime.t() | nil,
          departure_time: DateTime.t() | nil,
          time: DateTime.t(),
          flag?: boolean,
          early_departure?: boolean,
          last_stop?: boolean,
          stop_sequence: non_neg_integer,
          pickup_type: integer,
          platform_stop_id: Stop.id_t(),
          use_trip_id_in_name?: boolean,
          last_stop_name: String.t()
        }
end
