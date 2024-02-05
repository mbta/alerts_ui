defmodule AlertsUI.Models.AlertTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true

  alias AlertsUI.Models.{Alert, InformedEntity}

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
  end
end
