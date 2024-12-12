defmodule AlertsUI.FeedOutput.WriteFeedTest do
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.FeedOutput.WriteFeed

  describe "write_feed/0" do
    test "it writes" do
      current_time = DateTime.utc_now()
      four_minutes_ago = current_time |> DateTime.add(-4, :minute)

      insert(:alert,
        alert_id: "123abc",
        active_period_start: ~U[2023-10-12 00:01:00Z],
        active_period: [
          build(:active_period, %{start: ~U[2023-10-12 00:01:00Z], end: four_minutes_ago})
        ],
        closed_timestamp: four_minutes_ago
      )

      insert(:alert,
        alert_id: "234abc",
        active_period_start: ~U[2023-10-12 00:01:00Z],
        active_period: [build(:active_period, %{start: ~U[2023-10-12 00:01:00Z], end: nil})],
        notification_period_start: DateTime.add(current_time, -1, :hour)
      )

      insert(:alert,
        alert_id: "345abc",
        active_period_start: ~U[2023-10-12 00:01:00Z],
        active_period_end: four_minutes_ago,
        active_period: [
          build(:active_period, %{start: ~U[2023-10-12 00:01:00Z], end: four_minutes_ago})
        ]
      )

      insert(:alert,
        alert_id: "456abc",
        active_period_start: ~U[2023-10-12 00:01:00Z],
        notification_period_start: DateTime.add(current_time, 1, :hour),
        active_period: [build(:active_period, %{start: ~U[2023-10-12 00:01:00Z], end: nil})]
      )

      insert(:alert,
      alert_id: "567abc",
      active_period_start: DateTime.add(current_time, -1, :hour),
      active_period_end: DateTime.add(current_time, 1, :hour),
      duration_certainty: :ESTIMATED,
      active_period: [build(:active_period, %{start: DateTime.add(current_time, -1, :hour), end: DateTime.add(current_time, 1, :hour)})]
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
               current_time |> DateTime.to_unix()
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
                "alert_lifecycle" => "NEW",
              },
              "id" => "567abc"
            } = alert_4

      assert %{
               "gtfs_realtime_version" => "2.0",
               "incrementality" => "FULL_DATASET",
               "timestamp" => _
             } = actual["header"]
    end
  end

  defp within_two_seconds(time_1, time_2) do
    # account for small delays in running tests that make the times differ slightly
    abs(time_1 - time_2) < 2
  end
end
