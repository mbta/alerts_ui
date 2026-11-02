defmodule AlertsUIWeb.Tickets.DescriptionAutotextInboundOnlyStopTest do
  @moduledoc """
  Regression test for Asana ticket 1213857569129036 —
  "🐛 Description auto-text erroneously adds stops to wrong direction upon auto-refresh"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213857569129036

  Bug: when a bus detour alert is created with a stop that only serves one direction
  (e.g. "Ring Rd @ Boylston St (inbound)"), clicking "Auto refresh" on the edit page
  erroneously adds the stop to the outbound section of the auto-generated description
  text, producing:

      Skipped outbound stops:
      Ring Rd @ Boylston St

      Skipped inbound stops:
      Ring Rd @ Boylston St

  Expected behavior: since the stop has "(inbound)" in its name — indicating it only
  serves the inbound direction — auto-refresh should produce only the inbound section:

      Skipped inbound stops:
      Ring Rd @ Boylston St

  The root of the issue is in `BuildDescriptionText.stops_by_direction/3`, which filters
  stops for each direction. A stop named "Ring Rd @ Boylston St (inbound)" should be
  excluded from the outbound list because it has a direction marker in parentheses that
  does NOT include "outbound". This test pins that behavior at the unit level so a
  regression immediately surfaces.
  """
  use ExUnit.Case, async: true

  alias AlertsUIWeb.CreateAlertLive.Helpers.AutoText.BuildDescriptionText

  # A stop that only serves the inbound direction (has "(inbound)" in its name)
  @inbound_only_stop %{name: "Ring Rd @ Boylston St (inbound)"}

  # A stop that serves both directions (no direction qualifier in its name)
  @bidirectional_stop %{name: "Franklin St @ Sydney St"}

  # A stop that only serves the outbound direction
  @outbound_only_stop %{name: "Centre St @ Eliot St (outbound)"}

  describe "affected_stops/1 for bus detour (route_type 3)" do
    test "inbound-only stop does NOT appear in outbound section" do
      autotext_data = %{
        stops: [@inbound_only_stop],
        effect_name: "Detour",
        route_type: 3
      }

      result = BuildDescriptionText.affected_stops(autotext_data)

      # The stop is inbound-only — the outbound section must be absent
      refute String.contains?(result, "outbound"),
             "Expected no outbound section for an inbound-only stop, got: #{inspect(result)}"

      assert String.contains?(result, "inbound"),
             "Expected inbound section to be present, got: #{inspect(result)}"

      assert result == "Skipped inbound stops:\nRing Rd @ Boylston St",
             "Expected only 'Skipped inbound stops:\\nRing Rd @ Boylston St', got: #{inspect(result)}"
    end

    test "outbound-only stop does NOT appear in inbound section" do
      autotext_data = %{
        stops: [@outbound_only_stop],
        effect_name: "Detour",
        route_type: 3
      }

      result = BuildDescriptionText.affected_stops(autotext_data)

      refute String.contains?(result, "inbound"),
             "Expected no inbound section for an outbound-only stop, got: #{inspect(result)}"

      assert String.contains?(result, "outbound"),
             "Expected outbound section to be present, got: #{inspect(result)}"

      assert result == "Skipped outbound stops:\nCentre St @ Eliot St",
             "Expected only 'Skipped outbound stops:\\nCentre St @ Eliot St', got: #{inspect(result)}"
    end

    test "bidirectional stop (no direction qualifier) appears in both sections" do
      autotext_data = %{
        stops: [@bidirectional_stop],
        effect_name: "Detour",
        route_type: 3
      }

      result = BuildDescriptionText.affected_stops(autotext_data)

      assert String.contains?(result, "outbound"),
             "Expected outbound section for a bidirectional stop, got: #{inspect(result)}"

      assert String.contains?(result, "inbound"),
             "Expected inbound section for a bidirectional stop, got: #{inspect(result)}"
    end

    test "mixed stops: inbound-only stop appears only in inbound section alongside a bidirectional stop" do
      # This is the specific scenario from the ticket:
      # Route 39, Ring Rd @ Boylston St is inbound-only.
      # Previously, auto-refresh would produce BOTH inbound and outbound sections for it.
      autotext_data = %{
        stops: [@inbound_only_stop, @bidirectional_stop],
        effect_name: "Detour",
        route_type: 3
      }

      result = BuildDescriptionText.affected_stops(autotext_data)

      # Ring Rd should appear in inbound but NOT in outbound
      lines = String.split(result, "\n")
      outbound_section_start = Enum.find_index(lines, &String.contains?(&1, "outbound"))
      inbound_section_start = Enum.find_index(lines, &String.contains?(&1, "inbound"))

      assert outbound_section_start != nil,
             "Expected an outbound section (for the bidirectional stop)"

      assert inbound_section_start != nil, "Expected an inbound section"

      # The stop names in each section
      outbound_stops_lines =
        if outbound_section_start do
          lines
          |> Enum.drop(outbound_section_start + 1)
          |> Enum.take_while(&(not String.contains?(&1, "stops:") and &1 != ""))
        else
          []
        end

      inbound_stops_lines =
        if inbound_section_start do
          lines
          |> Enum.drop(inbound_section_start + 1)
          |> Enum.take_while(&(not String.contains?(&1, "stops:") and &1 != ""))
        else
          []
        end

      # Ring Rd @ Boylston St must NOT be in outbound section
      refute Enum.any?(outbound_stops_lines, &String.contains?(&1, "Ring Rd @ Boylston St")),
             "Ring Rd @ Boylston St (inbound-only) must not appear in outbound section.\nFull result: #{inspect(result)}"

      # Ring Rd @ Boylston St must be in inbound section
      assert Enum.any?(inbound_stops_lines, &String.contains?(&1, "Ring Rd @ Boylston St")),
             "Ring Rd @ Boylston St must appear in inbound section.\nFull result: #{inspect(result)}"

      # Franklin St (bidirectional) must be in outbound section
      assert Enum.any?(outbound_stops_lines, &String.contains?(&1, "Franklin St @ Sydney St")),
             "Franklin St @ Sydney St (bidirectional) must appear in outbound section.\nFull result: #{inspect(result)}"
    end
  end
end
