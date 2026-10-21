defmodule AlertsUI.AlertValidation.AlertValidatorTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  import Mock

  alias AlertsUI.AlertValidation.AlertValidator
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  describe("validate_alerts/1") do
    test "finds alerts with routes no longer in api" do
      with_mocks([
        {RoutesRepo, [],
         [
           all: fn ["filter[id]": _], [reject_hidden: false, base_url: _, api_key: _] ->
             [%Route{id: "1", type: 3}, %Route{id: "2", type: 3}]
           end
         ]}
      ]) do
        insert(:alert, %{
          alert_id: "567",
          primary_service_type: "2",
          informed_entity: [%{route_type: 2, route_id: "4"}]
        })

        insert(:alert, %{
          alert_id: "456",
          primary_service_type: "3",
          informed_entity: [%{route_type: 3, route_id: "1"}, %{route_type: 3, route_id: "2"}]
        })

        insert(:alert, %{
          alert_id: "234",
          primary_service_type: "3",
          closed_timestamp: ~U[2023-10-14 00:01:00Z],
          informed_entity: [%{route_type: 3, route_id: "1"}]
        })

        insert(:alert, %{
          alert_id: "123",
          primary_service_type: "3",
          informed_entity: [
            %{route_type: 3, route_id: "1"},
            %{route_type: 3, route_id: "2"},
            %{route_type: 3, route_id: "3"}
          ]
        })

        assert AlertValidator.validate_alerts() ==
                 [
                   %{
                     alert_id: "123",
                     invalid_facilities: [],
                     invalid_routes: ["3"],
                     invalid_stops: [],
                     invalid_trips: []
                   }
                 ]
      end
    end

    test "does not return green line as invalid" do
      with_mocks([
        {RoutesRepo, [],
         [
           all: fn ["filter[id]": _], [reject_hidden: false, base_url: _, api_key: _] ->
             [%Route{id: "1", type: 3}]
           end,
           green_line: fn ->
             %Route{
               id: "Green",
               name: "Green Line"
             }
           end
         ]}
      ]) do
        insert(:alert, %{
          alert_id: "123",
          informed_entity: [
            %{route_type: 3, route_id: "1"},
            %{route_type: 3, route_id: "3"},
            %{route_type: 1, route_id: "Green"}
          ]
        })

        assert AlertValidator.validate_alerts() ==
                 [
                   %{
                     alert_id: "123",
                     invalid_facilities: [],
                     invalid_routes: ["3"],
                     invalid_stops: [],
                     invalid_trips: []
                   }
                 ]
      end
    end

    test "finds alerts with stops no longer in api" do
      with_mocks([
        {StopsRepo, [],
         [
           all: fn ["filter[id]": _], [base_url: _, api_key: _] ->
             [%Stop{id: "1"}, %Stop{id: "2"}]
           end
         ]}
      ]) do
        insert(:alert, %{alert_id: "456", informed_entity: [%{stop_id: "1"}, %{stop_id: "2"}]})

        insert(:alert, %{
          alert_id: "234",
          closed_timestamp: ~U[2023-10-14 00:01:00Z],
          informed_entity: [%{stop_id: "1"}]
        })

        insert(:alert, %{
          alert_id: "123",
          informed_entity: [%{stop_id: "1"}, %{stop_id: "2"}, %{stop_id: "3"}]
        })

        assert AlertValidator.validate_alerts() ==
                 [
                   %{
                     alert_id: "123",
                     invalid_facilities: [],
                     invalid_routes: [],
                     invalid_stops: ["3"],
                     invalid_trips: []
                   }
                 ]
      end
    end

    test "finds alerts with trips no longer in api" do
      with_mocks([
        {SchedulesRepo, [],
         [
           trips_by_ids: fn _, [], [base_url: _, api_key: _] ->
             [%Trip{id: "1"}, %Trip{id: "2"}]
           end
         ]}
      ]) do
        insert(:alert, %{
          alert_id: "456",
          informed_entity: [%{trip: %{trip_id: "1"}}, %{trip: %{trip_id: "2"}}]
        })

        insert(:alert, %{
          alert_id: "234",
          closed_timestamp: ~U[2023-10-14 00:01:00Z],
          informed_entity: [%{trip: %{trip_id: "1"}}]
        })

        insert(:alert, %{
          alert_id: "123",
          informed_entity: [
            %{trip: %{trip_id: "1"}},
            %{trip: %{trip_id: "2"}},
            %{trip: %{trip_id: "3"}}
          ]
        })

        assert AlertValidator.validate_alerts() == [
                 %{
                   alert_id: "123",
                   invalid_facilities: [],
                   invalid_routes: [],
                   invalid_stops: [],
                   invalid_trips: ["3"]
                 }
               ]
      end
    end

    test "finds alerts with facilities no longer in api" do
      with_mocks([
        {FacilitiesRepo, [],
         [
           get: fn
             "1", [], [base_url: _, api_key: _] -> %Facility{id: "1"}
             "2", [], [base_url: _, api_key: _] -> %Facility{id: "2"}
             "3", [], [base_url: _, api_key: _] -> nil
           end
         ]},
        {StopsRepo, [],
         [
           all: fn _, _ -> [] end
         ]},
        {RoutesRepo, [],
         [
           all: fn _, _ ->
             []
           end
         ]}
      ]) do
        insert(:alert, %{
          alert_id: "456",
          informed_entity: [%{facility_id: "1"}, %{facility_id: "2"}],
          primary_service_type: "access"
        })

        insert(:alert, %{
          alert_id: "234",
          closed_timestamp: ~U[2023-10-14 00:01:00Z],
          informed_entity: [%{facility_id: "1"}],
          primary_service_type: "access"
        })

        insert(:alert, %{
          alert_id: "123",
          informed_entity: [
            %{facility_id: "1", route_id: "100", stop_id: "200"},
            %{facility_id: "2", route_id: "300", stop_id: "400"},
            %{facility_id: "3", route_id: "100", stop_id: "200"}
          ],
          primary_service_type: "access"
        })

        assert AlertValidator.validate_alerts() == [
                 %{
                   alert_id: "123",
                   invalid_facilities: ["3"],
                   invalid_routes: [],
                   invalid_stops: [],
                   invalid_trips: []
                 }
               ]
      end
    end
  end

  describe("validate_commuter_rail_alerts/1") do
    test "finds CR alerts with routes no longer in api" do
      with_mocks([
        {RoutesRepo, [],
         [
           all: fn ["filter[id]": _], [reject_hidden: false, base_url: _, api_key: _] ->
             [%Route{id: "1", type: 2}, %Route{id: "2", type: 3}]
           end
         ]}
      ]) do
        insert(:alert, %{
          alert_id: "567",
          primary_service_type: "2",
          informed_entity: [%{route_type: 2, route_id: "4"}]
        })

        insert(:alert, %{
          alert_id: "456",
          primary_service_type: "3",
          informed_entity: [%{route_type: 3, route_id: "1"}, %{route_type: 3, route_id: "2"}]
        })

        insert(:alert, %{
          alert_id: "234",
          primary_service_type: "2",
          closed_timestamp: ~U[2023-10-14 00:01:00Z],
          informed_entity: [%{route_type: 3, route_id: "1"}]
        })

        insert(:alert, %{
          alert_id: "123",
          primary_service_type: "2",
          informed_entity: [
            %{route_type: 2, route_id: "1"},
            %{route_type: 3, route_id: "2"},
            %{route_type: 2, route_id: "3"}
          ]
        })

        assert AlertValidator.validate_commuter_rail_alerts() ==
                 [
                   %{
                     alert_id: "567",
                     invalid_facilities: [],
                     invalid_routes: ["4"],
                     invalid_stops: [],
                     invalid_trips: []
                   },
                   %{
                     alert_id: "123",
                     invalid_facilities: [],
                     invalid_routes: ["3"],
                     invalid_stops: [],
                     invalid_trips: []
                   }
                 ]
      end
    end
  end

  describe "format invalid alerts/1" do
    test "formats alerts if no invalid alerts" do
      with_mocks([
        {RoutesRepo, [],
         [
           all: fn ["filter[id]": _], [reject_hidden: false, base_url: _, api_key: _] ->
             [%Route{id: "1", type: 3}]
           end
         ]},
        {StopsRepo, [],
         [
           all: fn ["filter[id]": _], [base_url: _, api_key: _] -> [%Stop{id: "1"}] end
         ]},
        {SchedulesRepo, [],
         [
           trips_by_ids: fn _, [], [base_url: _, api_key: _] -> [%Trip{id: "1"}] end
         ]},
        {FacilitiesRepo, [],
         [
           get: fn
             "1", [], [base_url: _, api_key: _] -> %Facility{id: "1"}
             "2", [], [base_url: _, api_key: _] -> nil
           end
         ]}
      ]) do
        insert(:alert, %{
          alert_id: "123",
          informed_entity: [%{route_type: 3, route_id: "1"}]
        })

        insert(:alert, %{
          alert_id: "234",
          informed_entity: [%{stop_id: "1"}]
        })

        insert(:alert, %{
          alert_id: "345",
          informed_entity: [
            %{trip: %{trip_id: "1"}}
          ]
        })

        insert(:alert, %{
          alert_id: "456",
          informed_entity: [%{facility_id: "1"}]
        })

        result =
          AlertValidator.validate_alerts() |> AlertValidator.format_invalid_alerts("current")

        assert result == "No invalid alerts found"
      end
    end

    test "formats alerts correctly" do
      with_mocks([
        {RoutesRepo, [],
         [
           all: fn ["filter[id]": _], [reject_hidden: false, base_url: _, api_key: _] ->
             [%Route{id: "1", type: 3}]
           end
         ]},
        {StopsRepo, [],
         [
           all: fn ["filter[id]": _], [base_url: _, api_key: _] -> [%Stop{id: "1"}] end
         ]},
        {SchedulesRepo, [],
         [
           trips_by_ids: fn _, [], [base_url: _, api_key: _] -> [%Trip{id: "1"}] end
         ]},
        {FacilitiesRepo, [],
         [
           get: fn
             "1", [], [base_url: _, api_key: _] -> %Facility{id: "1"}
             "2", [], [base_url: _, api_key: _] -> nil
           end
         ]}
      ]) do
        insert(:alert, %{
          alert_id: "123",
          informed_entity: [%{route_type: 3, route_id: "1"}, %{route_type: 3, route_id: "2"}]
        })

        insert(:alert, %{
          alert_id: "234",
          informed_entity: [%{stop_id: "1"}, %{stop_id: "2"}]
        })

        insert(:alert, %{
          alert_id: "345",
          informed_entity: [
            %{trip: %{trip_id: "1"}},
            %{trip: %{trip_id: "2"}}
          ]
        })

        insert(:alert, %{
          alert_id: "456",
          informed_entity: [%{facility_id: "1"}, %{facility_id: "2"}]
        })

        result =
          AlertValidator.validate_alerts() |> AlertValidator.format_invalid_alerts("current")

        assert result ==
                 "The following alerts have entities that no longer exist in current GTFS:|Alert 456:|Facilities: 2||Alert 345:|Trips: 2||Alert 234:|Stops: 2||Alert 123:|Routes: 2"
      end
    end

    test "formats Commuter Rail alerts correctly" do
      with_mocks([
        {RoutesRepo, [],
         [
           all: fn ["filter[id]": _], [reject_hidden: false, base_url: _, api_key: _] ->
             [%Route{id: "1", type: 2}]
           end
         ]},
        {StopsRepo, [],
         [
           all: fn ["filter[id]": _], [base_url: _, api_key: _] -> [%Stop{id: "1"}] end
         ]},
        {SchedulesRepo, [],
         [
           trips_by_ids: fn _, [], [base_url: _, api_key: _] -> [%Trip{id: "1"}] end
         ]},
        {FacilitiesRepo, [],
         [
           get: fn
             "1", [], [base_url: _, api_key: _] -> %Facility{id: "1"}
             "2", [], [base_url: _, api_key: _] -> nil
           end
         ]}
      ]) do
        insert(:alert, %{
          alert_id: "123",
          primary_service_type: "2",
          informed_entity: [%{route_type: 2, route_id: "1"}, %{route_type: 2, route_id: "2"}]
        })

        insert(:alert, %{
          alert_id: "234",
          primary_service_type: "2",
          informed_entity: [%{stop_id: "1"}, %{stop_id: "2"}]
        })

        insert(:alert, %{
          alert_id: "345",
          primary_service_type: "2",
          informed_entity: [
            %{trip: %{trip_id: "1"}},
            %{trip: %{trip_id: "2"}}
          ]
        })

        result =
          AlertValidator.validate_commuter_rail_alerts()
          |> AlertValidator.format_invalid_alerts("upcoming", "Commuter Rail ")

        assert result ==
                 "The following Commuter Rail alerts have entities that no longer exist in upcoming GTFS:|Alert 345:|Trips: 2||Alert 234:|Stops: 2||Alert 123:|Routes: 2"
      end
    end
  end
end
