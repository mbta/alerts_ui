defmodule AlertsUIWeb.CreateAlertLive.Helpers.TimeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AlertsUIWeb.CreateAlertLive.Helpers.Time, as: TimeHelper

  describe "today/0" do
    test "returns today's date in America/New_York" do
      expected = DateTime.now!("America/New_York") |> DateTime.to_date()
      assert TimeHelper.today() == expected
    end
  end

  describe "replace_date/2 with DateTime" do
    test "replaces the date while preserving the time and zone" do
      dt = DateTime.new!(~D[2024-11-27], ~T[09:30:00], "America/New_York")

      result = TimeHelper.replace_date(~D[2025-01-15], dt)

      assert result == DateTime.new!(~D[2025-01-15], ~T[09:30:00], "America/New_York")
      assert result.time_zone == "America/New_York"
    end
  end

  describe "replace_date/2 with NaiveDateTime" do
    test "replaces the date while preserving the time" do
      result = TimeHelper.replace_date(~D[2025-01-15], ~N[2024-11-27 09:30:00])

      assert result == ~N[2025-01-15 09:30:00]
    end
  end

  describe "replace_time/2 with DateTime" do
    test "replaces the time while preserving the date and zone" do
      dt = DateTime.new!(~D[2024-11-27], ~T[09:30:00], "America/New_York")

      result = TimeHelper.replace_time(dt, ~T[23:45:00])

      assert result == DateTime.new!(~D[2024-11-27], ~T[23:45:00], "America/New_York")
      assert result.time_zone == "America/New_York"
    end
  end

  describe "replace_time/2 with NaiveDateTime" do
    test "replaces the time while preserving the date" do
      result = TimeHelper.replace_time(~N[2024-11-27 09:30:00], ~T[23:45:00])

      assert result == ~N[2024-11-27 23:45:00]
    end
  end
end
