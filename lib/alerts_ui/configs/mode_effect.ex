defmodule AlertsUI.Configs.ModeEffect do
  @moduledoc """
  Config for mode-effect combinations and their various properties
  """
  @mode_effect %{
    subway: %{
      "Delay" => %{combination: :RDS, default_severity: 3},
      "Extra Service" => %{combination: :R, default_severity: 3},
      "Schedule Change" => %{combination: :R, default_severity: 3},
      "Service Change" => %{combination: :RDS, default_severity: 7},
      "Shuttle" => %{combination: :RDS, default_severity: 7},
      "Single Tracking" => %{combination: :RDS, default_severity: 1},
      "Station Bypass" => %{combination: :RDS, default_severity: 7},
      "Station Closure" => %{combination: :SR, default_severity: 7},
      "Station Issue" => %{combination: :SR, default_severity: 1},
      "Suspension" => %{combination: :RDS, default_severity: 7}
    },
    commuter_rail: %{
      "Cancellation" => %{combination: :RDT, default_severity: 5},
      "Delay" => %{combination: :RDTS, default_severity: 3},
      "Extra Service" => %{combination: :R, default_severity: 3},
      "Schedule Change" => %{combination: :R, default_severity: 3},
      "Service Change" => %{combination: :RDTS, default_severity: 3},
      "Shuttle" => %{combination: :RDTS, default_severity: 7},
      "Station Bypass" => %{combination: :RDTS, default_severity: 7},
      "Station Closure" => %{combination: :SR, default_severity: 7},
      "Station Issue" => %{combination: :SR, default_severity: 1},
      "Suspension" => %{combination: :RDTS, default_severity: 7},
      "Track Change" => %{combination: :RDTS, default_severity: 7}
    },
    bus: %{
      "Delay" => %{combination: :RDS, default_severity: 4},
      "Detour" => %{combination: :RDS, default_severity: 7},
      "Extra Service" => %{combination: :R, default_severity: 3},
      "Multi-Route Detour" => %{combination: :SR, default_severity: 7},
      "Schedule Change" => %{combination: :R, default_severity: 3},
      "Service Change" => %{combination: :RDS, default_severity: 3},
      "Snow Route" => %{combination: :RDS, default_severity: 5},
      "Stop Closure" => %{combination: :SR, default_severity: 5},
      "Stop Move" => %{combination: :SR, default_severity: 1},
      "Suspension" => %{combination: :RDS, default_severity: 7}
    },
    ferry: %{
      "Cancellation" => %{combination: :RDT, default_severity: 5},
      "Delay" => %{combination: :RDTS, default_severity: 3},
      "Dock Closure" => %{combination: :SR, default_severity: 5},
      "Dock Issue" => %{combination: :SR, default_severity: 1},
      "Extra Service" => %{combination: :R, default_severity: 3},
      "Schedule Change" => %{combination: :R, default_severity: 3},
      "Service Change" => %{combination: :RDTS, default_severity: 3},
      "Shuttle" => %{combination: :RDTS, default_severity: 7},
      "Suspension" => %{combination: :RDTS, default_severity: 7}
    },
    facility: %{
      "Access Issue" => %{combination: :ACCESS, default_severity: 3},
      "Bike Issue" => %{combination: :ACCESS, default_severity: 3},
      "Elevator Closure" => %{combination: :ACCESS, default_severity: 3},
      "Escalator Closure" => %{combination: :ACCESS, default_severity: 3},
      "Facility Issue" => %{combination: :ACCESS, default_severity: 3},
      "Parking Closure" => %{combination: :ACCESS, default_severity: 3},
      "Parking Issue" => %{combination: :ACCESS, default_severity: 3}
    },
    systemwide: %{
      "Amber Alert" => %{combination: nil, default_severity: 3},
      "Delay" => %{combination: nil, default_severity: 5},
      "Extra Service" => %{combination: nil, default_severity: 3},
      "Policy Change" => %{combination: nil, default_severity: 3},
      "Schedule Change" => %{combination: nil, default_severity: 3},
      "Service Change" => %{combination: nil, default_severity: 7},
      "Summary" => %{combination: nil, default_severity: 1},
      "Suspension" => %{combination: nil, default_severity: 7}
    }
  }

  def mode_effect, do: @mode_effect
end
