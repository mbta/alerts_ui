defmodule AlertsUI.Models.RoutePatternTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true

  alias AlertsUI.Models.RoutePattern
  alias MBTAV3API.RoutePatterns.RoutePattern, as: APIRoutePattern
  alias MBTAV3API.Stops.Stop

  @stop1 %Stop{id: "s1"}
  @stop2 %Stop{id: "s2"}
  @stop3 %Stop{id: "s3"}
  @stops [@stop1, @stop2, @stop3]
  @route_pattern %APIRoutePattern{
    id: "rp1",
    stops: @stops
  }

  describe "stops/1" do
    test "returns the stops for a given RoutePattern" do
      assert RoutePattern.stops(@route_pattern) == @stops
    end
  end

  describe "contains_stop?/2" do
    test "true if the pattern contains a stop with this ID" do
      assert RoutePattern.contains_stop?(@route_pattern, @stop1.id)
      assert RoutePattern.contains_stop?(@route_pattern, @stop2.id)
      assert RoutePattern.contains_stop?(@route_pattern, @stop3.id)
    end

    test "true if the pattern contains this stop" do
      assert RoutePattern.contains_stop?(@route_pattern, @stop1)
      assert RoutePattern.contains_stop?(@route_pattern, @stop2)
      assert RoutePattern.contains_stop?(@route_pattern, @stop3)
    end

    test "false if the pattern does not contains a stop with this ID" do
      refute RoutePattern.contains_stop?(@route_pattern, "missing")
    end

    test "false if the pattern does not contains this stop" do
      refute RoutePattern.contains_stop?(@route_pattern, %Stop{id: "missing"})
    end
  end

  describe "stop_type/2" do
    test "returns first if this is the ID of the first stop in the pattern" do
      assert RoutePattern.stop_type(@route_pattern, @stop1.id) == :first
    end

    test "returns first if this is the first stop in the pattern" do
      assert RoutePattern.stop_type(@route_pattern, @stop1) == :first
    end

    test "returns last if this is the ID of the last stop in the pattern" do
      assert RoutePattern.stop_type(@route_pattern, @stop3.id) == :last
    end

    test "returns last if this is the last stop in the pattern" do
      assert RoutePattern.stop_type(@route_pattern, @stop3) == :last
    end

    test "returns default if this is the ID of neither the first or last stop in the pattern" do
      assert RoutePattern.stop_type(@route_pattern, @stop2.id) == :default
    end

    test "returns default if this is neither the first or last stop in the pattern" do
      assert RoutePattern.stop_type(@route_pattern, @stop2) == :default
    end
  end

  describe "first_stop?/2" do
    test "true if the stop ID matches the first stop in this pattern" do
      assert RoutePattern.first_stop?(@route_pattern, @stop1.id)
    end

    test "true if the stop matches the first stop in this pattern" do
      assert RoutePattern.first_stop?(@route_pattern, @stop1)
    end

    test "false if the stop ID does not matches the first stop in this pattern" do
      refute RoutePattern.first_stop?(@route_pattern, @stop2.id)
      refute RoutePattern.first_stop?(@route_pattern, @stop3.id)
    end

    test "false if the stop does not matches the first stop in this pattern" do
      refute RoutePattern.first_stop?(@route_pattern, @stop2)
      refute RoutePattern.first_stop?(@route_pattern, @stop3)
    end
  end

  describe "last_stop?/2" do
    test "true if the stop ID matches the first stop in this pattern" do
      assert RoutePattern.last_stop?(@route_pattern, @stop3.id)
    end

    test "true if the stop matches the first stop in this pattern" do
      assert RoutePattern.last_stop?(@route_pattern, @stop3)
    end

    test "false if the stop ID does not matches the first stop in this pattern" do
      refute RoutePattern.last_stop?(@route_pattern, @stop1.id)
      refute RoutePattern.last_stop?(@route_pattern, @stop2.id)
    end

    test "false if the stop does not matches the first stop in this pattern" do
      refute RoutePattern.last_stop?(@route_pattern, @stop1)
      refute RoutePattern.last_stop?(@route_pattern, @stop2)
    end
  end
end
