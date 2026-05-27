defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.StopRouteSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  import Ecto.Changeset
  import Phoenix.LiveViewTest
  import Mock
  import Test.Support.Helpers
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.StopRouteServiceSlice
  alias MBTAV3API.Stops.Stop

  describe "stop_id_options/5 preservation logic" do
    test "a stop that was selected but is no longer in available_stops disappears when selected_stops is empty" do
      available_stops = [%Stop{id: "place-dwnxg", name: "Downtown Crossing"}]

      options =
        StopRouteServiceSlice.stop_id_options(
          available_stops,
          [],
          nil,
          1,
          ["place-pktrm"]
        )

      option_values = Enum.map(options, &Keyword.get(&1, :value))
      refute "place-pktrm" in option_values,
             "Expected Park Street to be absent from options, but it appeared — " <>
               "this would mean preservation is working, disproving the hypothesis"
    end

    test "a stop that was selected IS preserved when it is present in selected_stops" do
      park_street = %Stop{id: "place-pktrm", name: "Park Street"}
      available_stops = [%Stop{id: "place-dwnxg", name: "Downtown Crossing"}]

      options =
        StopRouteServiceSlice.stop_id_options(
          available_stops,
          [park_street],
          nil,
          1,
          ["place-pktrm"]
        )

      option_values = Enum.map(options, &Keyword.get(&1, :value))
      assert "place-pktrm" in option_values,
             "Expected Park Street to be preserved in options when selected_stops is populated"
    end
  end
end
