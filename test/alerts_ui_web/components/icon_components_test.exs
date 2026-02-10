defmodule AlertsUIWeb.IconComponentsTest do
  use ExUnit.Case, async: true

  import Mock
  import AlertsUIWeb.IconComponents
  import Phoenix.LiveViewTest

  alias MBTAV3API.Routes.Repo, as: RoutesRepo

  describe "mode_icon/1" do
    test "generates an svg or a stylized span element for the requested icon type" do
      with_mock(RoutesRepo,
        get: fn
          "Green-B" -> %{long_name: "Green Line B"}
          "Green-C" -> %{long_name: "Green Line C"}
          "Green-D" -> %{long_name: "Green Line D"}
          "Green-E" -> %{long_name: "Green Line E"}
          "Mattapan" -> %{long_name: "Mattapan Whatever"}
          "CR-Haverhill" -> %{long_name: "Haverhill Line"}
          "Boat-F4" -> %{long_name: "Charlestown Ferry"}
          "131" -> %{name: "131"}
          "746" -> %{name: "SLW"}
        end
      ) do
        assert render_component(&mode_icon/1, type: "Systemwide") =~ "<div"
        assert render_component(&mode_icon/1, type: "Red") =~ "<div"
        assert render_component(&mode_icon/1, type: "Blue") =~ "<div"
        assert render_component(&mode_icon/1, type: "Orange") =~ "<div"
        assert render_component(&mode_icon/1, type: "Green") =~ "<div"
        assert render_component(&mode_icon/1, type: "Mattapan") =~ "<div"
        assert render_component(&mode_icon/1, type: "Green-B") =~ "<div"
        assert render_component(&mode_icon/1, type: "Green-C") =~ "<div"
        assert render_component(&mode_icon/1, type: "Green-D") =~ "<div"
        assert render_component(&mode_icon/1, type: "Green-E") =~ "<div"
        assert render_component(&mode_icon/1, type: "CR-Haverhill") =~ "<div"
        assert render_component(&mode_icon/1, type: "Boat-F4") =~ "<div"
        assert render_component(&mode_icon/1, type: "131") =~ "<div"
        assert render_component(&mode_icon/1, type: "746") =~ "<div"
      end
    end
  end

  describe "circle_icon/1" do
    test "generates an svg or a stylized span element for the requested icon type" do
      assert_rendered(circle_icon(%{type: :bus}), "<svg")
      assert_rendered(circle_icon(%{type: :subway}), "<svg")
      assert_rendered(circle_icon(%{type: :commuter_rail}), "<svg")
      assert_rendered(circle_icon(%{type: :ferry}), "<svg")
      assert_rendered(circle_icon(%{type: :systemwide}), "<svg")
      assert_rendered(circle_icon(%{type: :facility}), "<svg")
      assert_rendered(circle_icon(%{type: "Red Line"}), "<svg")
      assert_rendered(circle_icon(%{type: "Blue Line"}), "<svg")
      assert_rendered(circle_icon(%{type: "Orange Line"}), "<svg")
      assert_rendered(circle_icon(%{type: "Green Line B"}), "<svg")
      assert_rendered(circle_icon(%{type: "Green Line C"}), "<svg")
      assert_rendered(circle_icon(%{type: "Green Line D"}), "<svg")
      assert_rendered(circle_icon(%{type: "Green Line E"}), "<svg")
      assert_rendered(circle_icon(%{type: "Green Line"}), "<svg")
      assert_rendered(circle_icon(%{type: "Mattapan Whatever Else"}), "<svg")
      assert_rendered(circle_icon(%{type: "using_escalator"}), "<span")
      assert_rendered(circle_icon(%{type: "using_wheelchair"}), "<span")
      assert_rendered(circle_icon(%{type: "park_car"}), "<span")
      assert_rendered(circle_icon(%{type: "bike"}), "<span")
      assert_rendered(circle_icon(%{type: "CR-Haverhill"}), "<span")
      assert_rendered(circle_icon(%{type: "131"}), "<span")
      assert_rendered(circle_icon(%{type: "Other"}), "<span")
    end
  end

  defp assert_rendered(result, pattern) do
    assert %Phoenix.LiveView.Rendered{static: static} = result
    assert Enum.any?(static, fn output -> output =~ pattern end)
  end
end
