defmodule AlertsUI.FeatureFlagsTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true

  alias AlertsUI.FeatureFlags
  alias AlertsUI.Models.FeatureFlag
  alias AlertsUI.Repo

  def get(name), do: Repo.one(from ff in FeatureFlag, where: ff.name == ^name)

  describe "enabled?/2" do
    test "creates the flag (disabled) if it does not already exist" do
      before_flag = get("Test Flag")
      FeatureFlags.enabled?("Test Flag")
      after_flag = get("Test Flag")

      assert nil == before_flag
      assert %FeatureFlag{name: "Test Flag", enabled: false} = after_flag
    end

    test "returns the enabled value of a flag that already exists" do
      FeatureFlag.build("Test Flag", true)
      |> Repo.insert()

      assert FeatureFlags.enabled?("Test Flag")
    end
  end

  describe "enable/1" do
    test "creates the flag (enabled) if it does not already exist" do
      before_flag = get("Test Flag")
      FeatureFlags.enable("Test Flag")
      after_flag = get("Test Flag")

      assert nil == before_flag
      assert %FeatureFlag{name: "Test Flag", enabled: true} = after_flag
    end

    test "enables an existing flag" do
      FeatureFlag.build("Test Flag", false)
      |> Repo.insert()

      FeatureFlags.enable("Test Flag")

      flag = get("Test Flag")
      assert flag.enabled == true
    end
  end

  describe "disable/1" do
    test "creates the flag (disabled) if it does not already exist" do
      before_flag = get("Test Flag")
      FeatureFlags.disable("Test Flag")
      after_flag = get("Test Flag")

      assert nil == before_flag
      assert %FeatureFlag{name: "Test Flag", enabled: false} = after_flag
    end

    test "disables an existing flag" do
      FeatureFlag.build("Test Flag", true)
      |> Repo.insert()

      FeatureFlags.disable("Test Flag")

      flag = get("Test Flag")
      assert flag.enabled == false
    end
  end
end
