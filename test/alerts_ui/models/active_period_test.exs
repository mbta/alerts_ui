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

    test "create with just end time is valid" do
      changeset = ActivePeriod.changeset(%ActivePeriod{}, %{end: ~U[2023-10-13 00:01:00Z]})
      assert changeset.valid?
    end

    test "create with just start time is valid" do
      changeset = ActivePeriod.changeset(%ActivePeriod{}, %{start: ~U[2023-10-12 00:01:00Z]})
      assert changeset.valid?
    end

    test "create with not start or end time is not valid" do
      changeset = ActivePeriod.changeset(%ActivePeriod{}, %{})
      assert changeset.valid? == false
    end
  end
end
