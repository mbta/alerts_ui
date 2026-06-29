defmodule AlertsUIWeb.Tickets.FacilityAlertsCorrectCauseTest do
  @moduledoc """
  Regression test for Asana ticket 1213545400300573
  "🐛 Manual facility alerts outputting wrong `cause`"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213545400300573

  Bug: Manually-created facility (ACCESS) alerts with a selected `cause_detail` of
  "MAINTENANCE" were output in the feed with `cause_detail: "MAINTENANCE"` but
  `cause: UNKNOWN_CAUSE`. The root cause: `AlertBuilder.cause_and_effect/1` called
  `Cause.get_by_mode_and_detail(nil, "MAINTENANCE")` for ACCESS alerts (because
  `route_type` is `nil` for facility alerts), which looked up "MAINTENANCE" in the
  *systemwide* cause map — a map that does not contain "MAINTENANCE", returning `nil`
  → `:UNKNOWN_CAUSE`.

  Fix (commit ffa8cdd6, PR #925): `cause_and_effect/1` now detects
  `route_type: nil, combination: :ACCESS` and promotes `route_type` to `:ACCESS` before
  the lookup, ensuring `Cause.get_by_mode_and_detail(:ACCESS, "MAINTENANCE")` returns
  the correct `:MAINTENANCE`.

  Tests:
    * Elevator Closure with cause_detail "MAINTENANCE" → cause must be :MAINTENANCE
    * Escalator Closure with cause_detail "MAINTENANCE" → cause must be :MAINTENANCE
    * ACCESS alert with cause_detail "ELECTRICAL_WORK" → cause must be :MAINTENANCE
    * ACCESS alert with cause_detail "CONSTRUCTION" → cause must be :CONSTRUCTION
    * ACCESS alert with empty cause_detail → cause must be :UNKNOWN_CAUSE (unchanged baseline)
    * Non-ACCESS nil route_type (systemwide) with cause_detail "MAINTENANCE" remains
      :UNKNOWN_CAUSE — the fix must not affect systemwide alerts.
  """
  use AlertsUI.DataCase
  import Mock

  alias AlertsUI.AlertBuilder
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  @elevator_facility %Facility{
    id: "717",
    type: "ELEVATOR",
    short_name: "Platform to Foley Street paid lobby",
    long_name: "Assembly Elevator 717 (Platform to Foley Street paid lobby)"
  }

  @escalator_facility %Facility{
    id: "301",
    type: "ESCALATOR",
    short_name: "Alewife platform to lobby",
    long_name: "Andrew Escalator 301 (Alewife platform to lobby)"
  }

  defp base_access_alert_data(overrides) do
    Map.merge(
      %{
        route_type: nil,
        header_text: "Elevator unavailable.",
        effect_name: "Elevator Closure",
        effect: "ACCESSIBILITY_ISSUE",
        effect_detail: "ELEVATOR_CLOSURE",
        facility_ids: ["717"],
        active_period_start: ~N[2024-04-30 11:54:00],
        active_period_end: ~N[2024-04-30 13:54:00],
        alert_timing: :"one-time",
        active_period_end_specifier: :later_today,
        active_period_start_specifier: :custom,
        notification_period_start: ~N[2024-04-30 05:52:00],
        notification_period_end: ~N[2025-10-13 17:00:00],
        severity: 3,
        combination: :ACCESS
      },
      overrides
    )
  end

  describe "facility alert cause field in feed output" do
    test "Elevator Closure with MAINTENANCE cause_detail outputs cause :MAINTENANCE (not :UNKNOWN_CAUSE)" do
      with_mocks([
        {FacilitiesRepo, [], [get: fn _id -> @elevator_facility end]},
        {StopsRepo, [], [all: fn ["filter[id]": ""], _opts -> [] end]}
      ]) do
        alert_data = base_access_alert_data(%{cause_detail: "MAINTENANCE"})

        result = AlertBuilder.build_alert(alert_data, :ACCESS, ~U[2024-04-30 11:54:00Z])

        assert result.cause == :MAINTENANCE,
               "Expected cause :MAINTENANCE for ACCESS Elevator Closure with cause_detail MAINTENANCE, got #{inspect(result.cause)}"
      end
    end

    test "Escalator Closure with MAINTENANCE cause_detail outputs cause :MAINTENANCE" do
      with_mocks([
        {FacilitiesRepo, [], [get: fn _id -> @escalator_facility end]},
        {StopsRepo, [], [all: fn ["filter[id]": ""], _opts -> [] end]}
      ]) do
        alert_data =
          base_access_alert_data(%{
            cause_detail: "MAINTENANCE",
            effect_name: "Escalator Closure",
            effect_detail: "ESCALATOR_CLOSURE",
            facility_ids: ["301"]
          })

        result = AlertBuilder.build_alert(alert_data, :ACCESS, ~U[2024-04-30 11:54:00Z])

        assert result.cause == :MAINTENANCE
      end
    end

    test "ACCESS alert with ELECTRICAL_WORK cause_detail outputs cause :MAINTENANCE" do
      with_mocks([
        {FacilitiesRepo, [], [get: fn _id -> @elevator_facility end]},
        {StopsRepo, [], [all: fn ["filter[id]": ""], _opts -> [] end]}
      ]) do
        alert_data = base_access_alert_data(%{cause_detail: "ELECTRICAL_WORK"})

        result = AlertBuilder.build_alert(alert_data, :ACCESS, ~U[2024-04-30 11:54:00Z])

        assert result.cause == :MAINTENANCE
      end
    end

    test "ACCESS alert with CONSTRUCTION cause_detail outputs cause :CONSTRUCTION" do
      with_mocks([
        {FacilitiesRepo, [], [get: fn _id -> @elevator_facility end]},
        {StopsRepo, [], [all: fn ["filter[id]": ""], _opts -> [] end]}
      ]) do
        alert_data = base_access_alert_data(%{cause_detail: "CONSTRUCTION"})

        result = AlertBuilder.build_alert(alert_data, :ACCESS, ~U[2024-04-30 11:54:00Z])

        assert result.cause == :CONSTRUCTION
      end
    end

    test "ACCESS alert with empty cause_detail outputs :UNKNOWN_CAUSE (baseline unchanged)" do
      with_mocks([
        {FacilitiesRepo, [], [get: fn _id -> @elevator_facility end]},
        {StopsRepo, [], [all: fn ["filter[id]": ""], _opts -> [] end]}
      ]) do
        alert_data = base_access_alert_data(%{cause_detail: ""})

        result = AlertBuilder.build_alert(alert_data, :ACCESS, ~U[2024-04-30 11:54:00Z])

        assert result.cause == :UNKNOWN_CAUSE
      end
    end

    test "fix does not affect systemwide alerts: nil route_type without :ACCESS combination still uses systemwide cause map" do
      # Systemwide alerts also have route_type: nil. The fix must only activate
      # when combination == :ACCESS. Systemwide map has no "MAINTENANCE" entry,
      # so result.cause should NOT be :MAINTENANCE (it returns nil for unknown entries).
      # This test guards against over-applying the fix.
      with_mocks([
        {StopsRepo, [], [all: fn ["filter[id]": ""], _opts -> [] end]}
      ]) do
        alert_data = %{
          route_type: nil,
          header_text: "System-wide notice.",
          effect_name: "Delay",
          cause_detail: "MAINTENANCE",
          effect: "SIGNIFICANT_DELAYS",
          effect_detail: "DELAY",
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end: ~N[2024-04-30 13:54:00],
          alert_timing: :"one-time",
          active_period_end_specifier: :later_today,
          active_period_start_specifier: :custom,
          notification_period_start: ~N[2024-04-30 05:52:00],
          notification_period_end: ~N[2025-10-13 17:00:00],
          severity: 3
          # No combination: :ACCESS → systemwide behavior, no :ACCESS key in alert_data
        }

        result = AlertBuilder.build_alert(alert_data, nil, ~U[2024-04-30 11:54:00Z])

        # Systemwide cause map has no "MAINTENANCE" entry → returns nil (not :MAINTENANCE).
        # The fix must NOT promote systemwide alerts to :ACCESS. If it did, result.cause would
        # be :MAINTENANCE, which would be incorrect for a true systemwide alert.
        refute result.cause == :MAINTENANCE,
               "Systemwide alert with nil combination must NOT get :MAINTENANCE cause (fix must not affect systemwide alerts)"
      end
    end
  end
end
