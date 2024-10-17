defmodule AlertsUI.ActivePeriodBuilderTest do
  @moduledoc false
  use AlertsUI.DataCase

  alias AlertsUI.ActivePeriodBuilder
  alias AlertsUI.Models.ActivePeriod

  @end_of_service_eastern ActivePeriod.end_of_service_time()
  @end_of_service_utc ActivePeriod.end_of_service_time() |> Time.add(4, :hour)

  describe "build_one_time_active_period/2" do
    test "builds active period with end value later_today" do
      alert_data =
        %{
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end: NaiveDateTime.new!(~D[2024-05-01], @end_of_service_eastern),
          active_period_end_specifier: :later_today,
          active_period_start_specifier: :custom
        }

      result =
        ActivePeriodBuilder.build_one_time_active_period(alert_data, ~U[2024-04-30 15:54:00Z])

      assert result.active_period == [
               %{
                 start: ~U[2024-04-30 15:54:00Z],
                 end: DateTime.new!(~D[2024-05-01], @end_of_service_utc)
               }
             ]

      assert result.active_period_start == ~U[2024-04-30 15:54:00Z]
      assert result.active_period_end == DateTime.new!(~D[2024-05-01], @end_of_service_utc)
      assert result.duration_certainty == :ESTIMATED
    end

    test "builds active period with end value further_notice" do
      alert_data =
        %{
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end: nil,
          active_period_end_specifier: :until_further_notice,
          active_period_start_specifier: :custom
        }

      result =
        ActivePeriodBuilder.build_one_time_active_period(alert_data, ~U[2024-04-30 15:54:00Z])

      assert result.active_period == [%{start: ~U[2024-04-30 15:54:00Z], end: nil}]
      assert result.active_period_start == ~U[2024-04-30 15:54:00Z]
      assert result.active_period_end == nil
      assert result.duration_certainty == :UNKNOWN
    end

    test "builds active period with end value pick" do
      alert_data =
        %{
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end: ~N[2024-04-30 23:54:00],
          active_period_end_specifier: :custom,
          active_period_start_specifier: :custom
        }

      result =
        ActivePeriodBuilder.build_one_time_active_period(alert_data, ~U[2024-04-30 15:54:00Z])

      assert result.active_period == [
               %{start: ~U[2024-04-30 15:54:00Z], end: ~U[2024-05-01 03:54:00Z]}
             ]

      assert result.active_period_start == ~U[2024-04-30 15:54:00Z]
      assert result.active_period_end == ~U[2024-05-01 03:54:00Z]
      assert result.duration_certainty == :KNOWN
    end

    test "builds active period with start time of now" do
      original_start_time = ~U[2024-04-30 05:54:00Z] |> DateTime.add(-5, :minute)

      alert_data =
        %{
          active_period_start:
            original_start_time
            |> DateTime.shift_zone!("America/New_York")
            |> DateTime.to_naive(),
          active_period_end: ~N[2024-04-30 23:54:00],
          active_period_end_specifier: :custom,
          active_period_start_specifier: :now
        }

      result =
        ActivePeriodBuilder.build_one_time_active_period(alert_data, ~U[2024-04-30 05:54:00Z])

      assert result.active_period_start == ~U[2024-04-30 05:54:00Z]
    end

    test "builds active period with end value end_of_service_today when time is before midnight" do
      alert_data =
        %{
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end: NaiveDateTime.new!(~D[2024-05-01], @end_of_service_eastern),
          active_period_end_specifier: :end_of_service,
          active_period_start_specifier: :custom
        }

      result =
        ActivePeriodBuilder.build_one_time_active_period(alert_data, ~U[2024-04-30 05:54:00Z])

      assert result.active_period == [
               %{
                 start: ~U[2024-04-30 15:54:00Z],
                 end: DateTime.new!(~D[2024-05-01], @end_of_service_utc)
               }
             ]

      assert result.active_period_start == ~U[2024-04-30 15:54:00Z]
      assert result.active_period_end == DateTime.new!(~D[2024-05-01], @end_of_service_utc)
      assert result.duration_certainty == :KNOWN
    end

    test "builds active period with end value end_of_service_today when time is after midnight" do
      alert_data =
        %{
          active_period_start: ~N[2024-04-30 01:54:00],
          active_period_end: NaiveDateTime.new!(~D[2024-04-30], @end_of_service_eastern),
          active_period_end_specifier: :end_of_service,
          active_period_start_specifier: :custom
        }

      result =
        ActivePeriodBuilder.build_one_time_active_period(alert_data, ~U[2024-04-30 05:54:00Z])

      assert result.active_period == [
               %{
                 start: ~U[2024-04-30 05:54:00Z],
                 end: DateTime.new!(~D[2024-04-30], @end_of_service_utc)
               }
             ]

      assert result.active_period_start == ~U[2024-04-30 05:54:00Z]
      assert result.active_period_end == DateTime.new!(~D[2024-04-30], @end_of_service_utc)
      assert result.duration_certainty == :KNOWN
    end
  end

  describe "build_recurring_active_period/2" do
    test "builds active periods with known end date" do
      alert_data =
        %{
          active_period_start_date: ~D[2024-10-14],
          active_period_end_date: ~D[2024-11-01],
          active_period_start_time: ~T[13:00:00],
          active_period_end_time: ~T[15:30:00],
          active_period_end_specifier: :custom,
          days_of_week: [:monday, :wednesday, :friday]
        }

      result = ActivePeriodBuilder.build_recurring_active_period(alert_data)

      assert result.active_period_start == ~U[2024-10-14 17:00:00Z]
      assert result.active_period_end == ~U[2024-11-01 19:30:00Z]
      assert result.duration_certainty == :KNOWN

      assert result.active_period == [
               %{
                 start: ~U[2024-10-14 17:00:00Z],
                 end: ~U[2024-10-14 19:30:00Z]
               },
               %{
                 start: ~U[2024-10-16 17:00:00Z],
                 end: ~U[2024-10-16 19:30:00Z]
               },
               %{
                 start: ~U[2024-10-18 17:00:00Z],
                 end: ~U[2024-10-18 19:30:00Z]
               },
               %{
                 start: ~U[2024-10-21 17:00:00Z],
                 end: ~U[2024-10-21 19:30:00Z]
               },
               %{
                 start: ~U[2024-10-23 17:00:00Z],
                 end: ~U[2024-10-23 19:30:00Z]
               },
               %{
                 start: ~U[2024-10-25 17:00:00Z],
                 end: ~U[2024-10-25 19:30:00Z]
               },
               %{
                 start: ~U[2024-10-28 17:00:00Z],
                 end: ~U[2024-10-28 19:30:00Z]
               },
               %{
                 start: ~U[2024-10-30 17:00:00Z],
                 end: ~U[2024-10-30 19:30:00Z]
               },
               %{
                 start: ~U[2024-11-01 17:00:00Z],
                 end: ~U[2024-11-01 19:30:00Z]
               }
             ]
    end

    test "builds active periods when end is next day" do
      alert_data =
        %{
          active_period_start_date: ~D[2024-10-15],
          active_period_end_date: ~D[2024-10-24],
          active_period_start_time: ~T[09:00:00],
          active_period_end_time: ~T[02:30:00],
          active_period_end_specifier: :custom,
          days_of_week: [:tuesday, :thursday]
        }

      result = ActivePeriodBuilder.build_recurring_active_period(alert_data)

      assert result.active_period_start == ~U[2024-10-15 13:00:00Z]
      assert result.active_period_end == ~U[2024-10-25 06:30:00Z]
      assert result.duration_certainty == :KNOWN

      assert result.active_period == [
               %{start: ~U[2024-10-15 13:00:00Z], end: ~U[2024-10-16 06:30:00Z]},
               %{start: ~U[2024-10-17 13:00:00Z], end: ~U[2024-10-18 06:30:00Z]},
               %{start: ~U[2024-10-22 13:00:00Z], end: ~U[2024-10-23 06:30:00Z]},
               %{start: ~U[2024-10-24 13:00:00Z], end: ~U[2024-10-25 06:30:00Z]}
             ]
    end

    test "builds active periods with no set end date" do
      alert_data =
        %{
          active_period_start_date: ~D[2024-10-12],
          active_period_end_date: nil,
          active_period_start_time: ~T[09:00:00],
          active_period_end_time: ~T[10:30:00],
          active_period_end_specifier: :until_further_notice,
          days_of_week: [:saturday]
        }

      result = ActivePeriodBuilder.build_recurring_active_period(alert_data)

      assert result.active_period_start == ~U[2024-10-12 13:00:00Z]
      assert result.active_period_end == nil
      assert (result.active_period |> Enum.reverse() |> hd).end == ~U[2025-10-11 14:30:00Z]
      assert length(result.active_period) == 53
      assert result.duration_certainty == :UNKNOWN
    end
  end
end
