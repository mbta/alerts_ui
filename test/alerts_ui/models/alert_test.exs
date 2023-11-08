defmodule AlertsUI.Models.AlertTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  alias AlertsUI.Models.Alert

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
      assert changeset.valid? == false
    end

    test "alert without header and description is not valid" do
      changeset = Alert.changeset(%Alert{}, %{header_text: "a", url: "example.com"})
      assert changeset.valid? == false
    end
  end
end
