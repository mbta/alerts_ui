defmodule AlertsUI.Models.FeatureFlagTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true

  alias AlertsUI.Models.FeatureFlag
  import Ecto.Changeset

  describe "changeset/2" do
    test "makes a changeset" do
      assert FeatureFlag.changeset(%FeatureFlag{}, %{name: "Test Flag"}).valid?
    end
  end

  describe "set/2" do
    test "sets the enabled flag" do
      changeset =
        %FeatureFlag{name: "Test Flag", enabled: false}
        |> FeatureFlag.set(true)

      assert get_change(changeset, :enabled) == true
    end
  end

  describe "build/1" do
    test "makes a changeset for the name that is not enabled" do
      build_changeset = FeatureFlag.build("Test Flag")
      changeset = FeatureFlag.changeset(%FeatureFlag{}, %{name: "Test Flag", enabled: false})

      assert build_changeset == changeset
    end
  end
end
