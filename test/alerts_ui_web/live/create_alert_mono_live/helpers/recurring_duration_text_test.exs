defmodule AlertsUIWeb.CreateAlertLive.Helpers.RecurringDurationTextTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import Phoenix.LiveViewTest
  alias AlertsUIWeb.CreateAlertLive.Helpers.RecurringDurationText

  describe("recurring_duration_text/1") do
    test "manages with nil data" do
      params = %{}

      expected =
        " –   every  from  until "

      actual =
        render_component(&RecurringDurationText.recurring_duration_text/1,
          form: %{params: params}
        )

      assert expected =~ actual
    end

    test "manages with incomplete data" do
      params = %{
        "active_period_start_time" => "",
        "active_period_end_time" => "",
        "active_period_start_date" => "",
        "active_period_end_date" => "",
        "recurrence_days" => []
      }

      expected =
        " –   every  from  until "

      actual =
        render_component(&RecurringDurationText.recurring_duration_text/1,
          form: %{params: params}
        )

      assert expected =~ actual
    end

    test "with end date and no +1" do
      params = %{
        "active_period_start_time" => ~T[07:35:00],
        "active_period_end_time" => ~T[21:45:00],
        "active_period_start_date" => ~D[2024-11-25],
        "active_period_end_date" => ~D[2025-01-01],
        "recurrence_days" => ["wednesday"]
      }

      expected =
        "7:35 AM – 9:45 PM (14 hours, 10 minutes) every Wednesday from Mon Nov 25, 2024 until Wed Jan 01, 2025"

      actual =
        render_component(&RecurringDurationText.recurring_duration_text/1,
          form: %{params: params}
        )

      assert expected =~ actual
    end

    test "with end date and equal start and end time" do
      params = %{
        "active_period_start_time" => ~T[07:35:00],
        "active_period_end_time" => ~T[07:35:00],
        "active_period_start_date" => ~D[2024-11-26],
        "active_period_end_date" => ~D[2025-01-02],
        "recurrence_days" => ["tuesday", "thursday"]
      }

      expected =
        "7:35 AM – 7:35 AM<sup>+1</sup> (1 day) every Tuesday and Thursday from Tue Nov 26, 2024 until Thu Jan 02, 2025"

      actual =
        render_component(&RecurringDurationText.recurring_duration_text/1,
          form: %{params: params}
        )

      assert expected == actual
    end

    test "with end date and midnight between start and end" do
      params = %{
        "active_period_start_time" => ~T[09:45:00],
        "active_period_end_time" => ~T[07:35:00],
        "active_period_start_date" => ~D[2024-11-26],
        "active_period_end_date" => ~D[2025-01-02],
        "recurrence_days" => ["tuesday", "wednesday", "thursday"]
      }

      expected =
        "9:45 AM – 7:35 AM<sup>+1</sup> (21 hours, 50 minutes) every Tuesday, Wednesday, and Thursday from Tue Nov 26, 2024 until Thu Jan 02, 2025"

      actual =
        render_component(&RecurringDurationText.recurring_duration_text/1,
          form: %{params: params}
        )

      assert expected == actual
    end

    test "with no end date" do
      params = %{
        "active_period_start_time" => ~T[11:45:00],
        "active_period_end_time" => ~T[03:45:00],
        "active_period_start_date" => ~D[2024-11-26],
        "active_period_end_date" => nil,
        "active_period_end_specifier" => "until_further_notice",
        "recurrence_days" => [
          "sunday",
          "monday",
          "tuesday",
          "wednesday",
          "thursday",
          "friday",
          "saturday"
        ]
      }

      expected =
        "11:45 AM – 3:45 AM<sup>+1</sup> (16 hours) every day from Tue Nov 26, 2024 until alert is manually closed"

      actual =
        render_component(&RecurringDurationText.recurring_duration_text/1,
          form: %{params: params}
        )

      assert expected == actual
    end
  end
end
