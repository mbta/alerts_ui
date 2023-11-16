defmodule AlertsUI.FeedOutput.CreateGtfsTest do
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.FeedOutput.CreateGtfsJson
  alias AlertsUI.FeedOutput.CreateOutputAlert

  setup do
    test_alert_1 =
      build(:alert, %{alert_id: "123", header_text: "cool beans"})
      |> CreateOutputAlert.build_alert()

    test_alert_2 =
      build(:alert, %{alert_id: "234", header_text: "hi mom"})
      |> CreateOutputAlert.build_alert()

    {:ok, test_alerts: [test_alert_1, test_alert_2]}
  end

  describe "build_gtfs_header/1" do
    test "outputs correctly formatted header" do
      assert %{gtfs_realtime_version: "2.0", incrementality: :FULL_DATASET, timestamp: _} =
               CreateGtfsJson.build_gtfs_header()
    end
  end

  describe "output_json/1" do
    test "returns json from map", %{test_alerts: test_alerts} do
      assert test_alerts |> CreateGtfsJson.output_json() |> is_list
    end
  end
end
