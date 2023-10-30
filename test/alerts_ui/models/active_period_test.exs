defmodule AlertsUI.Models.ActivePeriodTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  alias AlertsUI.Models.ActivePeriod

  describe "changeset/2" do
    test "create with start and end time is valid" do
      params = %{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:01:00Z]}

      changeset = ActivePeriod.changeset(%ActivePeriod{}, params)
      assert changeset.valid?
    end

    test "not valid if start time is missing" do
      changeset = ActivePeriod.changeset(%ActivePeriod{}, %{end_time: ~U[2023-10-13 00:01:00Z]})
      assert changeset.valid? == false
    end

    test "not valid if end time is missing" do
      changeset = ActivePeriod.changeset(%ActivePeriod{}, %{start_time: ~U[2023-10-12 00:01:00Z]})
      assert changeset.valid? == false
    end
  end
end
