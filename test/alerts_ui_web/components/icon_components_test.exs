defmodule AlertsUIWeb.IconComponentsTest do
  use ExUnit.Case, async: true

  import AlertsUIWeb.IconComponents
  import Phoenix.LiveViewTest

  describe "icon/1" do
    test "generates an svg or a stylized span element for the requested icon type" do
      assert_rendered(mode_icon(%{type: :bus}), "<svg")
      assert_rendered(mode_icon(%{type: :subway}), "<svg")
      assert_rendered(mode_icon(%{type: :commuter_rail}), "<svg")
      assert_rendered(mode_icon(%{type: :ferry}), "<svg")
      assert_rendered(mode_icon(%{type: :systemwide}), "<svg")
      assert_rendered(mode_icon(%{type: :access}), "<svg")
      assert_rendered(mode_icon(%{type: "Systemwide"}), "<div")
      assert_rendered(mode_icon(%{type: "Red"}), "<div")
      assert_rendered(mode_icon(%{type: "Blue"}), "<div")
      assert_rendered(mode_icon(%{type: "Orange"}), "<div")
      assert_rendered(mode_icon(%{type: "Green"}), "<div")
      assert_rendered(mode_icon(%{type: "Mattapan"}), "<div")
      assert_rendered(mode_icon(%{type: "using_escalator"}), "<div")
      assert_rendered(mode_icon(%{type: :USING_WHEELCHAIR}), "<div")
      assert_rendered(mode_icon(%{type: :PARK_CAR}), "<div")
      assert_rendered(mode_icon(%{type: :STORE_BIKE}), "<div")
      assert_rendered(mode_icon(%{type: "CR-Haverhill"}), "<div")
      assert_rendered(mode_icon(%{type: "Boat-F4"}), "<div")
      assert_rendered(mode_icon(%{type: "131"}), "<div")

      assert render_component(&mode_icon/1, type: "Green-B") =~ "<div"
      assert render_component(&mode_icon/1, type: "Green-C") =~ "<div"
      assert render_component(&mode_icon/1, type: "Green-D") =~ "<div"
      assert render_component(&mode_icon/1, type: "Green-E") =~ "<div"
    end
  end

  defp assert_rendered(result, pattern) do
    assert %Phoenix.LiveView.Rendered{static: static} = result
    assert Enum.any?(static, fn output -> output =~ pattern end)
  end
end
