defmodule AlertsUI.Helpers.DateTimeTest do
  use ExUnit.Case, async: true
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

      assert_raise RuntimeError, fn -> DTHelpers.new_protecting_gaps!(date, time, zone) end
    end
  end

  describe "new_round_up_to_gap!" do
    test "with a valid date and time" do
      date = ~D[2026-03-10]
      time = ~T[11:00:00]
      zone = "America/New_York"
      expected = DateTime.new!(date, time, zone)

      output = DTHelpers.new_round_up_to_gap!(date, time, zone)

      assert expected == output
    end

    test "with a date and time in a gap, it shifts the time forward to 3AM" do
      date = ~D[2024-03-10]
      time = ~T[02:30:00]
      zone = "America/New_York"
      expected = DateTime.new!(date, ~T[03:00:00], zone)

      output = DTHelpers.new_round_up_to_gap!(date, time, zone)

      assert expected == output
    end

    test "it raises if there is a different problem" do
      date = ~D[2026-03-10]
      time = ~T[02:30:00]
      zone = "LOL/Nowhere"

      assert_raise RuntimeError, fn -> DTHelpers.new_round_up_to_gap!(date, time, zone) end
    end
  end
end
