defmodule AlertsUI.Models.ActivePeriodTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  alias AlertsUI.Models.ActivePeriod

  describe "changeset/2" do
    test "create with start and end time is valid" do
      params = %{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:01:00Z]}

      changeset = ActivePeriod.changeset(%ActivePeriod{}, params)
      assert changeset.valid?
    end

    test "create with just end time is valid" do
      changeset = ActivePeriod.changeset(%ActivePeriod{}, %{end: ~U[2023-10-13 00:01:00Z]})
      assert changeset.valid?
    end

    test "create with just start time is valid" do
      changeset = ActivePeriod.changeset(%ActivePeriod{}, %{start: ~U[2023-10-12 00:01:00Z]})
      assert changeset.valid?
    end

    test "create with not start or end time is not valid" do
      changeset = ActivePeriod.changeset(%ActivePeriod{}, %{})
      assert changeset.valid? == false
    end
  end

  describe "is_time_inside_active_period?/2" do
    test "uses current time as default time" do
      active_period = %ActivePeriod{start: ~U[2008-10-12 00:01:00Z]}
      result = ActivePeriod.is_time_inside_active_period?(active_period)
      assert result == true
    end

    test "if no end time, returns true if time is after start" do
      active_period = %ActivePeriod{start: ~U[2023-10-12 00:01:00Z]}
      result = ActivePeriod.is_time_inside_active_period?(active_period, ~U[2023-10-13 00:01:00Z])
      assert result == true
    end

    test "if no end time, returns false if time is before start" do
      active_period = %ActivePeriod{start: ~U[2023-10-12 00:01:00Z]}
      result = ActivePeriod.is_time_inside_active_period?(active_period, ~U[2023-10-11 00:01:00Z])
      assert result == false
    end

    test "if no start time, returns true if time is before end" do
      active_period = %ActivePeriod{end: ~U[2023-10-12 00:01:00Z]}
      result = ActivePeriod.is_time_inside_active_period?(active_period, ~U[2023-10-11 00:01:00Z])
      assert result == true
    end

    test "if no start time, returns false if time is after end" do
      active_period = %ActivePeriod{end: ~U[2023-10-12 00:01:00Z]}
      result = ActivePeriod.is_time_inside_active_period?(active_period, ~U[2023-10-13 00:01:00Z])
      assert result == false
    end

    test "if start and end, return true if time is between them" do
      active_period = %ActivePeriod{
        start: ~U[2023-10-10 00:01:00Z],
        end: ~U[2023-10-12 00:01:00Z]
      }

      result = ActivePeriod.is_time_inside_active_period?(active_period, ~U[2023-10-11 00:01:00Z])
      assert result == true
    end

    test "if start and end, returns false if time is before start" do
      active_period = %ActivePeriod{
        start: ~U[2023-10-10 00:01:00Z],
        end: ~U[2023-10-12 00:01:00Z]
      }

      result = ActivePeriod.is_time_inside_active_period?(active_period, ~U[2023-10-09 00:01:00Z])
      assert result == false
    end

    test "if start and end, returns false if time is after end" do
      active_period = %ActivePeriod{
        start: ~U[2023-10-10 00:01:00Z],
        end: ~U[2023-10-12 00:01:00Z]
      }

      result = ActivePeriod.is_time_inside_active_period?(active_period, ~U[2023-10-13 00:01:00Z])
      assert result == false
    end
  end
end
