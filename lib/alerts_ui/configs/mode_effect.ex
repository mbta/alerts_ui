defmodule AlertsUI.Configs.ModeEffect do
  @moduledoc """
  Config for mode-effect combinations and their various properties
  """
  @mode_effect %{
    subway: %{
      "Delay" => %{combination: :RDS},
      "Extra Service" => %{combination: :R},
      "Schedule Change" => %{combination: :R},
      "Service Change" => %{combination: :RDS},
      "Shuttle" => %{combination: :RDS},
      "Station Closure" => %{combination: :SR},
      "Station Issue" => %{combination: :SR},
      "Suspension" => %{combination: :RDS}
    },
    commuter_rail: %{
      "Cancellation" => %{combination: :RDT},
      "Delay" => %{combination: :RDTS},
      "Extra Service" => %{combination: :R},
      "Schedule Change" => %{combination: :R},
      "Service Change" => %{combination: :RDTS},
      "Shuttle" => %{combination: :RDTS},
      "Station Closure" => %{combination: :SR},
      "Station Issue" => %{combination: :SR},
      "Suspension" => %{combination: :RDS},
      "Track Change" => %{combination: :RDTS}
    },
    bus: %{
      "Delay" => %{combination: :RDS},
      "Detour" => %{combination: :RDS},
      "Extra Service" => %{combination: :R},
      "Multi-Route Detour" => %{combination: :SR},
      "Schedule Change" => %{combination: :R},
      "Service Change" => %{combination: :RDS},
      "Snow Route" => %{combination: :RDS},
      "Stop Closure" => %{combination: :SR},
      "Stop Move" => %{combination: :SR},
      "Suspension" => %{combination: :RDS}
    },
    ferry: %{
      "Cancellation" => %{combination: :RDT},
      "Delay" => %{combination: :RDTS},
      "Dock Closure" => %{combination: :SR},
      "Dock Issue" => %{combination: :SR},
      "Extra Service" => %{combination: :R},
      "Schedule Change" => %{combination: :R},
      "Service Change" => %{combination: :RDTS},
      "Shuttle" => %{combination: :RDS},
      "Suspension" => %{combination: :RDS}
    },
    facility: %{
      "Access Issue" => %{combination: :ACCESS},
      "Bike Issue" => %{combination: :ACCESS},
      "Elevator Closure" => %{combination: :ACCESS},
      "Escalator Closure" => %{combination: :ACCESS},
      "Facility Issue" => %{combination: :ACCESS},
      "Parking Closure" => %{combination: :ACCESS},
      "Parking Issue" => %{combination: :ACCESS}
    },
    systemwide: %{
      "Amber Alert" => %{combination: nil},
      "Delay" => %{combination: nil},
      "Extra Service" => %{combination: nil},
      "Policy Change" => %{combination: nil},
      "Schedule Change" => %{combination: nil},
      "Service Change" => %{combination: nil},
      "Summary" => %{combination: nil},
      "Suspension" => %{combination: nil}
    }
  }

  def mode_effect, do: @mode_effect
end
