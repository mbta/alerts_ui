defmodule AlertsUI.GTFSIntake.RealtimeEnhancedParserTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import Test.Support.Helpers
  alias AlertsUI.GTFSIntake.RealtimeEnhancedParser
  alias AlertsUI.Models.{Alert, ExtendedTime, InformedEntity, TripDescriptor}

  @sample_alert %{
    "id" => "524485",
    "alert" => %{
      "effect" => "OTHER_EFFECT",
      "effect_detail" => "DELAY",
      "cause" => "UNKNOWN_CAUSE",
      "cause_detail" => "UNKNOWN_CAUSE",
      "header_text" => %{
        "translation" => [
          %{
            "text" =>
              "On weekdays, through October, between 8:00 am and 4:00 pm, Lowell Line passengers may experience delays of 5-10 minutes in both directions due to tie replacement work between Lowell and Wilmington. ",
            "language" => "en"
          }
        ]
      },
      "description_text" => %{
        "translation" => [
          %{
            "text" =>
              "Affected trips:\r\n307 (7:40 am from North Station)\r\n308 (8:05 am from Lowell)\r\n309 (8:25 am from North Station)\r\n310 (8:50 am from Lowell)\r\n311 (9:10 am from North Station)\r\n312 (9:30 am from Lowell)\r\n313 (10:10 am from North Station)\r\n314 (10:12 am from Lowell)\r\n315 (11:10 am from North Station)\r\n316 (11:12 am from Lowell)\r\n317 (12:10 pm from North Station)\r\n318 (12:12 pm from Lowell)\r\n319 (1:10 pm from North Station)\r\n320 (1:12 pm from Lowell)\r\n321 (2:10 pm from North Station)\r\n322 (2:12 pm from Lowell)\r\n323 (3:10 pm from North Station)\r\n324 (3:12 pm from Lowell)",
            "language" => "en"
          }
        ]
      },
      "severity_level" => "WARNING",
      "service_effect_text" => %{
        "translation" => [
          %{
            "text" => "Lowell Line delay",
            "language" => "en"
          }
        ]
      },
      "short_header_text" => %{
        "translation" => [
          %{
            "text" =>
              "On weekdays, from Sep 25th through mid-Oct, between 8am & 4pm, Lowell Ln passengers may experience delays of 5-10 minutes both ways due to t",
            "language" => "en"
          }
        ]
      },
      "severity" => 3,
      "created_timestamp" => 1_695_305_934,
      "last_modified_timestamp" => 1_697_118_343,
      "last_push_notification_timestamp" => 1_695_305_934,
      "timeframe_text" => %{
        "translation" => [
          %{
            "text" => "through October 20",
            "language" => "en"
          }
        ]
      },
      "alert_lifecycle" => "ONGOING",
      "duration_certainty" => "KNOWN",
      "active_period" => [
        %{
          "start" => 1_696_272_120,
          "end" => 1_697_832_000
        }
      ],
      "informed_entity" => [
        %{
          "agency_id" => "1",
          "route_type" => 2,
          "route_id" => "CR-Lowell",
          "trip" => %{
            "route_id" => "CR-Lowell",
            "trip_id" => "CR-627691-310",
            "direction_id" => 1,
            "start_date" => "20230921",
            "start_time" => "25:40:30"
          },
          "activities" => [
            "BOARD",
            "EXIT",
            "RIDE"
          ]
        },
        %{
          "agency_id" => "1",
          "route_type" => 2,
          "route_id" => "CR-Lowell",
          "trip" => %{
            "route_id" => "CR-Lowell",
            "trip_id" => "CR-632752-309",
            "direction_id" => 0
          },
          "activities" => [
            "BOARD",
            "EXIT",
            "RIDE"
          ]
        }
      ]
    }
  }

  describe "parse/1" do
    test "parsing an enhanced Alerts JSON file returns Alert structs" do
      binary = File.read!(fixture_path("alerts_enhanced.json"))
      parsed = RealtimeEnhancedParser.parse(binary)
      assert is_list(parsed)
      assert Enum.all?(parsed, &(&1.__struct__ in [Alert]))
    end
  end

  describe "decode_alert/2" do
    test "parsing alert JSON results in alert with expected fields" do
      actual_alert =
        RealtimeEnhancedParser.decode_alert(@sample_alert["alert"], @sample_alert["id"])

      assert actual_alert.__struct__ in [Alert]
      assert actual_alert.effect == :OTHER_EFFECT
      assert actual_alert.effect_detail == "DELAY"

      assert actual_alert.header_text ==
               "On weekdays, through October, between 8:00 am and 4:00 pm, Lowell Line passengers may experience delays of 5-10 minutes in both directions due to tie replacement work between Lowell and Wilmington. "

      assert actual_alert.cause == :UNKNOWN_CAUSE
      assert actual_alert.cause_detail == "UNKNOWN_CAUSE"

      assert actual_alert.description_text ==
               "Affected trips:\r\n307 (7:40 am from North Station)\r\n308 (8:05 am from Lowell)\r\n309 (8:25 am from North Station)\r\n310 (8:50 am from Lowell)\r\n311 (9:10 am from North Station)\r\n312 (9:30 am from Lowell)\r\n313 (10:10 am from North Station)\r\n314 (10:12 am from Lowell)\r\n315 (11:10 am from North Station)\r\n316 (11:12 am from Lowell)\r\n317 (12:10 pm from North Station)\r\n318 (12:12 pm from Lowell)\r\n319 (1:10 pm from North Station)\r\n320 (1:12 pm from Lowell)\r\n321 (2:10 pm from North Station)\r\n322 (2:12 pm from Lowell)\r\n323 (3:10 pm from North Station)\r\n324 (3:12 pm from Lowell)"

      assert actual_alert.severity_level == :WARNING
      assert actual_alert.service_effect_text == "Lowell Line delay"

      assert actual_alert.short_header_text ==
               "On weekdays, from Sep 25th through mid-Oct, between 8am & 4pm, Lowell Ln passengers may experience delays of 5-10 minutes both ways due to t"

      assert actual_alert.severity == 3
      assert actual_alert.created_timestamp == ~U[2023-09-21 14:18:54Z]
      assert actual_alert.last_modified_timestamp == ~U[2023-10-12 13:45:43Z]
      assert actual_alert.last_push_notification_timestamp == ~U[2023-09-21 14:18:54Z]
      assert actual_alert.timeframe_text == "through October 20"
      assert actual_alert.alert_lifecycle == :ONGOING

      assert actual_alert.active_period == [
               %{start: ~U[2023-10-02 18:42:00Z], end: ~U[2023-10-20 20:00:00Z]}
             ]

      assert actual_alert.duration_certainty == :KNOWN
      [ie_1, _ie_2] = informed_entities = actual_alert.informed_entity
      Enum.all?(informed_entities, &(&1.__struct__ in [InformedEntity]))
      assert ie_1.agency_id == "1"
      assert ie_1.route_type == 2
      assert ie_1.route_id == "CR-Lowell"
      assert ie_1.trip.__struct__ in [TripDescriptor]
      assert ie_1.trip.trip_id == "CR-627691-310"
      assert ie_1.trip.route_id == "CR-Lowell"
      assert ie_1.trip.direction_id == 1
      assert ie_1.trip.start_date == ~D[2023-09-21]
      assert ie_1.trip.start_time == %ExtendedTime{relative_day: 2, time: ~T[01:40:30]}
      assert ie_1.activities == [:BOARD, :EXIT, :RIDE]
    end
  end

  describe "date/1" do
    test "parses GTFS date correctly" do
      gtfs_datestring = "20231029"
      parsed_date = RealtimeEnhancedParser.date(gtfs_datestring)
      assert parsed_date == ~D[2023-10-29]
    end
  end
end
