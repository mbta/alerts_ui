defmodule AlertsUIWeb.FormComponents.Helpers.AutoTextTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUIWeb.FormComponents.Helpers.AutoText

  describe "build_header_auto_text/1" do
  end

  describe "build_description_auto_text/1" do
  end

  describe "cause/1" do
    test "definite article" do
      expected = "the holiday"
      actual = AutoText.cause("HOLIDAY")
      assert expected == actual
    end

    test "indefinite article with vowel" do
      expected = "an unruly passenger"
      actual = AutoText.cause("UNRULY_PASSENGER")
      assert expected == actual
    end

    test "indefinite article no vowel" do
      expected = "a slippery rail"
      actual = AutoText.cause("SLIPPERY_RAIL")
      assert expected == actual
    end

    test "no article no vowel" do
      expected = "heavy ridership"
      actual = AutoText.cause("HEAVY_RIDERSHIP")
      assert expected == actual
    end
  end

  describe "severity/1" do
    test "returns severity description for severity integer" do
      expected = "up to 10 minutes"
      actual = AutoText.severity(3)
      assert expected == actual
    end
  end
end
