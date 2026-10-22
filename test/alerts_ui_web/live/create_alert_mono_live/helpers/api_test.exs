defmodule AlertsUIWeb.CreateAlertLive.Helpers.APITest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AlertsUIWeb.CreateAlertLive.Helpers.API

  describe "async_available/1" do
    test "returns the result when ok? is true" do
      assert API.async_available(%{ok?: true, result: ["a", "b"]}) == ["a", "b"]
    end

    test "returns false when ok? is false" do
      assert API.async_available(%{ok?: false, result: ["a"]}) == false
    end

    test "returns nil when ok? is true and result is nil" do
      assert API.async_available(%{ok?: true, result: nil}) == nil
    end
  end

  describe "async_available?/1" do
    test "returns false for any argument" do
      assert API.async_available?(nil) == false
      assert API.async_available?(%{ok?: true, result: "x"}) == false
      assert API.async_available?("anything") == false
    end
  end
end
