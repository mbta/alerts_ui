defmodule AlertsUI.ActivitiesTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true

  alias AlertsUI.Activities

  describe "for_effect/1" do
    test "Access Issue" do
      assert Activities.for_effect("Access Issue") == [:USING_WHEELCHAIR]
    end

    test "Amber Alert" do
      assert Activities.for_effect("Amber Alert") == [:BOARD, :EXIT, :RIDE]
    end

    test "Bike Issue" do
      assert Activities.for_effect("Bike Issue") == [:BRINGING_BIKE, :STORE_BIKE]
    end

    test "Cancellation" do
      assert Activities.for_effect("Cancellation") == [:BOARD, :EXIT, :RIDE]
    end

    test "Delay" do
      assert Activities.for_effect("Delay") == [:BOARD, :EXIT, :RIDE]
    end

    test "Detour" do
      assert Activities.for_effect("Detour") == [:BOARD, :EXIT]
    end

    test "Dock Closure" do
      assert Activities.for_effect("Dock Closure") == [:BOARD, :EXIT]
    end

    test "Dock Issue" do
      assert Activities.for_effect("Dock Issue") == [:BOARD]
    end

    test "Elevator Closure" do
      assert Activities.for_effect("Elevator Closure") == [:USING_WHEELCHAIR]
    end

    test "Escalator Closure" do
      assert Activities.for_effect("Escalator Closure") == [:USING_ESCALATOR]
    end

    test "Extra Service" do
      assert Activities.for_effect("Extra Service") == [:BOARD, :EXIT, :RIDE]
    end

    test "Facility Issue" do
      assert Activities.for_effect("Facility Issue") == [
               :BRINGING_BIKE,
               :PARK_CAR,
               :STORE_BIKE,
               :USING_ESCALATOR,
               :USING_WHEELCHAIR
             ]
    end

    test "Multi-Route Detour" do
      assert Activities.for_effect("Multi-Route Detour") == [:BOARD, :RIDE]
    end

    test "Parking Closure" do
      assert Activities.for_effect("Parking Closure") == [:PARK_CAR]
    end

    test "Parking Issue" do
      assert Activities.for_effect("Parking Issue") == [:PARK_CAR]
    end

    test "Policy Change" do
      assert Activities.for_effect("Policy Change") == [:BOARD, :EXIT, :RIDE]
    end

    test "Schedule Change" do
      assert Activities.for_effect("Schedule Change") == [:BOARD, :EXIT, :RIDE]
    end

    test "Service Change" do
      assert Activities.for_effect("Service Change") == [:BOARD, :EXIT, :RIDE]
    end

    test "Snow Route" do
      assert Activities.for_effect("Snow Route") == [:BOARD, :EXIT]
    end

    test "Stop Move" do
      assert Activities.for_effect("Stop Move") == [:BOARD]
    end

    test "Stop Shoveling" do
      assert Activities.for_effect("Stop Shoveling") == [:BOARD, :RIDE]
    end

    test "Summary" do
      assert Activities.for_effect("Summary") == [:BOARD, :EXIT, :RIDE]
    end

    test "Track Change" do
      assert Activities.for_effect("Track Change") == [:BOARD]
    end

    test "defaults to an empty list" do
      assert Activities.for_effect("unknown effect") == []
    end
  end
end
