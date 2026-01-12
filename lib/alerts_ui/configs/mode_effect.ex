defmodule AlertsUI.Configs.ModeEffect do
  @moduledoc """
  Config for mode-effect combinations and their various properties
  """
  @mode_effect %{
    subway: %{
      "Delay" => %{
        combination: :RDS,
        default_cause: nil,
        default_severity: 3,
        send_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Extra Service" => %{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Schedule Change" => %{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Service Change" => %{
        combination: :RDS,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Shuttle" => %{
        combination: :RDS,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: true
      },
      "Single Tracking" => %{
        combination: :RDS,
        default_cause: "SINGLE_TRACKING",
        default_severity: 1,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Station Bypass" => %{
        combination: :RDS,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Station Closure" => %{
        combination: :SR,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Station Issue" => %{
        combination: :SR,
        default_cause: nil,
        default_severity: 1,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Suspension" => %{
        combination: :RDS,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: true
      }
    },
    commuter_rail: %{
      "Cancellation" => %{
        combination: :RDT,
        default_cause: nil,
        default_severity: 5,
        end_push_notification_on_edit: true,
        prediction_suppression_warning: true
      },
      "Delay" => %{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: true,
        prediction_suppression_warning: false
      },
      "Extra Service" => %{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: true,
        prediction_suppression_warning: false
      },
      "Schedule Change" => %{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: true,
        prediction_suppression_warning: false
      },
      "Service Change" => %{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: true,
        prediction_suppression_warning: false
      },
      "Shuttle" => %{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: true,
        prediction_suppression_warning: true
      },
      "Station Bypass" => %{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: true,
        prediction_suppression_warning: false
      },
      "Station Closure" => %{
        combination: :SR,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: true,
        prediction_suppression_warning: false
      },
      "Station Issue" => %{
        combination: :SR,
        default_cause: nil,
        default_severity: 1,
        end_push_notification_on_edit: true,
        prediction_suppression_warning: false
      },
      "Suspension" => %{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: true,
        prediction_suppression_warning: true
      },
      "Track Change" => %{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: true,
        prediction_suppression_warning: false
      }
    },
    bus: %{
      "Delay" => %{
        combination: :RDS,
        default_cause: nil,
        default_severity: 4,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Detour" => %{
        combination: :RDS,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Extra Service" => %{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Multi-Route Detour" => %{
        combination: :SR,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Schedule Change" => %{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Service Change" => %{
        combination: :RDS,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Snow Route" => %{
        combination: :RDS,
        default_cause: nil,
        default_severity: 5,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Stop Closure" => %{
        combination: :SR,
        default_cause: nil,
        default_severity: 5,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Stop Move" => %{
        combination: :SR,
        default_cause: nil,
        default_severity: 1,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Suspension" => %{
        combination: :RDS,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: true
      }
    },
    ferry: %{
      "Cancellation" => %{
        combination: :RDT,
        default_cause: nil,
        default_severity: 5,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: true
      },
      "Delay" => %{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Dock Closure" => %{
        combination: :SR,
        default_cause: nil,
        default_severity: 5,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Dock Issue" => %{
        combination: :SR,
        default_cause: nil,
        default_severity: 1,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Extra Service" => %{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Schedule Change" => %{
        combination: :R,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Service Change" => %{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Shuttle" => %{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: true
      },
      "Suspension" => %{
        combination: :RDTS,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: true
      }
    },
    facility: %{
      "Access Issue" => %{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Bike Issue" => %{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Elevator Closure" => %{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Escalator Closure" => %{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Facility Issue" => %{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Parking Closure" => %{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Parking Issue" => %{
        combination: :ACCESS,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      }
    },
    systemwide: %{
      "Amber Alert" => %{
        combination: nil,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Delay" => %{
        combination: nil,
        default_cause: nil,
        default_severity: 5,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Extra Service" => %{
        combination: nil,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Policy Change" => %{
        combination: nil,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Schedule Change" => %{
        combination: nil,
        default_cause: nil,
        default_severity: 3,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Service Change" => %{
        combination: nil,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Summary" => %{
        combination: nil,
        default_cause: nil,
        default_severity: 1,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      },
      "Suspension" => %{
        combination: nil,
        default_cause: nil,
        default_severity: 7,
        end_push_notification_on_edit: false,
        prediction_suppression_warning: false
      }
    }
  }

  def mode_effect, do: @mode_effect
end
