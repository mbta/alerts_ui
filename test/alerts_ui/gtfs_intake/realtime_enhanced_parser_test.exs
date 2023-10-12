defmodule AlertsUI.GTFSIntake.RealtimeEnhancedParserTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import Test.Support.Helpers
  alias AlertsUI.GTFSIntake.RealtimeEnhancedParser
  # alias AlertsUI.Models.Alert

  describe "parse/1" do
    test "parsing an enhanced Alerts JSON file returns Alert structs" do
      binary = File.read!(fixture_path("alerts_enhanced.json"))
      parsed = RealtimeEnhancedParser.parse(binary)
      assert is_list(parsed)
    end
  end
end
