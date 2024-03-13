defmodule AlertsUI.Activities do
  @moduledoc """
    Context for working with activities.
  """

  alias AlertsUI.Models.{Activity, Effect}

  @spec for_effect(Effect.effect_name()) :: [Activity.activity()]
  def for_effect("Access Issue"), do: [:USING_WHEELCHAIR]
  def for_effect("Amber Alert"), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Bike Issue"), do: [:BRINGING_BIKE, :STORE_BIKE]
  def for_effect("Cancellation"), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Delay"), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Detour"), do: [:BOARD, :EXIT]
  def for_effect("Dock Closure"), do: [:BOARD, :EXIT]
  def for_effect("Dock Issue"), do: [:BOARD]
  def for_effect("Elevator Closure"), do: [:USING_WHEELCHAIR]
  def for_effect("Escalator Closure"), do: [:USING_ESCALATOR]
  def for_effect("Extra Service"), do: [:BOARD, :EXIT, :RIDE]

  def for_effect("Facility Issue"),
    do: [:BRINGING_BIKE, :PARK_CAR, :STORE_BIKE, :USING_ESCALATOR, :USING_WHEELCHAIR]

  def for_effect("Multi-Route Detour"), do: [:BOARD, :RIDE]
  def for_effect("Parking Closure"), do: [:PARK_CAR]
  def for_effect("Parking Issue"), do: [:PARK_CAR]
  def for_effect("Policy Change"), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Schedule Change"), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Service Change"), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Snow Route"), do: [:BOARD, :EXIT]
  def for_effect("Stop Move"), do: [:BOARD]
  def for_effect("Stop Shoveling"), do: [:BOARD, :RIDE]
  def for_effect("Summary"), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Track Change"), do: [:BOARD]
  def for_effect(_), do: []
end
