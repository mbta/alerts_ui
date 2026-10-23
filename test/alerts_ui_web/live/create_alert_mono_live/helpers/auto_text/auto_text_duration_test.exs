defmodule AlertsUIWeb.CreateAlertLive.Helpers.AutoText.BuildAutoTextDurationTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUI.Models.ActivePeriod
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.CreateAlertLive.Helpers.AutoText.AutoTextDuration
  alias AlertsUIWeb.CreateAlertLive.Helpers.AutoText.BuildAutoText
  alias AlertsUIWeb.FormComponents.Helpers.DateTimeHelpers

  @schedule_1 %EnhancedSchedule{
    departure_time: ~U[2024-02-21 14:01:00.00Z]
  }

  describe "build_duration_text/1" do
    test "trip specific when alert fits no other criteria" do
      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        route_type: 4,
        effect_name: "Delay"
      }

      expected = ""
      actual = AutoTextDuration.build_duration_text(auto_text_data)
      assert expected == actual
    end

    test "trip specific starts in future end different day" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        route_type: 4,
        effect_name: "Delay",
        schedules: [@schedule_1],
        start_datetime: ~N[2025-05-09 13:00:00],
        end_datetime: ~N[2025-05-10 13:00:00]
      }

      expected = "from Fri, May 9 through Sat, May 10"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "trip specific starts in future end same day" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        route_type: 4,
        effect_name: "Delay",
        schedules: [@schedule_1],
        start_datetime: ~N[2025-05-09 13:00:00],
        end_datetime: ~N[2025-05-09 15:00:00]
      }

      expected = "on Fri, May 9"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "trip specific starts today end different day" do
      current_time = ~N[2025-05-09 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        route_type: 4,
        effect_name: "Delay",
        schedules: [@schedule_1],
        start_datetime: ~N[2025-05-09 13:00:00],
        end_datetime: ~N[2025-05-10 13:00:00]
      }

      expected = "today through Sat, May 10"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "trip specific starts in past end different day" do
      current_time = ~N[2025-05-09 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        route_type: 4,
        effect_name: "Delay",
        schedules: [@schedule_1],
        start_datetime: ~N[2025-05-07 13:00:00],
        end_datetime: ~N[2025-05-10 13:00:00]
      }

      expected = "today through Sat, May 10"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "no trip specific starts today end same day" do
      current_time = ~N[2025-05-09 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        route_type: 2,
        effect_name: "Track Change",
        schedules: [],
        end_specifier: :custom,
        start_datetime: ~N[2025-05-09 13:00:00],
        end_datetime: ~N[2025-05-09 15:04:00]
      }

      expected = "until 3:04 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "trip specific starts today end same day" do
      current_time = ~N[2025-05-09 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        route_type: 2,
        effect_name: "Track Change",
        schedules: [@schedule_1],
        end_specifier: :custom,
        start_datetime: ~N[2025-05-09 13:00:00],
        end_datetime: ~N[2025-05-09 15:04:00]
      }

      expected = "today"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "another trip specific starts today end same day" do
      current_time = ~N[2025-05-09 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        route_type: 4,
        effect_name: "Delay",
        schedules: [@schedule_1],
        start_datetime: ~N[2025-05-09 13:00:00],
        end_datetime: ~N[2025-05-09 15:00:00]
      }

      expected = "today"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "trip specific starts in past ends today" do
      current_time = ~N[2025-05-09 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        route_type: 4,
        effect_name: "Delay",
        schedules: [@schedule_1],
        start_datetime: ~N[2025-05-07 13:00:00],
        end_datetime: ~N[2025-05-09 15:00:00]
      }

      expected = "today"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is now and end is later today" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :later_today,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-08 13:00:00]
      }

      expected = ""
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is now and end is further notice" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :further_notice,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: nil
      }

      expected = ""
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is now and end is end of service today" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected = "today"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "end is set as custom but is actually end of service" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected = "today"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is now and end is custom today" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-08 15:00:00]
      }

      expected = "until 3:00 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is now and end is end of service after today" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 03:00:00]
      }

      expected = "through Fri, May 9"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is now and end is custom after today" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 13:00:00],
        end_datetime: ~N[2025-05-10 15:00:00]
      }

      expected = "until Sat, May 10 at 3:00 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom in past and end is end of service in future" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-07 14:00:00],
        end_datetime: ~N[2025-05-10 03:00:00]
      }

      expected = "through Fri, May 9"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom in past and end is custom a different day" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-07 14:00:00],
        end_datetime: ~N[2025-05-09 13:00:00]
      }

      expected = "until Fri, May 9 at 1:00 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom in past and end is custom today" do
      current_time = ~N[2025-05-09 12:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-07 14:00:00],
        end_datetime: ~N[2025-05-09 13:00:00]
      }

      expected = "until 1:00 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom on previous day and end is end of service today" do
      current_time = ~N[2025-05-13 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-10 13:00:00],
        end_datetime: NaiveDateTime.new!(~D[2025-05-14], ActivePeriod.end_of_service_time())
      }

      expected = "today"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom today and end is later today" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :later_today,
        start_datetime: ~N[2025-05-08 14:00:00],
        end_datetime: ~N[2025-05-08 16:00:00]
      }

      expected = "beginning at 2:00 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom today and end is further notice" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :further_notice,
        start_datetime: ~N[2025-05-08 14:00:00],
        end_datetime: nil
      }

      expected = "beginning at 2:00 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom today and end is end of service same day" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 14:00:00],
        end_datetime: ~N[2025-05-09 03:00:00]
      }

      expected = "from 2:00 PM to end of service"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom today and end is end of service a different day" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-08 14:00:00],
        end_datetime: ~N[2025-05-10 03:00:00]
      }

      expected = "from 2:00 PM today through Fri, May 9"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom today and end is custom today" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 14:00:00],
        end_datetime: ~N[2025-05-08 16:00:00]
      }

      expected = "from 2:00 PM to 4:00 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom today and end is custom a different day" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-08 14:00:00],
        end_datetime: ~N[2025-05-10 16:00:00]
      }

      expected = "from 2:00 PM today to Sat, May 10 at 4:00 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is start of service on previous day and end is custom not today" do
      current_time = ~N[2025-05-12 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :start_of_service,
        end_specifier: :custom,
        start_datetime: NaiveDateTime.new!(~D[2025-05-10], ActivePeriod.start_of_service_time()),
        end_datetime: ~N[2025-05-13 13:00:00]
      }

      expected = "until Tue, May 13 at 1:00 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is start of service on previous day and end is custom today" do
      current_time = ~N[2025-05-13 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :start_of_service,
        end_specifier: :custom,
        start_datetime: NaiveDateTime.new!(~D[2025-05-10], ActivePeriod.start_of_service_time()),
        end_datetime: ~N[2025-05-13 14:00:00]
      }

      expected = "until 2:00 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is start of service on previous day and end is end of service today" do
      current_time = ~N[2025-05-13 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :start_of_service,
        end_specifier: :end_of_service,
        start_datetime: NaiveDateTime.new!(~D[2025-05-10], ActivePeriod.start_of_service_time()),
        end_datetime: NaiveDateTime.new!(~D[2025-05-14], ActivePeriod.end_of_service_time())
      }

      expected = "today"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is start of service on previous day and end is end of service in future" do
      current_time = ~N[2025-05-13 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :start_of_service,
        end_specifier: :end_of_service,
        start_datetime: NaiveDateTime.new!(~D[2025-05-10], ActivePeriod.start_of_service_time()),
        end_datetime: NaiveDateTime.new!(~D[2025-05-15], ActivePeriod.end_of_service_time())
      }

      expected = "through Wed, May 14"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is start of service in future and end is until further notice" do
      current_time = ~N[2025-05-12 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :start_of_service,
        end_specifier: :until_further_notice,
        start_datetime: NaiveDateTime.new!(~D[2025-05-14], ActivePeriod.start_of_service_time()),
        end_datetime: nil
      }

      expected = "beginning Wed, May 14"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is set as custom time but is actually start of service" do
      current_time = ~N[2025-05-12 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :until_further_notice,
        start_datetime: NaiveDateTime.new!(~D[2025-05-14], ActivePeriod.start_of_service_time()),
        end_datetime: nil
      }

      expected = "beginning Wed, May 14"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom in future and end is until further notice" do
      current_time = ~N[2025-05-12 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :until_further_notice,
        start_datetime: ~N[2025-05-14 02:59:00],
        end_datetime: nil
      }

      expected = "beginning Wed, May 14 at 2:59 AM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom in future and end is after midnight same service day" do
      current_time = ~N[2025-05-12 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-14 13:00:00],
        end_datetime: ~N[2025-05-15 01:00:00]
      }

      expected = "from Wed, May 14 at 1:00 PM to Thu, May 15 at 1:00 AM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is start of service in future and end is end of service a different day" do
      current_time = ~N[2025-05-12 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :start_of_service,
        end_specifier: :end_of_service,
        start_datetime: NaiveDateTime.new!(~D[2025-05-14], ActivePeriod.start_of_service_time()),
        end_datetime: NaiveDateTime.new!(~D[2025-05-16], ActivePeriod.end_of_service_time())
      }

      expected = "from Wed, May 14 through Thu, May 15"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is start of service in future and end is end of service a different day and it's the weekend baby" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :start_of_service,
        end_specifier: :end_of_service,
        start_datetime: NaiveDateTime.new!(~D[2025-05-10], ActivePeriod.start_of_service_time()),
        end_datetime: NaiveDateTime.new!(~D[2025-05-12], ActivePeriod.end_of_service_time())
      }

      expected = "the weekend of Sat, May 10 and Sun, May 11"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "it's the weekend baby but our start and end datetimes are nil for some reason" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :start_of_service,
        end_specifier: :end_of_service,
        start_datetime: nil,
        end_datetime: nil
      }

      expected = "from  through "
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom in future and end is custom a different day" do
      current_time = ~N[2025-05-12 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-13 13:00:00],
        end_datetime: ~N[2025-05-14 15:00:00]
      }

      expected = "from Tue, May 13 at 1:00 PM to Wed, May 14 at 3:00 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is start of service in future and end is start of service a different day" do
      current_time = ~N[2025-05-12 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-13 13:00:00],
        end_datetime: ~N[2025-05-14 15:00:00]
      }

      expected = "from Tue, May 13 at 1:00 PM to Wed, May 14 at 3:00 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is start of service in future and end is custom different day" do
      current_time = ~N[2025-05-11 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :start_of_service,
        end_specifier: :custom,
        start_datetime: NaiveDateTime.new!(~D[2025-05-13], ActivePeriod.start_of_service_time()),
        end_datetime: ~N[2025-05-14 15:00:00]
      }

      expected = "from Tue, May 13 to Wed, May 14 at 3:00 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom in future and end is end of service a different day" do
      current_time = ~N[2025-05-11 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-13 15:00:00],
        end_datetime: NaiveDateTime.new!(~D[2025-05-15], ActivePeriod.start_of_service_time())
      }

      expected = "from Tue, May 13 at 3:00 PM through Wed, May 14"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom in future and end is custom the same day" do
      current_time = ~N[2025-05-11 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-13 13:00:00],
        end_datetime: ~N[2025-05-13 15:00:00]
      }

      expected = "from 1:00 PM to 3:00 PM on Tue, May 13"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is start of service in future and end is end of service the same day" do
      current_time = ~N[2025-05-11 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :start_of_service,
        end_specifier: :end_of_service,
        start_datetime: NaiveDateTime.new!(~D[2025-05-13], ActivePeriod.start_of_service_time()),
        end_datetime: NaiveDateTime.new!(~D[2025-05-14], ActivePeriod.end_of_service_time())
      }

      expected = "on Tue, May 13"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is custom in future and end is end of service the same day" do
      current_time = ~N[2025-05-11 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :end_of_service,
        start_datetime: ~N[2025-05-13 15:00:00],
        end_datetime: NaiveDateTime.new!(~D[2025-05-14], ActivePeriod.end_of_service_time())
      }

      expected = "on Tue, May 13 starting at 3:00 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "start is start of service in future and end is custom the same day" do
      current_time = ~N[2025-05-11 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :start_of_service,
        end_specifier: :custom,
        start_datetime: NaiveDateTime.new!(~D[2025-05-13], ActivePeriod.start_of_service_time()),
        end_datetime: ~N[2025-05-13 15:00:00]
      }

      expected = "on Tue, May 13 until 3:00 PM"
      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)
      assert expected == actual
    end

    test "recurring- when start and end are nil" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :recurring,
        start_time_specifier: :custom,
        end_time_specifier: :custom,
        start_date: nil,
        end_date: nil,
        start_time: nil,
        end_time: nil,
        recurrence_days: []
      }

      expected =
        " every  "

      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)

      assert expected == actual
    end

    test "recurring- when start and end are same day" do
      current_time = ~N[2025-05-07 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :recurring,
        route_type: 4,
        effect_name: "Delay",
        schedules: [@schedule_1],
        start_time_specifier: :custom,
        end_time_specifier: :custom,
        start_date: ~D[2025-05-09],
        end_date: ~D[2025-05-09],
        start_time: ~T[12:00:00],
        end_time: ~T[15:00:00],
        recurrence_days: [:friday]
      }

      expected =
        "on Fri, May 9"

      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)

      assert expected == actual
    end

    test "recurring- when start is in past and end today" do
      current_time = ~N[2025-05-07 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :recurring,
        route_type: 4,
        effect_name: "Delay",
        schedules: [@schedule_1],
        start_time_specifier: :custom,
        end_time_specifier: :custom,
        start_date: ~D[2025-05-05],
        end_date: ~D[2025-05-07],
        start_time: ~T[12:00:00],
        end_time: ~T[15:00:00],
        recurrence_days: [:friday]
      }

      expected = "today"

      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)

      assert expected == actual
    end

    test "recurring- when start is not today" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :recurring,
        start_time_specifier: :custom,
        end_time_specifier: :custom,
        start_date: ~D[2025-05-09],
        end_date: ~D[2025-05-29],
        start_time: ~T[12:00:00],
        end_time: ~T[15:00:00],
        recurrence_days: [:monday, :tuesday, :wednesday]
      }

      expected =
        "from Fri, May 9 to Thu, May 29 every Monday, Tuesday, and Wednesday from 12:00 PM to 3:00 PM"

      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)

      assert expected == actual
    end

    test "recurring- when start is today" do
      current_time = ~N[2025-05-08 13:00:00]

      auto_text_data = %BuildAutoText{
        alert_timing: :recurring,
        start_time_specifier: :custom,
        end_time_specifier: :custom,
        start_date: ~D[2025-05-09],
        end_date: ~D[2025-05-29],
        start_time: ~T[02:00:00],
        end_time: ~T[11:00:00],
        recurrence_days: [:wednesday, :thursday, :saturday]
      }

      expected =
        "until Thu, May 29 every Wednesday, Thursday, and Saturday from 2:00 AM to 11:00 AM"

      actual = AutoTextDuration.build_duration_text(auto_text_data, current_time)

      assert expected == actual
    end
  end

  describe "starts_today?/1" do
    test "if start time is nil returns false" do
      assert AutoTextDuration.starts_today?(nil, ~N[2025-05-08 13:00:00]) == false
    end

    test "if start time is today before midnight return true" do
      current_time = ~N[2025-05-08 13:00:00]
      start_datetime = ~N[2025-05-08 23:00:00]
      expected = true
      actual = AutoTextDuration.starts_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "if start time is after midnight but before end of service return true" do
      current_time = ~N[2025-05-08 13:00:00]
      start_datetime = ~N[2025-05-09 01:00:00]
      expected = true
      actual = AutoTextDuration.starts_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "if start time is at start of service return true" do
      current_time = ~N[2025-05-08 13:00:00]
      start_datetime = ~N[2025-05-08 03:00:00]
      expected = true
      actual = AutoTextDuration.starts_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "if start time is at end of service return false" do
      current_time = ~N[2025-05-08 13:00:00]
      start_datetime = ~N[2025-05-09 03:00:00]
      expected = false
      actual = AutoTextDuration.starts_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "if both times are after midnight but before EOS return true" do
      current_time = ~N[2025-05-09 01:00:00]
      start_datetime = ~N[2025-05-09 02:00:00]
      expected = true
      actual = AutoTextDuration.starts_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "if start time is next day after end of service return false" do
      current_time = ~N[2025-05-08 13:00:00]
      start_datetime = ~N[2025-05-09 05:00:00]
      expected = false
      actual = AutoTextDuration.starts_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "if both times are after midnight but start is after EOS return false" do
      current_time = ~N[2025-05-09 01:00:00]
      start_datetime = ~N[2025-05-09 05:00:00]
      expected = false
      actual = AutoTextDuration.starts_today?(start_datetime, current_time)
      assert expected == actual
    end
  end

  describe "ends_today?/1" do
    test "if start time is nil returns false" do
      assert AutoTextDuration.ends_today?(nil, ~N[2025-05-08 13:00:00]) == false
    end

    test "if start time is today before midnight return true" do
      current_time = ~N[2025-05-08 13:00:00]
      start_datetime = ~N[2025-05-08 23:00:00]
      expected = true
      actual = AutoTextDuration.ends_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "if start time is at start of service return false" do
      current_time = ~N[2025-05-08 13:00:00]
      start_datetime = ~N[2025-05-08 03:00:00]
      expected = false
      actual = AutoTextDuration.ends_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "if start time is at end of service return true" do
      current_time = ~N[2025-05-08 13:00:00]
      start_datetime = ~N[2025-05-09 03:00:00]
      expected = true
      actual = AutoTextDuration.ends_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "if start time is next day after end of service return false" do
      current_time = ~N[2025-05-08 13:00:00]
      start_datetime = ~N[2025-05-09 05:00:00]
      expected = false
      actual = AutoTextDuration.ends_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "if both times are after midnight but start is after EOS return false" do
      current_time = ~N[2025-05-09 01:00:00]
      start_datetime = ~N[2025-05-09 05:00:00]
      expected = false
      actual = AutoTextDuration.ends_today?(start_datetime, current_time)
      assert expected == actual
    end
  end

  describe "starts_before_today?/2" do
    test "start is same service day as now" do
      current_time = ~N[2025-05-09 01:00:00]
      start_datetime = ~N[2025-05-08 04:00:00]
      expected = false
      actual = AutoTextDuration.starts_before_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "start is previous service day" do
      current_time = ~N[2025-05-09 01:00:00]
      start_datetime = ~N[2025-05-08 02:00:00]
      expected = true
      actual = AutoTextDuration.starts_before_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "start is tomorrow" do
      current_time = ~N[2025-05-09 01:00:00]
      start_datetime = ~N[2025-05-09 02:00:00]
      expected = false
      actual = AutoTextDuration.starts_before_today?(start_datetime, current_time)
      assert expected == actual
    end
  end

  describe "build_date_string/3" do
    test "no start time returns empty string" do
      assert AutoTextDuration.build_date_string(%{
               start_datetime: nil
             }) == ""
    end

    test "trip specific not today no end date" do
      expected = "starting Sun, May 18"

      actual =
        AutoTextDuration.build_date_string(%{
          start_datetime: ~N[2025-05-18 15:00:00],
          end_datetime: nil,
          starts_today_or_earlier?: false,
          is_trip_combination?: true
        })

      assert expected == actual
    end

    test "trip specific today with no end date" do
      expected = "until further notice"

      actual =
        AutoTextDuration.build_date_string(%{
          start_datetime: ~N[2025-05-18 15:00:00],
          end_datetime: nil,
          starts_today_or_earlier?: true,
          is_trip_combination?: true
        })

      assert expected == actual
    end

    test "starts today but no end datetime" do
      expected = "until further notice"

      actual =
        assert AutoTextDuration.build_date_string(%{
                 start_datetime: ~N[2025-05-18 15:00:00],
                 end_datetime: nil,
                 starts_today_or_earlier?: true
               })

      assert expected == actual
    end

    test "start in future but no end datetime" do
      expected = "starting Fri, May 9 until further notice"

      actual =
        AutoTextDuration.build_date_string(%{
          start_datetime: ~N[2025-05-09 15:00:00],
          end_datetime: nil,
          starts_today_or_earlier?: false
        })

      assert expected == actual
    end

    test "starts today and has end datetime" do
      expected = "until Sun, May 18"

      actual =
        assert AutoTextDuration.build_date_string(%{
                 start_datetime: ~N[2025-05-08 15:00:00],
                 end_datetime: ~N[2025-05-18 16:00:00],
                 starts_today_or_earlier?: true
               })

      assert expected == actual
    end

    test "starts in future and has end datetime" do
      expected = "from Fri, May 9 to Sun, May 18"

      actual =
        assert AutoTextDuration.build_date_string(%{
                 start_datetime: ~N[2025-05-09 15:00:00],
                 end_datetime: ~N[2025-05-18 16:00:00],
                 starts_today_or_earlier?: false
               })

      assert expected == actual
    end
  end

  describe "build_weekday_string/1" do
    test "if no recurrence days" do
      assert AutoTextDuration.build_weekday_string([]) == ""
    end

    test "if one recurrence days" do
      actual = "Monday"
      expected = AutoTextDuration.build_weekday_string([:monday])
      assert expected == actual
    end

    test "if two recurrence days" do
      actual = "Monday and Tuesday"
      expected = AutoTextDuration.build_weekday_string([:monday, :tuesday])
      assert expected == actual
    end

    test "if more than two recurrence days" do
      actual = "Monday, Tuesday, and Friday"
      expected = AutoTextDuration.build_weekday_string([:monday, :tuesday, :friday])
      assert expected == actual
    end

    test "if seven recurrence days" do
      actual = "day"

      expected =
        AutoTextDuration.build_weekday_string([
          :sunday,
          :monday,
          :tuesday,
          :wednesday,
          :thursday,
          :friday,
          :saturday
        ])

      assert expected == actual
    end
  end

  describe "build_duration_text/1 with injected current_time" do
    test "uses current_time from struct instead of re-capturing system time" do
      # A past date: with this as current_time, start_dt appears "today" (same service day)
      pinned_time = ~N[2020-01-15 10:00:00]
      start_dt = ~N[2020-01-15 08:00:00]

      autotext = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :later_today,
        start_datetime: start_dt,
        end_datetime: ~N[2020-01-15 23:00:00],
        route_type: 1,
        effect_name: "DETOUR",
        current_time: pinned_time
      }

      # With pinned 2020 time: start_dt is "today" relative to that time
      result_with_pinned_time = AutoTextDuration.build_duration_text(autotext, pinned_time)
      # With live time (today ~2026): start_dt is in the past, so different branch fires
      result_with_live_time =
        AutoTextDuration.build_duration_text(autotext, DateTimeHelpers.current_time())

      # Confirm the scenario is meaningful: pinned vs live produce different text
      refute result_with_pinned_time == result_with_live_time

      # The 1-arg form should use struct's current_time (not live time)
      # After the H2 fix this should equal result_with_pinned_time
      # Before the fix it uses DateTimeHelpers.current_time() → equals result_with_live_time → FAILS
      assert AutoTextDuration.build_duration_text(autotext) == result_with_pinned_time
    end

    test "falls back to DateTimeHelpers.current_time() when struct has no current_time" do
      autotext = %BuildAutoText{
        alert_timing: :"one-time",
        start_specifier: :custom,
        end_specifier: :later_today,
        start_datetime: ~N[2025-06-03 08:00:00],
        end_datetime: ~N[2025-06-04 02:30:00],
        route_type: 1,
        effect_name: "DETOUR"
        # current_time intentionally absent (nil)
      }

      # Should not crash; should produce a string
      assert is_binary(AutoTextDuration.build_duration_text(autotext))
    end
  end

  describe "build_time_text/4" do
    test "if trip specific" do
      assert AutoTextDuration.build_time_string(%{
               start_time: ~T[15:00:00],
               start_time_specifier: :custom,
               is_trip_combination?: true
             }) == ""
    end

    test "if start specifier is missing" do
      assert AutoTextDuration.build_time_string(%{start_time_specifier: nil}) == ""
    end

    test "if end specifier is missing" do
      assert AutoTextDuration.build_time_string(%{end_time_specifier: nil}) == ""
    end

    test "if start time is missing" do
      assert AutoTextDuration.build_time_string(%{start_time: nil}) == ""
    end

    test "from start of service to end of service" do
      expected = ""

      actual =
        AutoTextDuration.build_time_string(%{
          start_time_specifier: :start_of_service,
          end_time_specifier: :end_of_service
        })

      assert expected == actual
    end

    test "from start of service when end is nil" do
      expected = "from start of service"

      actual =
        AutoTextDuration.build_time_string(%{
          end_time: nil,
          start_time_specifier: :start_of_service,
          end_time_specifier: :custom
        })

      assert expected == actual
    end

    test "from start of service when end is custom" do
      expected = "from start of service to 3:00 PM"

      actual =
        AutoTextDuration.build_time_string(%{
          end_time: ~T[15:00:00],
          start_time_specifier: :start_of_service,
          end_time_specifier: :custom
        })

      assert expected == actual
    end

    test "when start is nil" do
      expected = ""

      actual =
        AutoTextDuration.build_time_string(%{
          start_time: nil,
          start_time_specifier: :custom,
          end_time_specifier: :end_of_service
        })

      assert expected == actual
    end

    test "to end of service when start is custom" do
      expected = "from 3:00 PM to end of service"

      actual =
        AutoTextDuration.build_time_string(%{
          start_time: ~T[15:00:00],
          start_time_specifier: :custom,
          end_time_specifier: :end_of_service
        })

      assert expected == actual
    end

    test "custom to custom when start is nil" do
      expected = ""

      actual =
        AutoTextDuration.build_time_string(%{
          start_time: nil,
          end_time: ~T[15:00:00],
          start_time_specifier: :custom,
          end_time_specifier: :custom
        })

      assert expected == actual
    end

    test "custom to custom when end is nil" do
      expected = ""

      actual =
        AutoTextDuration.build_time_string(%{
          start_time: ~T[10:30:00],
          end_time: nil,
          start_time_specifier: :custom,
          end_time_specifier: :custom
        })

      assert expected == actual
    end

    test "custom to custom" do
      expected = "from 10:30 AM to 3:00 PM"

      actual =
        AutoTextDuration.build_time_string(%{
          start_time: ~T[10:30:00],
          end_time: ~T[15:00:00],
          start_time_specifier: :custom,
          end_time_specifier: :custom
        })

      assert expected == actual
    end
  end
end
