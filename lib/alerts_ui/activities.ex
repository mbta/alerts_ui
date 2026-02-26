defmodule AlertsUI.Activities do
  @moduledoc """
    Context for working with activities.
  """

  alias AlertsUI.Models.{Activity, Effect, RoutePattern}

  @spec for_effect(Effect.effect_name()) :: [Activity.activity()]
  @spec for_effect(Effect.effect_name(), RoutePattern.stop_type()) :: [Activity.activity()]
  def for_effect(effect_name, stop_type \\ :default)
  def for_effect("Access Issue", _), do: [:USING_WHEELCHAIR]
  def for_effect("Amber Alert", _), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Bike Issue", _), do: [:BRINGING_BIKE, :STORE_BIKE]
  def for_effect("Cancellation", _), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Delay", _), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Detour", _), do: [:BOARD, :EXIT]
  def for_effect("Dock Bypass", _), do: [:BOARD, :EXIT]
  def for_effect("Dock Closure", _), do: [:BOARD, :EXIT]
  def for_effect("Dock Issue", _), do: [:BOARD]
  def for_effect("Elevator Closure", _), do: [:USING_WHEELCHAIR]
  def for_effect("Escalator Closure", _), do: [:USING_ESCALATOR]
  def for_effect("Extra Service", _), do: [:BOARD, :EXIT, :RIDE]

  def for_effect("Facility Issue", _),
    do: [:BRINGING_BIKE, :PARK_CAR, :STORE_BIKE, :USING_ESCALATOR, :USING_WHEELCHAIR]

  def for_effect("Multi-Route Detour", _), do: [:BOARD, :EXIT]
  def for_effect("Notice", _), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Parking Closure", _), do: [:PARK_CAR]
  def for_effect("Parking Issue", _), do: [:PARK_CAR]
  def for_effect("Policy Change", _), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Schedule Change", _), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Service Change", _), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Shuttle", :first), do: [:BOARD, :RIDE]
  def for_effect("Shuttle", :last), do: [:EXIT, :RIDE]
  def for_effect("Shuttle", _), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Single Tracking", _), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Snow Route", _), do: [:BOARD, :EXIT]
  def for_effect("Station Closure", _), do: [:BOARD, :EXIT]
  def for_effect("Station Bypass", _), do: [:BOARD, :EXIT]
  def for_effect("Station Issue", _), do: [:BOARD]
  def for_effect("Stop Closure", _), do: [:BOARD, :EXIT]
  def for_effect("Stop Move", _), do: [:BOARD]
  def for_effect("Suspension", :first), do: [:BOARD, :RIDE]
  def for_effect("Suspension", :last), do: [:EXIT, :RIDE]
  def for_effect("Suspension", _), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Summary", _), do: [:BOARD, :EXIT, :RIDE]
  def for_effect("Track Change", _), do: [:BOARD]
  def for_effect(_, _), do: []
end
