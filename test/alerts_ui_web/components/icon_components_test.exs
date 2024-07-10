defmodule AlertsUIWeb.IconComponentsTest do
  use ExUnit.Case, async: true

  import AlertsUIWeb.IconComponents

  describe "icon/1" do
    test "generates an svg or a stylized span element for the requested icon type" do
      assert_rendered(mode_icon(%{type: :BUS}), "<svg")
      assert_rendered(mode_icon(%{type: :SUBWAY}), "<svg")
      assert_rendered(mode_icon(%{type: :COMMUTER_RAIL}), "<svg")
      assert_rendered(mode_icon(%{type: :FERRY}), "<svg")
      assert_rendered(mode_icon(%{type: :SYSTEMWIDE}), "<svg")
      assert_rendered(mode_icon(%{type: :ACCESS}), "<svg")
      assert_rendered(mode_icon(%{type: "Red Line"}), "<svg")
      assert_rendered(mode_icon(%{type: "Blue Line"}), "<svg")
      assert_rendered(mode_icon(%{type: "Orange Line"}), "<svg")
      assert_rendered(mode_icon(%{type: "Green Line B"}), "<svg")
      assert_rendered(mode_icon(%{type: "Green Line C"}), "<svg")
      assert_rendered(mode_icon(%{type: "Green Line D"}), "<svg")
      assert_rendered(mode_icon(%{type: "Green Line E"}), "<svg")
      assert_rendered(mode_icon(%{type: "Green Line"}), "<svg")
      assert_rendered(mode_icon(%{type: "Mattapan Trolley"}), "<svg")
      assert_rendered(mode_icon(%{type: :USING_ESCALATOR}), "<span")
      assert_rendered(mode_icon(%{type: :USING_WHEELCHAIR}), "<span")
      assert_rendered(mode_icon(%{type: :PARK_CAR}), "<span")
      assert_rendered(mode_icon(%{type: :BIKE}), "<span")
      assert_rendered(mode_icon(%{type: "CR-Haverhill"}), "<span")
      assert_rendered(mode_icon(%{type: "131"}), "<span")
      assert_rendered(mode_icon(%{type: "Other"}), "<span")
    end
  end

  defp assert_rendered(result, pattern) do
    assert %Phoenix.LiveView.Rendered{static: static} = result
    assert Enum.any?(static, fn output -> output =~ pattern end)
  end
end
