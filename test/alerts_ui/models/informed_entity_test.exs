defmodule AlertsUI.Models.InformedEntityTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  alias AlertsUI.Models.InformedEntity

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

  describe "facility_activies/0" do
    test "provides a list of activity atoms that are considered facilities" do
      facility_activies = InformedEntity.facility_activies()

      assert is_list(facility_activies)
      assert Enum.all?(facility_activies, &is_atom/1)
    end
  end

  describe "facility_activity?/1" do
    test "true if this is activity is considered a facility" do
      assert InformedEntity.facility_activity?(:park_car)
      refute InformedEntity.facility_activity?(:other)
    end
  end
end
