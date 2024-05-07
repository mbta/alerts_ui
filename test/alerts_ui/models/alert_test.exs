defmodule AlertsUI.Models.AlertTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  import Mock

  alias AlertsUI.Models.{Alert, InformedEntity, TripDescriptor}
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  describe "changeset/2" do
    test "create with header, description, and informed_entity is valid" do
      params = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        active_period: [
          %{
            start: ~U[2023-10-20 16:15:00Z],
            end: ~U[2023-10-20 18:45:38Z]
          }
        ],
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
      }

      changeset = Alert.changeset(%Alert{}, params)
      assert changeset.valid?
    end

    test "create with invalid effect is invalid" do
      params = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        effect: :COOL_BEAN,
        active_period: [
          %{
            start: ~U[2023-10-20 16:15:00Z],
            end: ~U[2023-10-20 18:45:38Z]
          }
        ],
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
      }

      changeset = Alert.changeset(%Alert{}, params)
      refute changeset.valid?
    end

    test "create with invalid active period is not valid" do
      params = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        active_period: [
          %{
            start: "not valid",
            end: ~U[2023-10-20 18:45:38Z]
          }
        ],
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
      }

      changeset = Alert.changeset(%Alert{}, params)
      refute changeset.valid?
    end

    test "alert without header and description is not valid" do
      changeset = Alert.changeset(%Alert{}, %{header_text: "a", url: "example.com"})
      refute changeset.valid?
    end
  end

  describe "draft_changeset/2" do
    test "create with draft set as true is valid" do
      params = %{
        draft: true
      }

      changeset = Alert.draft_changeset(%Alert{}, params)
      assert changeset.valid?
    end

    test "create with draft set as false is invalid" do
      params = %{
        draft: false
      }

      changeset = Alert.draft_changeset(%Alert{}, params)
      refute changeset.valid?
    end

    test "create with draft unset or false is invalid" do
      params = %{
        header_text: "a"
      }

      changeset = Alert.draft_changeset(%Alert{}, params)
      refute changeset.valid?
    end
  end

  describe "entities_with_icons" do
    test "returns a list of route IDs or facility activities representing the alert's informed entities" do
      alert = %Alert{
        id: "1",
        informed_entity: [
          %InformedEntity{activities: [:board, :exit, :ride], route_id: "28", route_type: 3},
          %InformedEntity{
            activities: [:using_wheelchair, :park_car, :board],
            facility_id: "772",
            stop_id: "70511"
          }
        ]
      }

      assert Alert.entities_with_icons(alert) == ["28", "using_wheelchair", "park_car"]
    end

    test "returns only unique results" do
      alert = %Alert{
        id: "1",
        informed_entity: [
          %InformedEntity{activities: [:board], route_id: "28", route_type: 3},
          %InformedEntity{activities: [:exit], route_id: "28", route_type: 3}
        ]
      }

      assert Alert.entities_with_icons(alert) == ["28"]
    end

    test "combines bike activities" do
      alert = %Alert{
        id: "1",
        informed_entity: [
          %InformedEntity{
            activities: [:bringing_bike, :store_bike],
            facility_id: "772",
            stop_id: "70511"
          }
        ]
      }

      assert Alert.entities_with_icons(alert) == ["bike"]
    end

    test "returns empty list if no informed entity" do
      alert = %Alert{
        id: "1",
        informed_entity: [
          %InformedEntity{
            facility_id: "772",
            stop_id: "70511",
            activities: nil
          }
        ]
      }

      assert Alert.entities_with_icons(alert) == []
    end
  end

  describe "get_direction/1" do
    test "returns nil if informed entity is empty list" do
      assert Alert.get_direction([]) == nil
    end

    test "returns direction if only 1 direction found" do
      informed_entity = [
        %InformedEntity{activities: [:exit], route_id: "28", route_type: 3, direction_id: 1},
        %InformedEntity{activities: [:exit], route_id: "29", route_type: 3, direction_id: 1},
        %InformedEntity{activities: [:exit], route_id: "27", route_type: 3}
      ]

      assert Alert.get_direction(informed_entity) == "1"
    end

    test "returns direction if direction is in trip" do
      informed_entity = [
        %InformedEntity{activities: [:exit], route_id: "28", route_type: 3},
        %InformedEntity{
          activities: [:exit],
          route_id: "29",
          route_type: 3,
          trip: %TripDescriptor{direction_id: 1}
        },
        %InformedEntity{activities: [:exit], route_id: "27", route_type: 3}
      ]

      assert Alert.get_direction(informed_entity) == "1"
    end

    test "returns nil if 2 directions found" do
      informed_entity = [
        %InformedEntity{activities: [:exit], route_id: "28", route_type: 3, direction_id: 0},
        %InformedEntity{activities: [:exit], route_id: "29", route_type: 3, direction_id: 1}
      ]

      assert Alert.get_direction(informed_entity) == nil
    end
  end

  describe "systemwide?/1" do
    test "true if any informed entity does not specify a route ID" do
      assert Alert.systemwide?(%Alert{
               informed_entity: [%InformedEntity{activities: [:exit], route_type: 3}]
             })

      refute Alert.systemwide?(%Alert{
               informed_entity: [
                 %InformedEntity{activities: [:exit], route_type: 3, route_id: "28"}
               ]
             })
    end
  end

  describe "get_route_type/1" do
    test "returns nil if informed entity is empty list" do
      assert Alert.get_route_type(%Alert{informed_entity: []}) == nil
    end

    test "returns 1 if any route types are 0 or 1" do
      alert = %Alert{
        informed_entity: [
          %InformedEntity{activities: [:exit], route_id: "28", route_type: 0, direction_id: 1},
          %InformedEntity{activities: [:exit], route_id: "29", route_type: 1, direction_id: 1},
          %InformedEntity{activities: [:exit], route_id: "27", route_type: 2}
        ]
      }

      assert Alert.get_route_type(alert) == 1
    end

    test "returns route type of head if no 0 or 1" do
      alert = %Alert{
        informed_entity: [
          %InformedEntity{activities: [:exit], route_id: "28", route_type: 3, direction_id: 1},
          %InformedEntity{activities: [:exit], route_id: "29", route_type: 3, direction_id: 1},
          %InformedEntity{activities: [:exit], route_id: "27", route_type: 3}
        ]
      }

      assert Alert.get_route_type(alert) == 3
    end

    test "accepts an Alert" do
      alert = %Alert{
        informed_entity: [
          %InformedEntity{activities: [:exit], route_id: "27", route_type: 3}
        ]
      }

      assert Alert.get_route_type(alert) == 3
    end

    test "returns nil for a systemwide alert" do
      alert = %Alert{
        informed_entity: [
          %InformedEntity{activities: [:exit], route_type: 0},
          %InformedEntity{activities: [:exit], route_type: 1},
          %InformedEntity{activities: [:exit], route_type: 2}
        ]
      }

      assert Alert.get_route_type(alert) == nil
    end
  end

  describe "service_types/1" do
    test "returns service types for a systemwide alert" do
      assert Alert.service_types(%Alert{
               informed_entity: [%InformedEntity{activities: [:exit], route_type: 3}]
             }) == [3]
    end

    test "returns an empty list for non-systemwide alerts" do
      assert Alert.service_types(%Alert{
               informed_entity: [
                 %InformedEntity{activities: [:exit], route_id: "27", route_type: 3}
               ]
             }) == []
    end

    test "maps subway route types to only 1" do
      assert Alert.service_types(%Alert{
               informed_entity: [
                 %InformedEntity{activities: [:exit], route_type: 0},
                 %InformedEntity{activities: [:exit], route_type: 1},
                 %InformedEntity{activities: [:exit], route_type: 2}
               ]
             }) == [1, 2]
    end

    test "returns an empty list for an alert with no informed entities" do
      assert Alert.service_types(%Alert{informed_entity: []}) == []
    end
  end

  describe "gather_route_ids/1" do
    test "lists route ids from informed entity" do
      informed_entity = [
        %InformedEntity{activities: [:exit], route_id: "27", route_type: 3, direction_id: 1},
        %InformedEntity{activities: [:exit], route_id: "28", route_type: 3, direction_id: 1},
        %InformedEntity{activities: [:exit], route_id: "29", route_type: 3, direction_id: 1},
        %InformedEntity{activities: [:exit], route_id: "29", route_type: 3, direction_id: 1},
        %InformedEntity{activities: [:exit], route_type: 3}
      ]

      assert Alert.gather_route_ids(informed_entity) == ["27", "28", "29"]
    end
  end

  describe "gather_parent_stop_ids/1" do
    # test "works correctly if editing" do
    #   with_mock(StopsRepo, [
    #     get_parent: fn _stop -> %{id: "place-aqucl"} end
    #   ]) do
    #     {:ok, view, _html} =
    #       live_isolated_component(
    #         StopRouteAffectedService,
    #         @assigns
    #         |> Map.merge(%{
    #           editing: true,
    #           available_stops: [%Stop{id: "place-aqucl"}, %Stop{id: "place-andrw"}],
    #           available_routes: [%Route{id: "Blue", type: 1}, %Route{id: "Green", type: 1}],
    #           alert_data: %{
    #             stop_ids: ["70043", "70044"],
    #             route_ids: ["Blue"],
    #             route_type: 1
    #           }
    #         })
    #       )
    #       open_browser(view)
    #       assert view |> render() =~ ~s(<option selected="selected" value="place-aqucl">)
    #       assert view |> render() =~ ~s(<option selected="selected" value="Blue">)
    #   end
    # end

    test "lists parent stop ids from informed entity" do
      with_mock(StopsRepo,
        get_parent: fn _stop -> %{id: "place-aqucl"} end
      ) do
        informed_entity = [
          %InformedEntity{activities: [:exit], route_id: "27", route_type: 3, stop_id: "70043"},
          %InformedEntity{activities: [:exit], route_id: "28", route_type: 3, stop_id: "70044"},
          %InformedEntity{
            activities: [:exit],
            route_id: "28",
            route_type: 3,
            stop_id: "place-aqucl"
          },
          %InformedEntity{activities: [:exit], route_type: 3}
        ]

        assert Alert.gather_parent_stop_ids(informed_entity) == ["place-aqucl"]
      end
    end
  end

  describe "gather_trip_ids/1" do
    test "lists trip ids from informed entity" do
      informed_entity = [
        %InformedEntity{activities: [:exit], route_type: 3, trip: %TripDescriptor{trip_id: "3"}},
        %InformedEntity{activities: [:exit], route_type: 3, trip: %TripDescriptor{trip_id: "2"}},
        %InformedEntity{activities: [:exit], route_type: 3},
        %InformedEntity{activities: [:exit], route_type: 3, trip: %TripDescriptor{trip_id: "1"}},
        %InformedEntity{activities: [:exit], route_type: 3, trip: %TripDescriptor{}}
      ]

      assert Alert.gather_trip_ids(informed_entity) == ["3", "2", "1"]
    end
  end
end
