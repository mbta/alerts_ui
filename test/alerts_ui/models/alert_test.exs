defmodule AlertsUI.Models.AlertTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true

  alias AlertsUI.Models.{Alert, InformedEntity, TripDescriptor}

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

    test "returns nil if 2 directions found" do
      informed_entity = [
        %InformedEntity{activities: [:exit], route_id: "28", route_type: 3, direction_id: 0},
        %InformedEntity{activities: [:exit], route_id: "29", route_type: 3, direction_id: 1}
      ]

      assert Alert.get_direction(informed_entity) == nil
    end
  end

  describe "get_route_type/1" do
    test "returns nil if informed entity is empty list" do
      assert Alert.get_route_type([]) == nil
    end

    test "returns 1 if any route types are 0 or 1" do
      informed_entity = [
        %InformedEntity{activities: [:exit], route_id: "28", route_type: 0, direction_id: 1},
        %InformedEntity{activities: [:exit], route_id: "29", route_type: 1, direction_id: 1},
        %InformedEntity{activities: [:exit], route_id: "27", route_type: 2}
      ]

      assert Alert.get_route_type(informed_entity) == 1
    end

    test "returns route type of head if no 0 or 1" do
      informed_entity = [
        %InformedEntity{activities: [:exit], route_id: "28", route_type: 3, direction_id: 1},
        %InformedEntity{activities: [:exit], route_id: "29", route_type: 3, direction_id: 1},
        %InformedEntity{activities: [:exit], route_id: "27", route_type: 3}
      ]

      assert Alert.get_route_type(informed_entity) == 3
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

  describe "gather_stop_ids/1" do
    test "lists stop ids from informed entity" do
      informed_entity = [
        %InformedEntity{activities: [:exit], route_id: "27", route_type: 3, stop_id: "1"},
        %InformedEntity{activities: [:exit], route_id: "28", route_type: 3, stop_id: "2"},
        %InformedEntity{activities: [:exit], route_id: "29", route_type: 3, stop_id: "2"},
        %InformedEntity{activities: [:exit], route_id: "29", route_type: 3, stop_id: "3"},
        %InformedEntity{activities: [:exit], route_type: 3}
      ]

      assert Alert.gather_stop_ids(informed_entity) == ["1", "2", "3"]
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
