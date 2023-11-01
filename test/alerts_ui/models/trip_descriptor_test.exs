defmodule AlertsUI.Models.TripDescriptorTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  alias AlertsUI.Models.TripDescriptor

  describe "create_changeset/2" do
    test "create with trip id is valid" do
      changeset = TripDescriptor.create_changeset(%TripDescriptor{}, %{trip_id: "1"})
      assert changeset.valid?
    end

    test "create with start time but no trip id, is valid" do
      params = %{
        route_id: "a",
        direction_id: 1,
        start_time: %{relative_day: 1, time: ~T[12:12:12]},
        start_date: ~D[2023-12-12],
        schedule_relationship: :SCHEDULED
      }

      changeset = TripDescriptor.create_changeset(%TripDescriptor{}, params)
      assert changeset.valid?
    end

    test "create with no trip_id and wrong schedule relationship is not valid" do
      params = %{
        route_id: "a",
        direction_id: 1,
        start_time: %{relative_day: 1, time: ~T[12:12:12]},
        start_date: ~D[2023-12-12],
        schedule_relationship: :ADDED
      }

      changeset = TripDescriptor.create_changeset(%TripDescriptor{}, params)
      assert changeset.valid? == false
    end
  end
end
