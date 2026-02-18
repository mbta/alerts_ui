defmodule AlertsUI.Models.AlertTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true

  import Ecto.Changeset
  import Mock
  import AlertsUI.Support.Factory

  alias AlertsUI.Models.{Alert, InformedEntity, TripDescriptor}
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  @five_minutes_ago DateTime.utc_now()
                    |> DateTime.add(-5, :minute)
                    |> DateTime.truncate(:second)

  describe "changeset/2" do
    test "create with header, description, active_period_start and informed_entity is valid" do
      params = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        active_period_start: ~U[2023-10-20 16:15:00Z],
        active_period: [
          %{
            start: ~U[2023-10-20 16:15:00Z],
            end: ~U[2023-10-20 18:45:38Z]
          }
        ],
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}],
        user: build(:user)
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
        active_period_start: ~U[2023-10-20 16:15:00Z],
        active_period: [
          %{
            start: ~U[2023-10-20 16:15:00Z],
            end: ~U[2023-10-20 18:45:38Z]
          }
        ],
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}],
        user: build(:user)
      }

      changeset = Alert.changeset(%Alert{}, params)
      refute changeset.valid?
    end

    test "create with invalid active period is not valid" do
      params = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        active_period_start: ~U[2023-10-20 14:45:38Z],
        active_period: [
          %{
            start: "not valid",
            end: ~U[2023-10-20 18:45:38Z]
          }
        ],
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}],
        user: build(:user)
      }

      changeset = Alert.changeset(%Alert{}, params)
      refute changeset.valid?
    end

    test "create with current time before active period start is valid" do
      params = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        active_period: [
          %{
            start: ~U[2023-10-19 18:45:38Z],
            end: ~U[2023-10-20 18:45:38Z]
          }
        ],
        active_period_start: ~U[2023-10-19 18:45:38Z],
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}],
        current_time: ~U[2023-10-18 18:45:38Z],
        user: build(:user)
      }

      changeset = Alert.changeset(%Alert{}, params)
      assert changeset.valid?
    end

    test "create with current time equal to active period start is valid" do
      params = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        active_period: [
          %{
            start: ~U[2023-10-19 18:45:38Z],
            end: ~U[2023-10-20 18:45:38Z]
          }
        ],
        active_period_start: ~U[2023-10-19 18:45:38Z],
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}],
        current_time: ~U[2023-10-19 18:45:38.571154Z],
        user: build(:user)
      }

      changeset = Alert.changeset(%Alert{}, params)
      assert changeset.valid?
    end

    test "create with improper recurrence days is not valid" do
      params = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        active_period: [
          %{
            start: ~U[2025-10-01 01:00:38Z],
            end: ~U[2025-10-01 05:45:38Z]
          }
        ],
        active_period_start: ~U[2025-10-01 01:00:38Z],
        recurrence_days: ["friday"],
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}],
        current_time: ~U[2023-10-19 18:45:38.571154Z],
        user: build(:user)
      }

      changeset = Alert.changeset(%Alert{}, params)
      refute changeset.valid?
    end

    test "create with correct recurrence days is valid" do
      params = %{
        alert_id: "123",
        header_text: "a",
        description_text: "b",
        active_period: [
          %{
            start: ~U[2025-10-01 01:00:38Z],
            end: ~U[2025-10-01 05:45:38Z]
          }
        ],
        active_period_start: ~U[2025-10-01 01:00:38Z],
        recurrence_days: ["tuesday"],
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}],
        current_time: ~U[2023-10-19 18:45:38.571154Z],
        user: build(:user)
      }

      changeset = Alert.changeset(%Alert{}, params)
      assert changeset.valid?
    end

    test "alert without header and description is not valid" do
      changeset =
        Alert.changeset(%Alert{}, %{
          header_text: "a",
          url: "example.com",
          active_period_start: @five_minutes_ago
        })

      refute changeset.valid?
    end

    test "does not change created_at on an existing alert" do
      existing_alert = %Alert{
        alert_id: "123",
        header_text: "old",
        active_period_start: @five_minutes_ago,
        created_at: @five_minutes_ago
      }

      params = %{
        alert_id: "123",
        header_text: "new"
      }

      changeset = Alert.changeset(existing_alert, params)

      refute changed?(changeset, :created_at)
    end

    test "alert with unknown duration and nil active_period_end is valid" do
      changeset =
        %Alert{
          alert_id: "123",
          header_text: "old",
          created_at: @five_minutes_ago,
          active_period_start: ~U[2025-11-03 10:04:00Z],
          informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}],
          duration_certainty: :UNKNOWN
        }
        |> Alert.changeset(%{})

      assert changeset.valid?
    end

    test "alert with unknown duration and active_period_end is invalid" do
      changeset =
        %Alert{
          alert_id: "123",
          header_text: "old",
          created_at: @five_minutes_ago,
          active_period_start: @five_minutes_ago,
          active_period_end: @five_minutes_ago,
          informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}],
          duration_certainty: :UNKNOWN
        }
        |> Alert.changeset(%{})

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

  describe "get_direction/1" do
    test "returns nil if informed entity is empty list" do
      assert Alert.get_direction(build(:alert, informed_entity: [])) == nil
    end

    test "returns direction if only 1 direction found" do
      informed_entity = [
        %InformedEntity{activities: [:exit], route_id: "28", route_type: 3, direction_id: 1},
        %InformedEntity{activities: [:exit], route_id: "29", route_type: 3, direction_id: 1},
        %InformedEntity{activities: [:exit], route_id: "27", route_type: 3}
      ]

      assert Alert.get_direction(build(:alert, informed_entity: informed_entity)) == "1"
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

      assert Alert.get_direction(build(:alert, informed_entity: informed_entity)) == "1"
    end

    test "returns nil if 2 directions found" do
      informed_entity = [
        %InformedEntity{activities: [:exit], route_id: "28", route_type: 3, direction_id: 0},
        %InformedEntity{activities: [:exit], route_id: "29", route_type: 3, direction_id: 1}
      ]

      assert Alert.get_direction(build(:alert, informed_entity: informed_entity)) == nil
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

      assert Alert.gather_route_ids(build(:alert, informed_entity: informed_entity)) == [
               "27",
               "28",
               "29"
             ]
    end

    test "lists unique route ids from original selection for IBI alert" do
      alert =
        build(
          :alert,
          source: :IBI,
          original_route_selections: ["foo|1", "bar|2", "dup|1"]
        )

      assert Alert.gather_route_ids(alert) == ["1", "2"]
    end
  end

  describe "gather_parent_stop_ids/1" do
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

        assert Alert.gather_parent_stop_ids(build(:alert, informed_entity: informed_entity)) == [
                 "place-aqucl"
               ]
      end
    end

    test "lists unique parent stop ids from original selection for IBI alert" do
      with_mock(StopsRepo,
        get_parent: fn _stop -> %{id: "foo-bar"} end
      ) do
        alert =
          build(
            :alert,
            source: :IBI,
            original_stop_selections: ["foo|1", "bar|2", "dup|1"]
          )

        assert Alert.gather_parent_stop_ids(alert) == ["foo-bar"]
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

      assert Alert.gather_trip_ids(build(:alert, informed_entity: informed_entity)) == [
               "3",
               "2",
               "1"
             ]
    end

    test "lists unique trip ids from original selection for IBI alert" do
      alert =
        build(
          :alert,
          source: :IBI,
          original_trip_selections: ["foo|1", "bar|2", "dup|1"]
        )

      assert Alert.gather_trip_ids(alert) == ["1", "2"]
    end
  end
end
