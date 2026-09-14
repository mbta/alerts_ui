defmodule AlertsUI.FeatureFlagsTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true

  alias AlertsUI.FeatureFlags
  alias AlertsUI.Models.FeatureFlag
  alias AlertsUI.Repo

  def get(name), do: Repo.one(from ff in FeatureFlag, where: ff.name == ^name)

  describe "enabled?/2" do
    test "returns false if the flag does not exist" do
      before_flag = get("Test Flag")
      enabled? = FeatureFlags.enabled?("Test Flag")

      assert nil == before_flag
      assert enabled? == false
    end

    test "returns the enabled value of a flag that already exists" do
      FeatureFlag.build("Test Flag", true)
      |> Repo.insert()

      assert FeatureFlags.enabled?("Test Flag")
    end
  end

  describe "enable/1" do
    test "returns false if the flag does not already exist" do
      before_flag = get("Test Flag")
      flag = FeatureFlags.enable("Test Flag")

      assert nil == before_flag
      assert flag == false
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
    test "returns false if the flag does not already exist" do
      before_flag = get("Test Flag")
      flag = FeatureFlags.disable("Test Flag")

      assert nil == before_flag
      assert flag == false
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
