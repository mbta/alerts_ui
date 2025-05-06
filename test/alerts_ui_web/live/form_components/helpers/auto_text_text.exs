defmodule AlertsUIWeb.FormComponents.Helpers.AutoTextTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUIWeb.FormComponents.Helpers.AutoText
  alias MBTAV3API.Stops.Stop

  @stop_1 %Stop{id: "place-lech", name: "Lechmere"}
  @stop_2 %Stop{id: "place-lngmd", name: "Longwood Medical Area"}
  @stop_3 %Stop{id: "place-masta", name: "Massachusetts Avenue"}
  @stop_4 %Stop{id: "place-matt", name: "Mattapan"}

  describe "build_header_auto_text/1" do
  end

  describe "build_description_auto_text/1" do
  end

  describe "cause/1" do
    test "when cause is empty" do
      assert AutoText.cause("") == ""
    end

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
    test "when severity is nil" do
      assert AutoText.severity(nil) == ""
    end

    test "returns severity description for severity integer" do
      expected = "up to 10 minutes"
      actual = AutoText.severity(3)
      assert expected == actual
    end
  end

  describe "service_types/1" do
    test "service types empty" do
      assert AutoText.service_types([]) == ""
    end

    test "one service type" do
      expected = "Commuter Rail"
      actual = AutoText.service_types([2])
      assert expected == actual
    end

    test "two service types" do
      expected = "Ferry and Commuter Rail"
      actual = AutoText.service_types([4, 2])
      assert expected == actual
    end

    test "more than two service types" do
      expected = "Subway, Bus, Ferry, and Commuter Rail"
      actual = AutoText.service_types([1, 3, 4, 2])
      assert expected == actual
    end
  end

  describe "stops/1" do
    test "stops empty" do
      assert AutoText.stops([]) == ""
    end

    test "one stop" do
      expected = "Lechmere"
      actual = AutoText.stops([@stop_1])
      assert expected == actual
    end

    test "two stops" do
      expected = "Lechmere and Longwood Medical Area"
      actual = AutoText.stops([@stop_1, @stop_2])
      assert expected == actual
    end

    test "more than two stops" do
      expected = "Lechmere, Longwood Medical Area, Massachusetts Avenue, and Mattapan"
      actual = AutoText.stops([@stop_1, @stop_2, @stop_3, @stop_4])
      assert expected == actual
    end
  end

  describe "stop_form/1" do
    test "stops empty" do
      assert AutoText.stop_form([]) == ""
    end

    test "one stop" do
      assert AutoText.stop_form([@stop_1]) == "stop is"
    end

    test "multiple stops" do
      assert AutoText.stop_form([@stop_1, @stop_2]) == "stops are"
    end
  end
end
