defmodule AlertsUIWeb.TripEndnWarningModalTest do
  use ExUnit.Case, async: true

  import AlertsUIWeb.TripEndWarningModal

  describe "show_warning?/1" do
    test "returns true if trip_arrival_time is before active_period_start" do
      trip_arrival_time = ~N[2026-07-17 10:00:00]
      active_period_start = ~N[2026-07-17 12:00:17]
      modal_date = "2026-07-17"

      assert show_warning?(trip_arrival_time, active_period_start, modal_date)
    end

    test "returns false if trip_arrival_time is after active_period_start" do
      trip_arrival_time = ~N[2026-07-17 10:00:00]
      active_period_start = ~N[2026-07-17 09:00:17]
      modal_date = "2026-07-17"

      refute show_warning?(trip_arrival_time, active_period_start, modal_date)
    end

    test "returns false if trip_arrival_time is not naive datetime" do
      trip_arrival_time = nil
      active_period_start = ~N[2026-07-17 09:00:17]
      modal_date = "2026-07-17"

      refute show_warning?(trip_arrival_time, active_period_start, modal_date)
    end

    test "returns false if active_period_start is not naive datetime" do
      trip_arrival_time = ~N[2026-07-17 09:00:17]
      active_period_start = nil
      modal_date = "2026-07-17"

      refute show_warning?(trip_arrival_time, active_period_start, modal_date)
    end

    test "returns false if modal date is nil" do
      trip_arrival_time = ~N[2026-07-17 10:00:00]
      active_period_start = ~N[2026-07-17 09:00:17]
      modal_date = nil

      refute show_warning?(trip_arrival_time, active_period_start, modal_date)
    end
  end
end
