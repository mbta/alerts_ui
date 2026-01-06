defmodule AlertsUI.Configs.ModeEffect do
  @moduledoc """
  Config for mode-effect combinations and their various properties
  """
  @mode_effect %{
    subway: %{
      "Delay" => %{combination: :RDS, default_severity: 3, default_cause: nil},
      "Extra Service" => %{combination: :R, default_severity: 3, default_cause: nil},
      "Schedule Change" => %{combination: :R, default_severity: 3, default_cause: nil},
      "Service Change" => %{combination: :RDS, default_severity: 7, default_cause: nil},
      "Shuttle" => %{combination: :RDS, default_severity: 7, default_cause: nil},
      "Single Tracking" => %{
        combination: :RDS,
        default_severity: 1,
        default_cause: "SINGLE_TRACKING"
      },
      "Station Bypass" => %{combination: :RDS, default_severity: 7, default_cause: nil},
      "Station Closure" => %{combination: :SR, default_severity: 7, default_cause: nil},
      "Station Issue" => %{combination: :SR, default_severity: 1, default_cause: nil},
      "Suspension" => %{combination: :RDS, default_severity: 7, default_cause: nil}
    },
    commuter_rail: %{
      "Cancellation" => %{combination: :RDT, default_severity: 5, default_cause: nil},
      "Delay" => %{combination: :RDTS, default_severity: 3, default_cause: nil},
      "Extra Service" => %{combination: :R, default_severity: 3, default_cause: nil},
      "Schedule Change" => %{combination: :R, default_severity: 3, default_cause: nil},
      "Service Change" => %{combination: :RDTS, default_severity: 3, default_cause: nil},
      "Shuttle" => %{combination: :RDTS, default_severity: 7, default_cause: nil},
      "Station Bypass" => %{combination: :RDTS, default_severity: 7, default_cause: nil},
      "Station Closure" => %{combination: :SR, default_severity: 7, default_cause: nil},
      "Station Issue" => %{combination: :SR, default_severity: 1, default_cause: nil},
      "Suspension" => %{combination: :RDTS, default_severity: 7, default_cause: nil},
      "Track Change" => %{combination: :RDTS, default_severity: 7}
    },
    bus: %{
      "Delay" => %{combination: :RDS, default_severity: 4, default_cause: nil},
      "Detour" => %{combination: :RDS, default_severity: 7, default_cause: nil},
      "Extra Service" => %{combination: :R, default_severity: 3, default_cause: nil},
      "Multi-Route Detour" => %{combination: :SR, default_severity: 7, default_cause: nil},
      "Schedule Change" => %{combination: :R, default_severity: 3, default_cause: nil},
      "Service Change" => %{combination: :RDS, default_severity: 3, default_cause: nil},
      "Snow Route" => %{combination: :RDS, default_severity: 5, default_cause: nil},
      "Stop Closure" => %{combination: :SR, default_severity: 5, default_cause: nil},
      "Stop Move" => %{combination: :SR, default_severity: 1, default_cause: nil},
      "Suspension" => %{combination: :RDS, default_severity: 7, default_cause: nil}
    },
    ferry: %{
      "Cancellation" => %{combination: :RDT, default_severity: 5, default_cause: nil},
      "Delay" => %{combination: :RDTS, default_severity: 3, default_cause: nil},
      "Dock Closure" => %{combination: :SR, default_severity: 5, default_cause: nil},
      "Dock Issue" => %{combination: :SR, default_severity: 1, default_cause: nil},
      "Extra Service" => %{combination: :R, default_severity: 3, default_cause: nil},
      "Schedule Change" => %{combination: :R, default_severity: 3, default_cause: nil},
      "Service Change" => %{combination: :RDTS, default_severity: 3, default_cause: nil},
      "Shuttle" => %{combination: :RDTS, default_severity: 7, default_cause: nil},
      "Suspension" => %{combination: :RDTS, default_severity: 7, default_cause: nil}
    },
    facility: %{
      "Access Issue" => %{combination: :ACCESS, default_severity: 3, default_cause: nil},
      "Bike Issue" => %{combination: :ACCESS, default_severity: 3, default_cause: nil},
      "Elevator Closure" => %{combination: :ACCESS, default_severity: 3, default_cause: nil},
      "Escalator Closure" => %{combination: :ACCESS, default_severity: 3, default_cause: nil},
      "Facility Issue" => %{combination: :ACCESS, default_severity: 3, default_cause: nil},
      "Parking Closure" => %{combination: :ACCESS, default_severity: 3, default_cause: nil},
      "Parking Issue" => %{combination: :ACCESS, default_severity: 3, default_cause: nil}
    },
    systemwide: %{
      "Amber Alert" => %{combination: nil, default_severity: 3, default_cause: nil},
      "Delay" => %{combination: nil, default_severity: 5, default_cause: nil},
      "Extra Service" => %{combination: nil, default_severity: 3, default_cause: nil},
      "Policy Change" => %{combination: nil, default_severity: 3, default_cause: nil},
      "Schedule Change" => %{combination: nil, default_severity: 3, default_cause: nil},
      "Service Change" => %{combination: nil, default_severity: 7, default_cause: nil},
      "Summary" => %{combination: nil, default_severity: 1, default_cause: nil},
      "Suspension" => %{combination: nil, default_severity: 7, default_cause: nil}
    }
  }

  def mode_effect, do: @mode_effect
end
