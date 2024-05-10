defmodule AlertsUI.FeedOutput.WriteFeedTest do
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.FeedOutput.WriteFeed

  describe "write_json_file/2" do
    test "it writes" do
      insert(:alert, alert_id: "123abc", active_period_start: ~U[2023-10-12 00:01:00Z])

      expected_alert = %{
        "alert" => %{
          "active_period" => [%{"end" => 1_697_155_260, "start" => 1_697_068_860}],
          "description_text" => %{"translation" => [%{"language" => "en", "text" => "b"}]},
          "header_text" => %{"translation" => [%{"language" => "en", "text" => "a"}]},
          "informed_entity" => [
            %{"activities" => [], "route_id" => "1", "trip" => %{"trip_id" => "1"}}
          ],
          "alert_lifecycle" => "ONGOING"
        },
        "id" => "123abc"
      }

      {:ok, actual} = WriteFeed.write_feed()

      assert %{
               "gtfs_realtime_version" => "2.0",
               "incrementality" => "FULL_DATASET",
               "timestamp" => _
             } = actual["header"]

      assert [^expected_alert] = actual["entity"]
    end
  end
end
