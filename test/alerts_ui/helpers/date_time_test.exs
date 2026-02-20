defmodule AlertsUI.Helpers.DateTimeTest do
  use ExUnit.Case, asyne: true
  alias AlertsUI.Helpers.DateTime, as: DTHelpers

  describe "new_protecting_gaps!" do
    test "with a valid date and time" do
      date = ~D[2026-03-10]
      time = ~T[11:00:00]
      zone = "America/New_York"
      expected = DateTime.new!(date, time, zone)

      output = DTHelpers.new_protecting_gaps!(date, time, zone)

      assert expected == output
    end

    test "with a date and time in a gap, it shifts the time forward" do
      date = ~D[2024-03-10]
      time = ~T[02:30:00]
      zone = "America/New_York"
      expected = DateTime.new!(date, ~T[03:30:00], zone)

      output = DTHelpers.new_protecting_gaps!(date, time, zone)

      assert expected == output
    end

    test "it raises if there is a different problem" do
      date = ~D[2026-03-10]
      time = ~T[02:30:00]
      zone = "LOL/Nowhere"

      try do
        DTHelpers.new_protecting_gaps!(date, time, zone)
        flunk("This should have raised!")
      rescue
        e -> assert e
      end
    end
  end
end
