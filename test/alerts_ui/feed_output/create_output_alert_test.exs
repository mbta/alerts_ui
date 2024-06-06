defmodule AlertsUI.FeedOutput.CreateOutputAlertTest do
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.Alerts
  alias AlertsUI.FeedOutput.CreateOutputAlert

  describe "build_alert/2" do
    test "properly outputs alert map" do
      active_period_start = DateTime.utc_now() |> DateTime.add(40, :day)
      active_period_end = active_period_start |> DateTime.add(1, :hour)

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
          "Affected trips:\r\n307 (7:40 am from North Station)\r\n308 (8:05 am from Lowell)\r\n309 (8:25 am from North Station)\r\n310 (8:50 am from Lowell)\r\n311 (9:10 am from North Station)\r\n312 (9:30 am from Lowell)\r\n313 (10:10 am from North Station)\r\n314 (10:12 am from Lowell)\r\n315 (11:10 am from North Station)\r\n316 (11:12 am from Lowell)\r\n317 (12:10 pm from North Station)\r\n318 (12:12 pm from Lowell)\r\n319 (1:10 pm from North Station)\r\n320 (1:12 pm from Lowell)\r\n321 (2:10 pm from North Station)\r\n322 (2:12 pm from Lowell)\r\n323 (3:10 pm from North Station)\r\n324 (3:12 pm from Lowell)",
        severity_level: :WARNING,
        service_effect_text: "Lowell Line delay",
        short_header_text:
          "On weekdays, from Sep 25th through mid-Oct, between 8am & 4pm, Lowell Ln passengers may experience delays of 5-10 minutes both ways due to t",
        severity: 3,
        created_timestamp: ~U[2023-09-21 14:18:54Z],
        last_modified_timestamp: ~U[2023-10-12 13:45:43Z],
        last_push_notification_timestamp: ~U[2023-09-21 14:18:54Z],
        closed_timestamp: ~U[2023-09-22 14:18:54Z],
        duration_certainty: :KNOWN,
        active_period: [
          build(:active_period, %{start: active_period_start, end: active_period_end})
        ],
        active_period_start: active_period_start,
        active_period_end: active_period_end,
        informed_entity: [
          informed_entity_1,
          informed_entity_2
        ]
      })

      existing_alert = Alerts.get_by_alert_id("524485")

      expected = %{
        id: "524485",
        alert: %{
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY",
          cause: :UNKNOWN_CAUSE,
          cause_detail: "UNKNOWN_CAUSE",
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
                  "Affected trips:\r\n307 (7:40 am from North Station)\r\n308 (8:05 am from Lowell)\r\n309 (8:25 am from North Station)\r\n310 (8:50 am from Lowell)\r\n311 (9:10 am from North Station)\r\n312 (9:30 am from Lowell)\r\n313 (10:10 am from North Station)\r\n314 (10:12 am from Lowell)\r\n315 (11:10 am from North Station)\r\n316 (11:12 am from Lowell)\r\n317 (12:10 pm from North Station)\r\n318 (12:12 pm from Lowell)\r\n319 (1:10 pm from North Station)\r\n320 (1:12 pm from Lowell)\r\n321 (2:10 pm from North Station)\r\n322 (2:12 pm from Lowell)\r\n323 (3:10 pm from North Station)\r\n324 (3:12 pm from Lowell)",
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
          created_timestamp: 1_695_305_934,
          last_modified_timestamp: 1_697_118_343,
          last_push_notification_timestamp: 1_695_305_934,
          closed_timestamp: 1_695_392_334,
          timeframe_text: %{
            translation: [
              %{
                text: "#{Timex.month_name(active_period_end.month)} #{active_period_end.day}",
                language: "en"
              }
            ]
          },
          alert_lifecycle: :UPCOMING,
          duration_certainty: :KNOWN,
          active_period: [
            %{
              start: DateTime.to_unix(active_period_start),
              end: DateTime.to_unix(active_period_end)
            }
          ],
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
      }

      actual = CreateOutputAlert.build_alert(existing_alert)
      assert expected == actual
    end
  end

  describe "build_gtfs_header/1" do
    test "outputs correctly formatted header" do
      assert %{gtfs_realtime_version: "2.0", incrementality: :FULL_DATASET, timestamp: _} =
               CreateOutputAlert.build_gtfs_header()
    end
  end
end
