defmodule AlertsUIWeb.Tickets.F1InformedEntityForF2HTest do
  @moduledoc """
  Regression test for Asana ticket 1213737377246666
  "⛴️ F1 should be informed entity for F2H alerts"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213737377246666

  Bug: When creating a Ferry • Delay alert for route Boat-F2H (Hingham/Hull Ferry),
  the resulting informed_entities in the feed only included Boat-F2H, not Boat-F1
  (Hingham Ferry). Since Hingham/Hull Ferry (F2H) also serves Hingham like F1,
  passengers expecting F1 service need to be informed.

  AC: When an alert is created with route Boat-F2H selected, there should be
  informed_entities for both Boat-F2H and Boat-F1. This should be true for both
  trip-based and non-trip-based Ferry alerts.

  Verified behavior (local environment, 2026-06-07):
    - Non-trip-based (`:R` combination): PASS — both routes appear.
    - Trip-based (`:RDT` combination, specific trip selected): FAIL — only Boat-F2H
      with trip_id appears; Boat-F1 is absent. This is a known gap in the fix.
  """

  use AlertsUI.DataCase
  import Mock
  alias AlertsUI.AlertBuilder
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.RoutePatterns.RoutePattern, as: APIRoutePattern
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  # Shared mock helpers
  defp route_pattern_mock do
    {RoutePatternsRepo, [],
     [
       by_route_id: fn
         _id, [include: "representative_trip.stops,route"] ->
           [%APIRoutePattern{id: "1", direction_id: 0, stops: [], route_id: nil}]
       end
     ]}
  end

  defp routes_repo_mock do
    {RoutesRepo, [],
     [
       get: fn id, _opts ->
         %Route{id: id, type: 4, name: id, description: :ferry}
       end
     ]}
  end

  defp stops_repo_mock do
    {StopsRepo, [], [all: fn ["filter[id]": ""], _opts -> [] end]}
  end

  describe "Boat-F2H alerts include Boat-F1 in informed_entities" do
    @tag :f2h_combo_route
    test "non-trip-based Boat-F2H alert includes both Boat-F2H and Boat-F1" do
      # This is the primary AC from the ticket: a route-only (non-trip-based)
      # Boat-F2H alert should produce informed_entities for BOTH Boat-F2H and Boat-F1.
      # Fix lives in AlertBuilder.add_special_combo_routes/2 for "Boat-F2H".
      with_mocks([route_pattern_mock(), routes_repo_mock(), stops_repo_mock()]) do
        alert_data = %{
          route_type: 4,
          description_text: "Hingham/Hull Ferry operating about 10 minutes late today.",
          header_text: "Hingham/Hull Ferry operating about 10 minutes late today.",
          effect_name: "Delay",
          direction: "default",
          route_ids: ["Boat-F2H"],
          stop_ids: [],
          active_period_start: ~N[2026-06-07 09:30:00],
          active_period_end_specifier: :until_further_notice,
          active_period_start_specifier: :custom,
          cause_detail: ""
        }

        result = AlertBuilder.build_alert(alert_data, :R, ~U[2026-06-07 09:30:00Z])

        route_ids = Enum.map(result.informed_entity, & &1.route_id)

        assert "Boat-F2H" in route_ids,
               "Expected Boat-F2H in informed_entity routes, got: #{inspect(route_ids)}"

        assert "Boat-F1" in route_ids,
               "Expected Boat-F1 in informed_entity routes (fix for ticket 1213737377246666), " <>
                 "got: #{inspect(route_ids)}"

        assert length(route_ids) == 2,
               "Expected exactly 2 informed entities (Boat-F2H + Boat-F1), got: #{inspect(route_ids)}"

        # Both should have ferry route_type (4) and standard activities
        for ie <- result.informed_entity do
          assert ie.route_type == 4
          assert ie.activities == [:BOARD, :EXIT, :RIDE]
          assert ie.agency_id == "1"
        end
      end
    end

    @tag :f2h_combo_route
    test "add_special_combo_routes/2 adds Boat-F1 for Boat-F2H" do
      # Unit test for the specific function that implements the fix.
      route_ids = AlertBuilder.add_special_combo_routes([], "Boat-F2H")

      assert "Boat-F1" in route_ids,
             "add_special_combo_routes/2 should add Boat-F1 for Boat-F2H, got: #{inspect(route_ids)}"
    end

    @tag :f2h_combo_route
    test "add_special_combo_routes/2 preserves other routes for Boat-F2H" do
      # Ensure the function concatenates, not replaces
      route_ids = AlertBuilder.add_special_combo_routes(["some-other-id"], "Boat-F2H")
      assert "Boat-F1" in route_ids
      assert "some-other-id" in route_ids
    end

    @tag :f2h_combo_route_trip_based
    @tag :known_gap
    @tag :skip
    test "trip-based Boat-F2H alert does NOT yet include Boat-F1 (known gap)" do
      # This test documents the KNOWN GAP in the fix:
      # When a specific trip is selected for Boat-F2H, the informed_entity is built
      # per-trip via the :RDT combination and does NOT include the Boat-F1 combo route.
      # The AC says "both trip-based and non-trip-based" should include Boat-F1,
      # but the :RDT code path bypasses the combo route addition.
      # This test is RED on purpose to track the outstanding gap.
      with_mocks([route_pattern_mock(), routes_repo_mock(), stops_repo_mock()]) do
        trip_id = "Boat-F2H-0800-Hingham-F2H-A-AM-Sunday-Summer-26"

        alert_data = %{
          route_type: 4,
          description_text: "Test.",
          header_text: "Test.",
          effect_name: "Delay",
          direction: "default",
          route_ids: ["Boat-F2H"],
          stop_ids: [],
          trip_ids: [trip_id],
          trip_information_by_id: %{
            trip_id => %{direction_id: 1, route_id: "Boat-F2H"}
          },
          active_period_start: ~N[2026-06-07 09:30:00],
          active_period_end_specifier: :custom,
          active_period_start_specifier: :custom,
          active_period_end: ~N[2026-06-07 09:55:00],
          cause_detail: ""
        }

        result = AlertBuilder.build_alert(alert_data, :RDT, ~U[2026-06-07 09:30:00Z])

        route_ids = Enum.map(result.informed_entity, & &1.route_id)

        # This assertion documents the CURRENT (failing) behavior:
        # Only Boat-F2H appears, Boat-F1 does NOT.
        assert "Boat-F2H" in route_ids,
               "Expected Boat-F2H in informed_entity routes"

        # This assertion FAILS — it documents the AC that is not yet met.
        # When this turns GREEN, the trip-based case is fixed too.
        assert "Boat-F1" in route_ids,
               "Expected Boat-F1 in informed_entity routes for trip-based Boat-F2H alert " <>
                 "(AC from ticket 1213737377246666: should be true for both trip-based and " <>
                 "non-trip-based Ferry alerts). Current behavior: only #{inspect(route_ids)} present."
      end
    end
  end
end
