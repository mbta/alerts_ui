defmodule AlertsUI.FeedOutput.CreateStandardAlertTest do
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.FeedOutput.{CreateOutputAlert, CreateStandardAlert}

  describe "build_standard_alert/1" do
    test "returns standard alert" do
      test_alert =
        build(:alert, %{alert_id: "234", header_text: "hi mom", alert_lifecycle: "ONGOING"})
        |> CreateOutputAlert.build_alert()

      result = CreateStandardAlert.build_standard_alert(test_alert)

      assert result == %{
               id: "234",
               alert: %{
                 active_period: [%{start: 1_697_068_860, end: 1_697_155_260}],
                 description_text: %{translation: [%{text: "b", language: "en"}]},
                 header_text: %{translation: [%{text: "hi mom", language: "en"}]},
                 informed_entity: [%{route_id: "1", trip: %{trip_id: "1"}}]
               }
             }
    end
  end
end
