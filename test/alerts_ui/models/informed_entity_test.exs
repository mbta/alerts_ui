defmodule AlertsUI.Models.InformedEntityTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  alias AlertsUI.Models.InformedEntity

  describe "create_changeset/2" do
    test "create with at least 1 field is valid" do
      params = %{agency_id: "1", trip: %{trip_id: "2"}}
      changeset = InformedEntity.create_changeset(%InformedEntity{}, params)
      assert changeset.valid?
    end

    test "params cannot be empty" do
      changeset = InformedEntity.create_changeset(%InformedEntity{}, %{})
      assert changeset.valid? == false
    end
  end
end
