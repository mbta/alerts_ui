defmodule AlertsUI.Models.ModeEffectStruct do
  @moduledoc "Describe a map of all aspects of an effect"
  defstruct [
    :combination,
    :default_cause,
    :default_severity,
    :send_push_notification_on_edit,
    :prediction_suppression_warning
  ]

  @type t :: %{
          combination: atom(),
          default_cause: String.t() | nil,
          default_severity: integer(),
          send_push_notification_on_edit: boolean(),
          prediction_suppression_warning: boolean()
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
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Extra Service" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Schedule Change" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Service Change" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Shuttle" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: true
      },
      "Single Tracking" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: "SINGLE_TRACKING",
        default_severity: 1,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Station Bypass" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Station Closure" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Station Issue" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 1,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Suspension" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: true
      }
    },
    commuter_rail: %{
      "Cancellation" => %ModeEffectStruct{
        combination: :RDT,
        default_cause: nil,
        default_severity: 5,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: true
      },
      "Delay" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false
      },
      "Extra Service" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false
      },
      "Schedule Change" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false
      },
      "Service Change" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false
      },
      "Shuttle" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: true
      },
      "Station Bypass" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false
      },
      "Station Closure" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false
      },
      "Station Issue" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 1,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false
      },
      "Suspension" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: true
      },
      "Track Change" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: true,
        prediction_suppression_warning: false
      }
    },
    bus: %{
      "Delay" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 4,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Detour" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Extra Service" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Multi-Route Detour" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Schedule Change" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Service Change" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Snow Route" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 5,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Stop Closure" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 5,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Stop Move" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 1,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Suspension" => %ModeEffectStruct{
        combination: :RDS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: true
      }
    },
    ferry: %{
      "Cancellation" => %ModeEffectStruct{
        combination: :RDT,
        default_cause: nil,
        default_severity: 5,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: true
      },
      "Delay" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Dock Closure" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 5,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Dock Issue" => %ModeEffectStruct{
        combination: :SR,
        default_cause: nil,
        default_severity: 1,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Extra Service" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Schedule Change" => %ModeEffectStruct{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Service Change" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Shuttle" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: true
      },
      "Suspension" => %ModeEffectStruct{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: true
      }
    },
    facility: %{
      "Access Issue" => %ModeEffectStruct{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Bike Issue" => %ModeEffectStruct{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Elevator Closure" => %ModeEffectStruct{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Escalator Closure" => %ModeEffectStruct{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Facility Issue" => %ModeEffectStruct{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Parking Closure" => %ModeEffectStruct{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Parking Issue" => %ModeEffectStruct{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      }
    },
    systemwide: %{
      "Amber Alert" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Delay" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 5,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Extra Service" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Policy Change" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Schedule Change" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Service Change" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Summary" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 1,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Suspension" => %ModeEffectStruct{
        combination: nil,
        default_cause: nil,
        default_severity: 7,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      }
    }
  }

  @spec mode_effect() :: %{atom => %{String.t() => ModeEffectStruct.t()}}
  def mode_effect, do: @mode_effect
end
