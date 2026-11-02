defmodule AlertsUIWeb.CreateAlertLive.Helpers.ValueTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AlertsUIWeb.CreateAlertLive.Helpers.Value

  describe "blank?/1" do
    test "returns true for nil" do
      assert Value.blank?(nil) == true
    end

    test "returns true for an empty string" do
      assert Value.blank?("") == true
    end

    test "returns false for a non-empty string" do
      assert Value.blank?("x") == false
    end

    test "returns false for an integer (including zero)" do
      assert Value.blank?(0) == false
      assert Value.blank?(42) == false
    end

    test "returns false for an empty list" do
      assert Value.blank?([]) == false
    end

    test "returns false for a non-empty list" do
      assert Value.blank?([1]) == false
    end

    test "returns false for a map" do
      assert Value.blank?(%{}) == false
    end
  end
end
