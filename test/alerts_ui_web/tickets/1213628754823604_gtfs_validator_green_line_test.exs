defmodule AlertsUIWeb.Tickets.GtfsValidatorGreenLineTest do
  @moduledoc """
  Regression test for Asana ticket 1213628754823604 —
  "🐛 GTFS validator says Green Line no longer exists"
  https://app.asana.com/0/1167196461144361/1213628754823604

  Bug: `AlertValidator.validate_alerts/0` was falsely reporting the virtual
  "Green" route as invalid in GTFS validation emails. The MBTA V3 API does not
  return a route with id "Green" (the actual routes are the individual branches
  Green-B, Green-C, Green-D, Green-E), so the call to `RoutesRepo.all/2`
  filtered by `"Green"` returned nothing — causing the validator to incorrectly
  flag "Green" as an obsolete/upcoming entity.

  Fix (commit b6330e1c): `AlertValidator.invalid_routes/2` now pipes through
  `maybe_include_virtual_green_line/2`, which injects `RoutesRepo.green_line()`
  (the virtual %Route{id: "Green"} struct) into the found routes whenever
  "Green" is among the route IDs being validated, so the diff `route_ids --
  found_route_ids` no longer includes "Green".

  Acceptance criteria: Alerts for the "Green" line no longer produce obsolete
  "upcoming GTFS" entity emails — verified here by asserting that
  `validate_alerts/0` excludes "Green" from its `invalid_routes` result even
  when the API mock returns only non-Green routes.
  """

  use AlertsUIWeb.ConnCase, async: false
  import AlertsUI.Support.Factory
  import Mock

  alias AlertsUI.AlertValidation.AlertValidator
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route

  describe "GTFS validator (ticket 1213628754823604)" do
    test "does not flag Green Line route as invalid when API returns no route with id 'Green'" do
      # Simulate the scenario that caused the bug: an open alert has an
      # informed entity with route_id "Green", but the MBTA V3 API's
      # `filter[id]=Green` call returns nothing (only non-Green routes are
      # returned). Without the fix, "Green" ends up in invalid_routes.
      with_mocks([
        {RoutesRepo, [],
         [
           # The API returns routes for other IDs but nothing for "Green" itself.
           all: fn ["filter[id]": _filter], [reject_hidden: false, base_url: _, api_key: _] ->
             [%Route{id: "Red", type: 1}]
           end,
           green_line: fn ->
             %Route{id: "Green", name: "Green Line", type: 0}
           end
         ]}
      ]) do
        insert(:alert, %{
          alert_id: "green-test-alert",
          informed_entity: [
            %{route_type: 1, route_id: "Green"},
            %{route_type: 1, route_id: "Red"}
          ]
        })

        results = AlertValidator.validate_alerts()

        # No alert should appear in the invalid list — "Green" must NOT be
        # classified as invalid, and "Red" was returned by the mock so it's valid.
        assert results == [],
               "Expected no invalid alerts, got: #{inspect(results)}. " <>
                 "If 'Green' appears in invalid_routes, the virtual Green Line is " <>
                 "not being injected into the found-routes list (regression of ticket 1213628754823604)."
      end
    end

    test "still detects truly invalid (non-Green) routes alongside a valid Green route" do
      # Confirm the fix does not suppress legitimate invalid route findings:
      # if an alert has both "Green" (valid virtual route) and "Fake-99"
      # (not returned by the API), only "Fake-99" should appear as invalid.
      with_mocks([
        {RoutesRepo, [],
         [
           all: fn ["filter[id]": _filter], [reject_hidden: false, base_url: _, api_key: _] ->
             # API returns nothing; "Green" is still covered by the virtual route injection.
             []
           end,
           green_line: fn ->
             %Route{id: "Green", name: "Green Line", type: 0}
           end
         ]}
      ]) do
        insert(:alert, %{
          alert_id: "mixed-test-alert",
          informed_entity: [
            %{route_type: 1, route_id: "Green"},
            %{route_type: 3, route_id: "Fake-99"}
          ]
        })

        results = AlertValidator.validate_alerts()

        assert length(results) == 1, "Expected exactly one alert with invalid entities"

        [%{alert_id: alert_id, invalid_routes: invalid_routes}] = results
        assert alert_id == "mixed-test-alert"

        assert "Fake-99" in invalid_routes,
               "Expected 'Fake-99' to be flagged as invalid"

        refute "Green" in invalid_routes,
               "Green must NOT be flagged as invalid (regression of ticket 1213628754823604)"
      end
    end
  end
end
