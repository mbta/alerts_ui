defmodule AlertsUI.FeedOutput.CreateOutputAlertTest do
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.Alerts
  alias AlertsUI.FeedOutput.CreateOutputAlert

  describe "build_alert/2" do
    test "properly outputs alert map" do
      active_period_start = DateTime.utc_now() |> DateTime.add(40, :day)
      active_period_end = active_period_start |> DateTime.add(1, :hour)

      active_period_start_in_unix = DateTime.to_unix(active_period_start)
      active_period_end_in_unix = DateTime.to_unix(active_period_end)

      expected_time_frame_text =
        active_period_end
        |> Timex.Timezone.convert("America/New_York")
        |> then(&"#{Timex.month_name(&1.month)} #{&1.day}")

      trip1 =
        build(:trip_descriptor, %{
          route_id: "CR-Lowell",
          trip_id: "CR-627689-308",
          direction_id: 1,
          start_date: ~D[2023-09-21],
          start_time: build(:extended_time, %{relative_day: 2, time: ~T[01:40:30]})
        })

      trip2 =
        build(:trip_descriptor, %{
          route_id: "CR-Lowell",
          trip_id: "CR-627691-310",
          direction_id: 1,
          start_time: build(:extended_time, %{relative_day: 1, time: ~T[01:40:30]})
        })

      informed_entity_1 =
        build(:informed_entity, %{
          agency_id: "1",
          route_type: 2,
          route_id: "CR-Lowell",
          stop_id: "1003",
          facility_id: "park-qamnl-garage",
          trip: trip1,
          activities: [
            :BOARD,
            :EXIT,
            :RIDE
          ]
        })

      informed_entity_2 =
        build(:informed_entity, %{
          agency_id: "1",
          route_type: 2,
          route_id: "CR-Lowell",
          trip: trip2,
          activities: [
            :BOARD,
            :EXIT,
            :RIDE
          ]
        })

      insert(:alert, %{
        alert_id: "524485",
        effect: :OTHER_EFFECT,
        effect_detail: "DELAY",
        cause: :UNKNOWN_CAUSE,
        cause_detail: "UNKNOWN_CAUSE",
        header_text:
          "On weekdays, through October, between 8:00 am and 4:00 pm, Lowell Line passengers may experience delays of 5-10 minutes in both directions due to tie replacement work between Lowell and Wilmington. ",
        description_text:
          "Affected trips:\r\n\n307 (7:40 am from North Station)\n308 (8:05 am from Lowell)\n309 (8:25 am from North Station)\n310 (8:50 am from Lowell)\n311 (9:10 am from North Station)\n312 (9:30 am from Lowell)\n313 (10:10 am from North Station)\n314 (10:12 am from Lowell)\n315 (11:10 am from North Station)\n316 (11:12 am from Lowell)\n317 (12:10 pm from North Station)\n318 (12:12 pm from Lowell)\n319 (1:10 pm from North Station)\n320 (1:12 pm from Lowell)\n321 (2:10 pm from North Station)\n322 (2:12 pm from Lowell)\n323 (3:10 pm from North Station)\n324 (3:12 pm from Lowell)",
        severity_level: :WARNING,
        service_effect_text: "Lowell Line delay",
        short_header_text:
          "On weekdays, from Sep 25th through mid-Oct, between 8am & 4pm, Lowell Ln passengers may experience delays of 5-10 minutes both ways due to t",
        severity: 3,
        last_push_notification_timestamp: ~U[2023-09-21 14:18:54Z],
        last_modified_timestamp: ~U[2023-09-21 14:18:54Z],
        closed_timestamp: nil,
        duration_certainty: :KNOWN,
        active_period: [
          build(:active_period, %{start: active_period_start, end: active_period_end})
        ],
        active_period_start: active_period_start,
        active_period_end: active_period_end,
        informed_entity: [
          informed_entity_1,
          informed_entity_2
        ],
        reminder_times: [
          build(:reminder_time, %{reminder_time: ~U[2023-09-22 14:19:54Z]}),
          build(:reminder_time, %{reminder_time: ~U[2023-09-22 14:20:54Z]})
        ]
      })

      existing_alert = Alerts.get_by_alert_id("524485")

      actual = CreateOutputAlert.build_alert(existing_alert)

      assert %{
               id: "524485",
               alert: %{
                 effect: :OTHER_EFFECT,
                 effect_detail: %{
                   translation: [
                     %{
                       text: "DELAY",
                       language: "en"
                     }
                   ]
                 },
                 cause: :UNKNOWN_CAUSE,
                 cause_detail: %{
                   translation: [
                     %{
                       text: "UNKNOWN_CAUSE",
                       language: "en"
                     }
                   ]
                 },
                 header_text: %{
                   translation: [
                     %{
                       text:
                         "On weekdays, through October, between 8:00 am and 4:00 pm, Lowell Line passengers may experience delays of 5-10 minutes in both directions due to tie replacement work between Lowell and Wilmington. ",
                       language: "en"
                     }
                   ]
                 },
                 description_text: %{
                   translation: [
                     %{
                       text:
                         "Affected trips:\r\n\r\n307 (7:40 am from North Station)\r\n308 (8:05 am from Lowell)\r\n309 (8:25 am from North Station)\r\n310 (8:50 am from Lowell)\r\n311 (9:10 am from North Station)\r\n312 (9:30 am from Lowell)\r\n313 (10:10 am from North Station)\r\n314 (10:12 am from Lowell)\r\n315 (11:10 am from North Station)\r\n316 (11:12 am from Lowell)\r\n317 (12:10 pm from North Station)\r\n318 (12:12 pm from Lowell)\r\n319 (1:10 pm from North Station)\r\n320 (1:12 pm from Lowell)\r\n321 (2:10 pm from North Station)\r\n322 (2:12 pm from Lowell)\r\n323 (3:10 pm from North Station)\r\n324 (3:12 pm from Lowell)",
                       language: "en"
                     }
                   ]
                 },
                 severity_level: :WARNING,
                 service_effect_text: %{
                   translation: [
                     %{
                       text: "Lowell Line delay",
                       language: "en"
                     }
                   ]
                 },
                 short_header_text: %{
                   translation: [
                     %{
                       text:
                         "On weekdays, from Sep 25th through mid-Oct, between 8am & 4pm, Lowell Ln passengers may experience delays of 5-10 minutes both ways due to t",
                       language: "en"
                     }
                   ]
                 },
                 severity: 3,
                 last_push_notification_timestamp: 1_695_305_934,
                 last_modified_timestamp: 1_695_305_934,
                 timeframe_text: %{
                   translation: [
                     %{
                       text: ^expected_time_frame_text,
                       language: "en"
                     }
                   ]
                 },
                 alert_lifecycle: :UPCOMING,
                 duration_certainty: :KNOWN,
                 active_period: [
                   %{
                     start: ^active_period_start_in_unix,
                     end: ^active_period_end_in_unix
                   }
                 ],
                 reminder_times: [1_695_392_394, 1_695_392_454],
                 informed_entity: [
                   %{
                     agency_id: "1",
                     route_type: 2,
                     route_id: "CR-Lowell",
                     stop_id: "1003",
                     facility_id: "park-qamnl-garage",
                     trip: %{
                       route_id: "CR-Lowell",
                       trip_id: "CR-627689-308",
                       direction_id: 1,
                       start_date: "20230921",
                       start_time: "25:40:30"
                     },
                     activities: [
                       :BOARD,
                       :EXIT,
                       :RIDE
                     ]
                   },
                   %{
                     agency_id: "1",
                     route_type: 2,
                     route_id: "CR-Lowell",
                     trip: %{
                       route_id: "CR-Lowell",
                       trip_id: "CR-627691-310",
                       direction_id: 1,
                       start_time: "01:40:30"
                     },
                     activities: [
                       :BOARD,
                       :EXIT,
                       :RIDE
                     ]
                   }
                 ]
               }
             } = actual

      assert within_two_seconds(
               actual.alert.created_timestamp,
               DateTime.utc_now() |> DateTime.to_unix()
             )
    end

    test "filters out old recurring alerts" do
      insert(:alert, %{
        alert_id: "524486",
        active_period: [
          build(:active_period, %{start: ~U[2023-09-22 00:00:54Z], end: ~U[2023-09-22 14:20:54Z]}),
          build(:active_period, %{start: ~U[2023-09-23 00:00:54Z], end: ~U[2023-09-23 14:20:54Z]}),
          build(:active_period, %{start: ~U[2023-09-24 00:00:54Z], end: ~U[2023-09-24 00:00:54Z]})
        ],
        active_period_start: ~U[2023-09-22 00:00:54Z],
        active_period_end: ~U[2023-09-22 00:00:54Z],
        last_modified_timestamp: ~U[2023-09-22 00:00:54Z]
      })

      existing_alert = Alerts.get_by_alert_id("524486")
      actual = CreateOutputAlert.build_alert(existing_alert, ~U[2023-09-23 00:04:54Z])

      assert %{
               id: "524486",
               alert: %{
                 header_text: %{translation: [%{text: "a", language: "en"}]},
                 description_text: %{translation: [%{text: "b", language: "en"}]},
                 alert_lifecycle: :ONGOING,
                 reminder_times: [1_727_222_460],
                 active_period: [
                   %{end: 1_695_478_854, start: 1_695_427_254},
                   %{start: 1_695_513_654, end: 1_695_513_654}
                 ],
                 last_modified_timestamp: 1_695_340_854,
                 informed_entity: [%{route_id: "1", trip: %{trip_id: "1"}, activities: []}]
               }
             } = actual

      assert within_two_seconds(
               actual.alert.created_timestamp,
               DateTime.utc_now() |> DateTime.to_unix()
             )
    end

    test "removes active periods if it's closed" do
      insert(:alert, %{
        alert_id: "524486",
        active_period: [
          build(:active_period, %{start: ~U[2023-09-22 00:00:54Z], end: ~U[2023-09-22 14:20:54Z]}),
          build(:active_period, %{start: ~U[2023-09-23 00:00:54Z], end: ~U[2023-09-23 14:20:54Z]}),
          build(:active_period, %{start: ~U[2023-09-24 00:00:54Z], end: ~U[2023-09-24 00:00:54Z]})
        ],
        active_period_start: ~U[2023-09-22 00:00:54Z],
        active_period_end: ~U[2023-09-21 00:00:54Z],
        last_modified_timestamp: ~U[2023-09-21 00:00:54Z],
        closed_timestamp: ~U[2023-09-21 00:00:54Z]
      })

      existing_alert = Alerts.get_by_alert_id("524486")
      actual = CreateOutputAlert.build_alert(existing_alert, ~U[2023-09-23 00:04:54Z])

      assert %{
               id: "524486",
               alert: %{
                 header_text: %{translation: [%{text: "a", language: "en"}]},
                 description_text: %{translation: [%{text: "b", language: "en"}]},
                 alert_lifecycle: :ONGOING,
                 reminder_times: [1_727_222_460],
                 active_period: [],
                 closed_timestamp: 1_695_254_454,
                 last_modified_timestamp: 1_695_254_454,
                 informed_entity: [%{route_id: "1", trip: %{trip_id: "1"}, activities: []}]
               }
             } = actual

      assert within_two_seconds(
               actual.alert.created_timestamp,
               DateTime.utc_now() |> DateTime.to_unix()
             )
    end
  end

  describe "build_gtfs_header/1" do
    test "outputs correctly formatted header" do
      assert %{gtfs_realtime_version: "2.0", incrementality: :FULL_DATASET, timestamp: _} =
               CreateOutputAlert.build_gtfs_header()
    end
  end

  defp within_two_seconds(time_1, time_2) do
    # account for small delays in running tests that make the times differ slightly
    abs(time_1 - time_2) < 2
  end
end
