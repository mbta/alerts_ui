defmodule AlertsUI.AlertValidation.AlertAssociationValidatorTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  import Mock

  alias AlertsUI.AlertValidation.AlertAssociationValidator

  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.{Schedule, Trip}
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @cr_alert_params %{
    alert_id: "345",
    primary_service_type: "2",
    original_route_selections: ["Lowell Line|CR-Lowell"],
    original_stop_selections: ["Wedgemere|place-NHRML-0073", "Bad Stop|place-nope"],
    original_trip_selections: ["595|CR-683322-595", "000|nope-444"]
  }

  @closed_alert_params %{
    alert_id: "234",
    primary_service_type: "1",
    closed_timestamp: ~U[2023-10-14 00:01:00Z],
    original_route_selections: ["Red Line|Red"],
    original_stop_selections: ["Alewife|place-alfcl", "Bad Stop|place-nope"],
    original_trip_selections: ["595|CR-683322-595", "000|nope-444"]
  }

  @ferry_alert_params %{
    alert_id: "123",
    primary_service_type: "4",
    original_route_selections: ["Quincy Ferry|Boat-F7"],
    original_stop_selections: ["Central Wharf|Boat-Aquarium"],
    original_trip_selections: ["595|CR-683322-595", "000|nope-444"]
  }

  @subway_alert_params %{
    alert_id: "456",
    primary_service_type: "1",
    original_route_selections: ["Red Line|Red"],
    original_stop_selections: ["Alewife|place-alfcl", "Bad Stop|place-nope"],
    original_trip_selections: []
  }

  describe("validate_alerts/0") do
    test "finds alerts with stops no longer associated with their routes" do
      insert(:alert, @cr_alert_params)
      insert(:alert, @closed_alert_params)
      insert(:alert, @subway_alert_params)

      with_mocks([
        {StopsRepo, [],
         [
           all: fn ["filter[route]": "Red"] ->
             [%Stop{id: "place-alfcl", name: "Alewife"}]
           end
         ]}
      ]) do
        assert AlertAssociationValidator.validate_alerts() ==
                 [
                   %{
                     alert_id: "456",
                     invalid_stops: ["place-nope"],
                     invalid_trips: []
                   }
                 ]
      end
    end

    test "finds alerts with trips no longer associated with their routes" do
      insert(:alert, @cr_alert_params)
      insert(:alert, @closed_alert_params)
      insert(:alert, @ferry_alert_params)

      with_mocks([
        {StopsRepo, [],
         [
           all: fn ["filter[route]": "Boat-F7"] ->
             [%Stop{id: "Boat-Aquarium", name: "Central Wharf"}]
           end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn ["Boat-F7"] ->
             [%Schedule{trip: %Trip{id: "CR-683322-595", name: "595"}}]
           end
         ]}
      ]) do
        assert AlertAssociationValidator.validate_alerts() ==
                 [
                   %{
                     alert_id: "123",
                     invalid_stops: [],
                     invalid_trips: ["nope-444"]
                   }
                 ]
      end
    end
  end

  describe("validate_commute_rail_alerts/0") do
    test "finds CR alert with stops and trips no longer associated with their routes" do
      insert(:alert, @cr_alert_params)
      insert(:alert, @closed_alert_params)
      insert(:alert, @ferry_alert_params)

      with_mocks([
        {StopsRepo, [],
         [
           all: fn ["filter[route]": "CR-Lowell"] ->
             [%Stop{id: "place-NHRML-0073", name: "Wedgemere"}]
           end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn ["CR-Lowell"] ->
             [%Schedule{trip: %Trip{id: "CR-683322-595", name: "595"}}]
           end
         ]}
      ]) do
        assert AlertAssociationValidator.validate_commuter_rail_alerts() ==
                 [
                   %{
                     alert_id: "345",
                     invalid_stops: ["place-nope"],
                     invalid_trips: ["nope-444"]
                   }
                 ]
      end
    end
  end
end
