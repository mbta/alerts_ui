defmodule AlertsUI.Models.ModeEffectStruct do
  @moduledoc "Describe a map of all aspects of an effect.
  Values either have a default or are required."

  @enforce_keys [
    :combination,
    :default_cause,
    :default_severity,
    :send_push_notification_on_edit,
    :prediction_suppression_warning,
    :path_name
  ]
  defstruct [
    :combination,
    :default_cause,
    :default_severity,
    :send_push_notification_on_edit,
    :prediction_suppression_warning,
    :path_name,
    send_push_notification_on_create: true
  ]

  @type t :: %{
          combination: atom(),
          default_cause: String.t() | nil,
          default_severity: integer(),
          send_push_notification_on_create: boolean(),
          send_push_notification_on_edit: boolean(),
          prediction_suppression_warning: boolean(),
          path_name: String.t()
        }
end

defmodule AlertsUI.Configs.ModeEffect do
  @moduledoc """
  Config for mode-effect combinations and their various properties
  """

  alias AlertsUI.Models.ModeEffectStruct

  @mode_effect %{
    subway: %{
      "Delay" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "delay"
      },
      "Extra Service" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "extra_service"
      },
      "Notice" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 1,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "notice"
      },
      "Schedule Change" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "schedule_change"
      },
      "Service Change" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "service_change"
      },
      "Shuttle" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: true,
        path_name: "shuttle"
      },
      "Single Tracking" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: "SINGLE_TRACKING",
        default_severity: 1,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "single_tracking"
      },
      "Station Bypass" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "station_bypass"
      },
      "Station Closure" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "station_closure"
      },
      "Station Issue" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 1,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "station_issue"
      },
      "Suspension" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: true,
        path_name: "suspension"
      }
    },
    commuter_rail: %{
      "Cancellation" => %ModeEffectStruct{
        combination: :RDT,
        default_cause: nil,
        default_severity: 5,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: true,
        path_name: "cancellation"
      },
      "Delay" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false,
        path_name: "delay"
      },
      "Extra Service" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false,
        path_name: "extra_service"
      },
      "Notice" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 1,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "notice"
      },
      "Schedule Change" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false,
        path_name: "schedule_change"
      },
      "Service Change" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false,
        path_name: "service_change"
      },
      "Shuttle" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: true,
        path_name: "shuttle"
      },
      "Station Bypass" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false,
        path_name: "station_bypass"
      },
      "Station Closure" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false,
        path_name: "station_closure"
      },
      "Station Issue" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 1,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false,
        path_name: "station_issue"
      },
      "Suspension" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: true,
        path_name: "suspension"
      },
      "Track Change" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false,
        path_name: "track_change"
      }
    },
    bus: %{
      "Delay" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 4,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "delay"
      },
      "Detour" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "detour"
      },
      "Extra Service" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "extra_service"
      },
      "Multi-Route Detour" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "multi-route_detour"
      },
      "Notice" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 1,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "notice"
      },
      "Schedule Change" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "schedule_change"
      },
      "Service Change" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "service_change"
      },
      "Snow Route" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 5,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "snow_route"
      },
      "Stop Closure" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 5,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "stop_closure"
      },
      "Stop Move" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 1,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "stop_move"
      },
      "Suspension" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: true,
        path_name: "suspension"
      }
    },
    ferry: %{
      "Cancellation" => %ModeEffectStruct{
        combination: :RDT,
        default_cause: nil,
        default_severity: 5,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: true,
        path_name: "cancellation"
      },
      "Delay" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "delay"
      },
      "Dock Bypass" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false,
        path_name: "dock_bypass"
      },
      "Dock Closure" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 5,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "dock_closure"
      },
      "Dock Issue" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 1,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "dock_issue"
      },
      "Extra Service" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "extra_service"
      },
      "Notice" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 1,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "notice"
      },
      "Schedule Change" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "schedule_change"
      },
      "Service Change" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "service_change"
      },
      "Shuttle" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: true,
        path_name: "shuttle"
      },
      "Suspension" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: true,
        path_name: "suspension"
      }
    },
    facility: %{
      "Access Issue" => %ModeEffectStruct{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "access_issue"
      },
      "Bike Issue" => %ModeEffectStruct{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "bike_issue"
      },
      "Elevator Closure" => %ModeEffectStruct{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "elevator_closure"
      },
      "Escalator Closure" => %ModeEffectStruct{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "escalator_closure"
      },
      "Facility Issue" => %ModeEffectStruct{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "facility_issue"
      },
      "Parking Closure" => %ModeEffectStruct{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "parking_closure"
      },
      "Parking Issue" => %ModeEffectStruct{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "parking_issue"
      }
    },
    systemwide: %{
      "Amber Alert" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "amber_alert"
      },
      "Delay" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 5,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "delay"
      },
      "Extra Service" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "extra_service"
      },
      "Notice" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 1,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "notice"
      },
      "Policy Change" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "policy_change"
      },
      "Schedule Change" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "schedule_change"
      },
      "Service Change" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "service_change"
      },
      "Summary" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 1,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "summary"
      },
      "Suspension" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_create: true,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false,
        path_name: "suspension"
      }
    }
  }

  @spec mode_effect() :: %{atom => %{String.t() => ModeEffectStruct.t()}}
  def mode_effect, do: @mode_effect

  def mode_effects_by_route_type_name(route_type_name) do
    @mode_effect[route_type_name]
  end
end
