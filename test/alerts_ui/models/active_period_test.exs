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

  describe "time_inside_active_period?/2" do
    test "uses current time as default time" do
      active_period = %ActivePeriod{start: ~U[2008-10-12 00:01:00Z]}
      result = ActivePeriod.time_inside_active_period?(active_period)
      assert result == true
    end

    test "if no end time, returns true if time is after start" do
      active_period = %ActivePeriod{start: ~U[2023-10-12 00:01:00Z]}
      result = ActivePeriod.time_inside_active_period?(active_period, ~U[2023-10-13 00:01:00Z])
      assert result == true
    end

    test "if no end time, returns false if time is before start" do
      active_period = %ActivePeriod{start: ~U[2023-10-12 00:01:00Z]}
      result = ActivePeriod.time_inside_active_period?(active_period, ~U[2023-10-11 00:01:00Z])
      assert result == false
    end

    test "if no start time, returns true if time is before end" do
      active_period = %ActivePeriod{end: ~U[2023-10-12 00:01:00Z]}
      result = ActivePeriod.time_inside_active_period?(active_period, ~U[2023-10-11 00:01:00Z])
      assert result == true
    end

    test "if no start time, returns false if time is after end" do
      active_period = %ActivePeriod{end: ~U[2023-10-12 00:01:00Z]}
      result = ActivePeriod.time_inside_active_period?(active_period, ~U[2023-10-13 00:01:00Z])
      assert result == false
    end

    test "if start and end, return true if time is between them" do
      active_period = %ActivePeriod{
        start: ~U[2023-10-10 00:01:00Z],
        end: ~U[2023-10-12 00:01:00Z]
      }

      result = ActivePeriod.time_inside_active_period?(active_period, ~U[2023-10-11 00:01:00Z])
      assert result == true
    end

    test "if start and end, returns false if time is before start" do
      active_period = %ActivePeriod{
        start: ~U[2023-10-10 00:01:00Z],
        end: ~U[2023-10-12 00:01:00Z]
      }

      result = ActivePeriod.time_inside_active_period?(active_period, ~U[2023-10-09 00:01:00Z])
      assert result == false
    end

    test "if start and end, returns false if time is after end" do
      active_period = %ActivePeriod{
        start: ~U[2023-10-10 00:01:00Z],
        end: ~U[2023-10-12 00:01:00Z]
      }

      result = ActivePeriod.time_inside_active_period?(active_period, ~U[2023-10-13 00:01:00Z])
      assert result == false
    end
  end

  describe "start_time_of_first_active_period/1" do
    test "gives earliest start out of active periods" do
      active_periods = [
        %ActivePeriod{
          start: ~U[2023-10-10 00:01:00Z],
          end: ~U[2023-10-18 00:01:00Z]
        },
        %ActivePeriod{
          start: ~U[2023-10-09 00:01:00Z],
          end: ~U[2023-10-19 00:01:00Z]
        },
        %ActivePeriod{
          start: ~U[2023-10-11 00:01:00Z],
          end: ~U[2023-10-20 00:01:00Z]
        },
        %ActivePeriod{
          start: nil,
          end: ~U[2023-10-20 00:01:00Z]
        }
      ]

      result = ActivePeriod.start_time_of_first_active_period(active_periods)
      assert result == ~U[2023-10-09 00:01:00Z]
    end

    test "returns nil if no start times" do
      active_periods = [
        %ActivePeriod{
          end: ~U[2023-10-11 00:01:00Z],
          start: nil
        },
        %ActivePeriod{
          end: ~U[2023-10-10 00:01:00Z],
          start: nil
        },
        %ActivePeriod{
          end: ~U[2023-10-09 00:01:00Z],
          start: nil
        }
      ]

      result = ActivePeriod.start_time_of_first_active_period(active_periods)
      assert result == nil
    end
  end

  describe "end_time_of_last_active_period/1" do
    test "gives last end out of active periods" do
      active_periods = [
        %ActivePeriod{
          start: ~U[2023-10-11 00:01:00Z],
          end: ~U[2023-10-20 00:01:00Z]
        },
        %ActivePeriod{
          start: ~U[2023-10-10 00:01:00Z],
          end: ~U[2023-10-18 00:01:00Z]
        },
        %ActivePeriod{
          start: ~U[2023-10-09 00:01:00Z],
          end: ~U[2023-10-19 00:01:00Z]
        },
        %ActivePeriod{
          start: ~U[2023-10-09 00:01:00Z],
          end: nil
        }
      ]

      result = ActivePeriod.end_time_of_last_active_period(active_periods)
      assert result == ~U[2023-10-20 00:01:00Z]
    end

    test "returns nil if no end times" do
      active_periods = [
        %ActivePeriod{
          start: ~U[2023-10-11 00:01:00Z],
          end: nil
        },
        %ActivePeriod{
          start: ~U[2023-10-10 00:01:00Z],
          end: nil
        },
        %ActivePeriod{
          start: ~U[2023-10-09 00:01:00Z],
          end: nil
        }
      ]

      result = ActivePeriod.end_time_of_last_active_period(active_periods)
      assert result == nil
    end
  end

  describe "end_of_service_date/1" do
    test "adds 1 to date if time is after service start" do
      start_time = DateTime.new!(~D[2023-10-10], ~T[13:00:00], "America/New_York")
      assert ~D[2023-10-11] = ActivePeriod.end_of_service_date(start_time)
    end

    test "returns same date if time is before service start" do
      start_time = DateTime.new!(~D[2023-10-10], ~T[02:00:00], "America/New_York")
      assert ~D[2023-10-10] = ActivePeriod.end_of_service_date(start_time)
    end

    test "works with naive date time" do
      start_time = NaiveDateTime.new!(~D[2023-10-10], ~T[01:00:00])
      assert ~D[2023-10-10] = ActivePeriod.end_of_service_date(start_time)
    end
  end

  describe "end_of_service_datetime_naive/1" do
    test "adds 1 to date if time is after service start" do
      start_time = NaiveDateTime.new!(~D[2023-10-10], ~T[04:00:00])
      assert ~N[2023-10-11 03:00:00Z] = ActivePeriod.end_of_service_datetime_naive(start_time)
    end

    test "returns same date if time is before service start" do
      start_time = NaiveDateTime.new!(~D[2023-10-10], ~T[02:00:00])
      assert ~N[2023-10-10 03:00:00Z] = ActivePeriod.end_of_service_datetime_naive(start_time)
    end
  end

  describe "end_of_service_datetime_utc/1" do
    test "adds 1 to date if time is after service start" do
      start_time = DateTime.new!(~D[2023-10-10], ~T[04:00:00], "America/New_York")
      assert ~U[2023-10-11 07:00:00Z] = ActivePeriod.end_of_service_datetime_utc(start_time)
    end

    test "returns same date if time is before service start" do
      start_time = DateTime.new!(~D[2023-10-10], ~T[02:00:00], "America/New_York")
      assert ~U[2023-10-10 07:00:00Z] = ActivePeriod.end_of_service_datetime_utc(start_time)
    end
  end

  describe "next_start_of_service_datetime/1" do
    test "adds 1 to date if time is after service start" do
      start_time = DateTime.new!(~D[2023-10-10], ~T[13:00:00], "America/New_York")
      assert ~U[2023-10-11 03:00:00Z] = ActivePeriod.next_start_of_service_datetime(start_time)
    end

    test "returns same date if time is before service start" do
      start_time = DateTime.new!(~D[2023-10-10], ~T[02:00:00], "America/New_York")
      assert ~U[2023-10-10 03:00:00Z] = ActivePeriod.next_start_of_service_datetime(start_time)
    end
  end
end
