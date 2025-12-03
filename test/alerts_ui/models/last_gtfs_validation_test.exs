defmodule AlertsUI.Models.LastGtfsValidationTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  alias AlertsUI.Models.LastGTFSValidation

  describe "changeset/2" do
    test "create with datetime of last validation valid" do
      params = %{datetime_of_last_validation: ~U[2023-10-20 16:15:00Z]}

      changeset = LastGTFSValidation.changeset(%LastGTFSValidation{}, params)
      assert changeset.valid?
    end

    test "create without datetime of last validation not valid" do
      changeset = LastGTFSValidation.changeset(%LastGTFSValidation{}, %{})
      refute changeset.valid?
    end
  end

  describe "store_last_gtfs_validation/1" do
    test "inserts record when given date" do
      time = ~U[2025-11-17 13:34:39Z]
      result = LastGTFSValidation.store_last_gtfs_validation(time)
      assert result == {:ok, ~U[2025-11-17 13:34:39Z]}
    end
  end

  describe "get_most_recent_validation/0" do
    test "returns nil if no records found" do
      result = LastGTFSValidation.get_most_recent_validation()
      assert is_nil(result)
    end

    test "returns most recent record" do
      time1 = ~U[2025-11-15 13:34:39Z]
      time2 = ~U[2025-11-17 13:34:39Z]
      time3 = ~U[2025-11-16 13:34:39Z]

      LastGTFSValidation.store_last_gtfs_validation(time1)
      LastGTFSValidation.store_last_gtfs_validation(time2)
      LastGTFSValidation.store_last_gtfs_validation(time3)

      result = LastGTFSValidation.get_most_recent_validation()

      assert result == time2
    end
  end
end
