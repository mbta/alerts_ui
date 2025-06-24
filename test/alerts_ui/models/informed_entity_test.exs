defmodule AlertsUI.Models.InformedEntityTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  alias AlertsUI.Models.InformedEntity

  doctest InformedEntity

  describe "changeset/2" do
    test "create with at least 1 field is valid" do
      params = %{agency_id: "1", trip: %{trip_id: "2"}}
      changeset = InformedEntity.changeset(%InformedEntity{}, params)
      assert changeset.valid?
    end

    test "params cannot be empty" do
      changeset = InformedEntity.changeset(%InformedEntity{}, %{})
      assert changeset.valid? == false
    end
  end

  describe "facility_activities/0" do
    test "provides a list of activity atoms that are considered facilities" do
      facility_activities = InformedEntity.facility_activities()

      assert is_list(facility_activities)
      assert Enum.all?(facility_activities, &is_atom/1)
    end
  end

  describe "facility_activity?/1" do
    test "true if this is activity is considered a facility" do
      assert InformedEntity.facility_activity?(:PARK_CAR)
      refute InformedEntity.facility_activity?(:OTHER)
    end
  end
end
