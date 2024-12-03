defmodule AlertsUIWeb.FormComponents.Helpers.TimeRangeDurationTextTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUIWeb.FormComponents.Helpers.TimeRangeDurationText

  describe "one_time_duration_text/1" do
    test "custom start and end" do
      params = %{
        "active_period_start_specifier" => "custom",
        "active_period_start" => ~N[2024-11-27 09:00:00],
        "active_period_end_specifier" => "custom",
        "active_period_end" => ~N[2024-11-27 15:00:00]
      }

      expected = "Wed Nov 27, 2024 @ 9:00 AM until Wed Nov 27, 2024 @ 3:00 PM (6 hours)"
      actual = TimeRangeDurationText.one_time_duration_text(params)
      assert expected == actual
    end

    test "start of now" do
      params = %{
        "active_period_start_specifier" => "now",
        "active_period_start" => ~N[2024-11-27 09:30:00],
        "active_period_end_specifier" => "custom",
        "active_period_end" => ~N[2024-11-27 21:00:00]
      }

      expected = "Now until Wed Nov 27, 2024 @ 9:00 PM (11 hours, 30 minutes)"
      actual = TimeRangeDurationText.one_time_duration_text(params)
      assert expected == actual
    end

    test "start of start_of_service" do
      params = %{
        "active_period_start_specifier" => "start_of_service",
        "active_period_start" => ~N[2024-11-27 03:00:00],
        "active_period_end_specifier" => "custom",
        "active_period_end" => ~N[2024-11-28 03:00:00]
      }

      expected = "Wed Nov 27, 2024 @ 3:00 AM until Thu Nov 28, 2024 @ 3:00 AM (1 day)"
      actual = TimeRangeDurationText.one_time_duration_text(params)
      assert expected == actual
    end

    test "end of later_today" do
      params = %{
        "active_period_start_specifier" => "custom",
        "active_period_start" => ~N[2024-11-27 09:00:00],
        "active_period_end_specifier" => "later_today",
        "active_period_end" => ~N[2024-11-28 03:00:00]
      }

      expected = "Wed Nov 27, 2024 @ 9:00 AM until later today (max 18 hours)"
      actual = TimeRangeDurationText.one_time_duration_text(params)
      assert expected == actual
    end

    test "end of end_of_service" do
      params = %{
        "active_period_start_specifier" => "start_of_service",
        "active_period_start" => ~N[2024-11-28 01:00:01],
        "active_period_end_specifier" => "end_of_service",
        "active_period_end" => ~N[2024-11-27 03:00:03]
      }

      expected = "Thu Nov 28, 2024 @ 1:00 AM until Thu Nov 28, 2024 @ 3:00 AM (2 hours)"
      actual = TimeRangeDurationText.one_time_duration_text(params)
      assert expected == actual
    end

    test "end of end_of_service 2" do
      params = %{
        "active_period_start_specifier" => "custom",
        "active_period_start" => ~N[2024-11-28 01:00:00],
        "active_period_end_specifier" => "end_of_service",
        "active_period_end" => ~N[2024-11-27 03:00:00]
      }

      expected = "Thu Nov 28, 2024 @ 1:00 AM until Thu Nov 28, 2024 @ 3:00 AM (2 hours)"
      actual = TimeRangeDurationText.one_time_duration_text(params)
      assert expected == actual
    end

    test "end of until_further_notice" do
      params = %{
        "active_period_start_specifier" => "start_of_service",
        "active_period_start" => ~N[2024-11-27 09:00:00],
        "active_period_end_specifier" => "until_further_notice",
        "active_period_end" => ""
      }

      expected = "Wed Nov 27, 2024 @ 9:00 AM until alert is manually closed (indefinite)"
      actual = TimeRangeDurationText.one_time_duration_text(params)
      assert expected == actual
    end
  end
end
