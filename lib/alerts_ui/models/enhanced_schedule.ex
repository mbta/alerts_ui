defmodule AlertsUI.Models.EnhancedSchedule do
  @moduledoc """
  Representation of schedules with a couple added convenience fields. Used only in frontend.
  """

  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.{Schedule, Trip}
  alias MBTAV3API.Stops.Stop

  @schedule_keys Map.keys(Schedule.__struct__()) |> List.delete(:__struct__)
  @enhanced_keys [use_trip_id_in_name?: false, last_stop_name: "", time_of_last_trip_arrival: nil]

  defstruct @schedule_keys ++ @enhanced_keys

  @type t :: %__MODULE__{
          route_id: Route.id_t(),
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
          last_stop_name: String.t(),
          time_of_last_trip_arrival: DateTime.t() | nil
        }
end
