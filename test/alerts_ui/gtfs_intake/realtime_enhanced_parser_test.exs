defmodule AlertsUI.GTFSIntake.RealtimeEnhancedParserTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true

  import Test.Support.Helpers
  alias AlertsUI.GTFSIntake.RealtimeEnhancedParser

  describe "parse/1" do
    test "parsing alert JSON results in alert atructs with expected fields" do
      binary = File.read!(fixture_path("alerts_enhanced.json"))
      [actual_alert, _alert2] = parsed = RealtimeEnhancedParser.parse(binary)
      assert Enum.all?(parsed, &is_map(&1))
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
      Enum.all?(informed_entities, &is_map(&1))
      assert ie_1.agency_id == "1"
      assert ie_1.route_type == 2
      assert ie_1.route_id == "CR-Lowell"
      assert is_map(ie_1.trip)
      assert ie_1.trip.trip_id == "CR-627689-308"
      assert ie_1.trip.route_id == "CR-Lowell"
      assert ie_1.trip.direction_id == 1
      assert ie_1.trip.start_date == ~D[2023-09-21]
      assert ie_1.trip.start_time.time == ~T[01:40:30]
      assert ie_1.trip.start_time.relative_day == 2
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
