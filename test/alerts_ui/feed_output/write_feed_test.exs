defmodule AlertsUI.FeedOutput.WriteFeedTest do
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  import Test.Support.Helpers
  alias AlertsUI.Alerts
  alias AlertsUI.FeedOutput.{CreateOutputAlert, WriteFeed}
  alias AlertsUI.Models.ActivePeriod

  describe "write_feed/0" do
    setup do
      reassign_env(:alerts_ui, :get_http_fn, fn _ ->
        %{status: 200, body: Jason.encode!(%{"entity" => []})}
      end)

      reassign_env(:alerts_ui, :get_obj_fn, fn _, _ ->
        %{status_code: 200, body: Jason.encode!(%{"entity" => []})}
      end)

      reassign_env(:alerts_ui, :make_request_fn, fn _ ->
        %{status_code: 200, body: Jason.encode!(%{"entity" => []})}
      end)
    end

    test "it writes" do
      current_time = DateTime.utc_now()
      four_minutes_ago = current_time |> DateTime.add(-4, :minute)

      insert(:alert,
        alert_id: "123abc",
        active_period_start: ~U[2023-10-12 00:01:00Z],
        active_period: [
          build(:active_period, %{start: ~U[2023-10-12 00:01:00Z], end: four_minutes_ago})
        ],
        last_modified_timestamp: four_minutes_ago,
        closed_timestamp: four_minutes_ago,
        user: build(:user)
      )

      insert(:alert,
        alert_id: "234abc",
        active_period_start: ~U[2023-10-12 00:01:00Z],
        active_period: [build(:active_period, %{start: ~U[2023-10-12 00:01:00Z], end: nil})],
        notification_period_start: DateTime.add(current_time, -1, :hour),
        last_modified_timestamp: current_time,
        user: build(:user)
      )

      insert(:alert,
        alert_id: "345abc",
        active_period_start: ~U[2023-10-12 00:01:00Z],
        active_period_end: four_minutes_ago,
        active_period: [
          build(:active_period, %{start: ~U[2023-10-12 00:01:00Z], end: four_minutes_ago})
        ],
        last_modified_timestamp: four_minutes_ago,
        user: build(:user)
      )

      insert(:alert,
        alert_id: "456abc",
        active_period_start: ~U[2023-10-12 00:01:00Z],
        notification_period_start: DateTime.add(current_time, 1, :hour),
        active_period: [build(:active_period, %{start: ~U[2023-10-12 00:01:00Z], end: nil})],
        user: build(:user)
      )

      insert(:alert,
        alert_id: "567abc",
        active_period_start: DateTime.add(current_time, -1, :hour),
        active_period_end: DateTime.add(current_time, 1, :hour),
        duration_certainty: :ESTIMATED,
        notification_period_end: ActivePeriod.end_of_service_datetime_utc(current_time),
        active_period: [
          build(:active_period, %{
            start: DateTime.add(current_time, -1, :hour),
            end: DateTime.add(current_time, 1, :hour)
          })
        ],
        user: build(:user)
      )

      {:ok, actual} = WriteFeed.write_feed()
      [alert_1, alert_2, alert_3, alert_4] = actual["entity"] |> Enum.sort_by(& &1["id"])

      assert %{
               "alert" => %{
                 "active_period" => [],
                 "description_text" => %{"translation" => [%{"language" => "en", "text" => "b"}]},
                 "header_text" => %{"translation" => [%{"language" => "en", "text" => "a"}]},
                 "informed_entity" => [
                   %{"activities" => [], "route_id" => "1", "trip" => %{"trip_id" => "1"}}
                 ],
                 "alert_lifecycle" => "ONGOING",
                 "reminder_times" => [1_727_222_460]
               },
               "id" => "123abc"
             } = alert_1

      assert within_two_seconds(
               alert_1["alert"]["created_timestamp"],
               current_time |> DateTime.to_unix()
             )

      assert within_two_seconds(
               alert_1["alert"]["last_modified_timestamp"],
               four_minutes_ago |> DateTime.to_unix()
             )

      assert within_two_seconds(
               alert_1["alert"]["closed_timestamp"],
               four_minutes_ago |> DateTime.to_unix()
             )

      assert %{
               "alert" => %{
                 "active_period" => [%{"start" => 1_697_068_860}],
                 "description_text" => %{"translation" => [%{"language" => "en", "text" => "b"}]},
                 "header_text" => %{"translation" => [%{"language" => "en", "text" => "a"}]},
                 "informed_entity" => [
                   %{"activities" => [], "route_id" => "1", "trip" => %{"trip_id" => "1"}}
                 ],
                 "alert_lifecycle" => "ONGOING",
                 "reminder_times" => [1_727_222_460]
               },
               "id" => "234abc"
             } = alert_2

      assert within_two_seconds(
               alert_2["alert"]["created_timestamp"],
               current_time |> DateTime.to_unix()
             )

      assert within_two_seconds(
               alert_2["alert"]["last_modified_timestamp"],
               current_time |> DateTime.to_unix()
             )

      assert alert_2["alert"]["closed_timestamp"] === nil

      %{
        "alert" => %{
          "active_period" => [],
          "description_text" => %{"translation" => [%{"language" => "en", "text" => "b"}]},
          "header_text" => %{"translation" => [%{"language" => "en", "text" => "a"}]},
          "informed_entity" => [
            %{"activities" => [], "route_id" => "1", "trip" => %{"trip_id" => "1"}}
          ],
          "duration_certainty" => "KNOWN",
          "alert_lifecycle" => "ONGOING",
          "reminder_times" => [1_727_222_460]
        },
        "id" => "345abc"
      } = alert_3

      assert within_two_seconds(
               alert_3["alert"]["created_timestamp"],
               current_time |> DateTime.to_unix()
             )

      assert within_two_seconds(
               alert_3["alert"]["last_modified_timestamp"],
               current_time |> DateTime.to_unix()
             )

      assert within_two_seconds(
               alert_3["alert"]["closed_timestamp"],
               current_time |> DateTime.to_unix()
             )

      expected_start = current_time |> DateTime.add(-1, :hour) |> DateTime.to_unix()
      expected_end = current_time |> DateTime.add(2, :hour) |> DateTime.to_unix()

      %{
        "alert" => %{
          "active_period" => [%{"start" => ^expected_start, "end" => ^expected_end}],
          "description_text" => %{"translation" => [%{"language" => "en", "text" => "b"}]},
          "header_text" => %{"translation" => [%{"language" => "en", "text" => "a"}]},
          "informed_entity" => [
            %{"activities" => [], "route_id" => "1", "trip" => %{"trip_id" => "1"}}
          ],
          "duration_certainty" => "ESTIMATED",
          "alert_lifecycle" => "NEW"
        },
        "id" => "567abc"
      } = alert_4

      assert %{
               "gtfs_realtime_version" => "2.0",
               "incrementality" => "FULL_DATASET",
               "timestamp" => _
             } = actual["header"]
    end

    test "SITA gets special filtering" do
      insert(:alert,
        alert_id: "890abc",
        effect_detail: "SHUTTLE",
        informed_entity: [
          %{
            route_type: 2,
            stop_id: "FB-0148-02",
            activities: [
              "BOARD",
              "EXIT",
              "RIDE"
            ],
            agency_id: "1",
            route_id: "CR-Franklin",
            trip: %{
              route_id: "CR-Franklin",
              direction_id: 1,
              trip_id: "BasewUpdatedWalpoleTurns-788924-1756"
            }
          },
          %{
            route_type: 2,
            stop_id: "FB-0148-05",
            activities: [
              "BOARD",
              "EXIT",
              "RIDE"
            ],
            agency_id: "1",
            route_id: "CR-Franklin",
            trip: %{
              route_id: "CR-Franklin",
              direction_id: 1,
              trip_id: "BasewUpdatedWalpoleTurns-788924-1756"
            }
          }
        ]
      )

      alerts =
        Alerts.list_all_open()
        |> Enum.map(&CreateOutputAlert.build_alert/1)

      {:ok, output} = WriteFeed.write(:enhanced_sita, alerts)

      assert %{
               "entity" => [
                 %{
                   "alert" => %{
                     "informed_entity" => [
                       %{
                         "route_type" => 2,
                         "agency_id" => "1",
                         "route_id" => "CR-Franklin",
                         "trip" => %{
                           "route_id" => "CR-Franklin",
                           "direction_id" => 1,
                           "trip_id" => "BasewUpdatedWalpoleTurns-788924-1756"
                         }
                       }
                     ]
                   },
                   "id" => "890abc"
                 }
               ]
             } = Jason.decode!(output)
    end
  end

  defp within_two_seconds(time_1, time_2) do
    # account for small delays in running tests that make the times differ slightly
    abs(time_1 - time_2) < 2
  end
end
