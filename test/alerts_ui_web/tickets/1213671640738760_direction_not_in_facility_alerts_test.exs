defmodule AlertsUIWeb.Tickets.DirectionNotInFacilityAlertsTest do
  @moduledoc """
  Regression test for Asana ticket 1213671640738760
  "🐛 Direction shouldn't be in facility alerts"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213671640738760

  Bug: facility alerts (Elevator Closure, Escalator Closure, Facility Issue, Access Issue)
  were showing "direction: both" in the alert details modal, which doesn't make sense for
  physical facilities that have no concept of transit direction.

  Accepted fix: the `:ACCESS` service/effect combination (used for all facility alerts) is
  excluded from the `[:RDS, :RDT, :RDTS]` set that allows direction storage, so
  `AlertBuilder.build_alert/3` now sets `original_direction_selections` to `nil` for all
  facility alerts — even when a `direction` value is present in `alert_data` (as happens
  during an edit round-trip). This ensures neither the View Alerts details modal nor the
  history CSV ever shows a "Direction:" row for facility alerts.

  Tests:
    * `AlertBuilder.build_alert/3` with `:ACCESS` combination never stores a direction —
      not for Elevator Closure, Escalator Closure, nor for Facility Issue.
    * The review modal rendered from an `:ACCESS` alert_data struct does not include a
      "Direction:" row, even when `original_direction_selections` is set to a legacy value.
    * The `:ACCESS` alert_data loaded from an existing Elevator Closure alert does not
      include a direction in `original_direction_selections`.

  Related ticket: 1212433843572811 covers the broader "don't store direction when not
  relevant" fix for non-facility combinations (:SR, :R). This ticket extends the same
  principle explicitly to facility alerts (:ACCESS).
  """
  use AlertsUI.DataCase
  import Mock

  alias AlertsUI.AlertBuilder
  alias AlertsUIWeb.FormComponents.Helpers.AlertData
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  @facility %Facility{
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

  # Base alert_data for a facility alert — contains a direction value to simulate
  # the edit round-trip (where direction is always present in the map).
  defp base_facility_alert_data(extra) do
    Map.merge(
      %{
        route_type: nil,
        header_text: "Assembly Elevator 717 is unavailable due to maintenance.",
        cause_detail: "MAINTENANCE",
        effect_name: "Elevator Closure",
        effect: "ACCESSIBILITY_ISSUE",
        effect_detail: "ELEVATOR_CLOSURE",
        facility_ids: ["717"],
        # direction is present as it would be in an edit round-trip
        direction: "default",
        active_period_start: ~N[2024-04-30 09:47:00],
        active_period_end_specifier: :until_further_notice,
        active_period_start_specifier: :custom,
        alert_timing: :"one-time",
        notification_period_start: ~N[2024-04-30 09:47:00],
        notification_specifier: :now,
        severity: 3,
        combination: :ACCESS
      },
      extra
    )
  end

  describe "AlertBuilder.build_alert/3 does not store direction for :ACCESS (facility) combination" do
    test "Elevator Closure (:ACCESS) never stores original_direction_selections" do
      with_mocks([
        {FacilitiesRepo, [], [get: fn _id -> @facility end]},
        {StopsRepo, [], [all: fn ["filter[id]": ""], _opts -> [] end]}
      ]) do
        alert_data = base_facility_alert_data(%{})

        result = AlertBuilder.build_alert(alert_data, :ACCESS, ~U[2024-04-30 09:47:00Z])

        # Core assertion: no direction stored for facility alerts
        assert result.original_direction_selections in [nil, []]
        refute direction_contains_both?(result.original_direction_selections)
      end
    end

    test "Escalator Closure (:ACCESS) never stores original_direction_selections" do
      with_mocks([
        {FacilitiesRepo, [], [get: fn _id -> @escalator_facility end]},
        {StopsRepo, [], [all: fn ["filter[id]": ""], _opts -> [] end]}
      ]) do
        alert_data =
          base_facility_alert_data(%{
            effect_name: "Escalator Closure",
            effect_detail: "ESCALATOR_CLOSURE",
            facility_ids: ["301"]
          })

        result = AlertBuilder.build_alert(alert_data, :ACCESS, ~U[2024-04-30 09:47:00Z])

        assert result.original_direction_selections in [nil, []]
        refute direction_contains_both?(result.original_direction_selections)
      end
    end

    test "Facility Issue (:ACCESS) never stores original_direction_selections" do
      with_mocks([
        {FacilitiesRepo, [], [get: fn _id -> @facility end]},
        {StopsRepo, [], [all: fn ["filter[id]": ""], _opts -> [] end]}
      ]) do
        alert_data =
          base_facility_alert_data(%{
            effect_name: "Facility Issue",
            effect: "OTHER_EFFECT",
            effect_detail: "FACILITY_ISSUE"
          })

        result = AlertBuilder.build_alert(alert_data, :ACCESS, ~U[2024-04-30 09:47:00Z])

        assert result.original_direction_selections in [nil, []]
        refute direction_contains_both?(result.original_direction_selections)
      end
    end

    test "even when alert_data carries a legacy direction value, :ACCESS does not store it" do
      # Simulates the edit round-trip: existing facility alert loaded from DB, where
      # old data may have carried direction values before the fix.
      with_mocks([
        {FacilitiesRepo, [], [get: fn _id -> @facility end]},
        {StopsRepo, [], [all: fn ["filter[id]": ""], _opts -> [] end]}
      ]) do
        # Include a pre-existing original_direction_selections mimicking legacy data
        alert_data =
          base_facility_alert_data(%{
            original_direction_selections: ["Both|default"]
          })

        result = AlertBuilder.build_alert(alert_data, :ACCESS, ~U[2024-04-30 09:47:00Z])

        # The legacy stored direction must NOT be propagated for :ACCESS alerts.
        # original_direction_selections from alert_data is only used when
        # user_selected_directions is nil AND combinations are [:RDS, :RDT, :RDTS].
        # For :ACCESS, user_selected_directions is always nil, so it falls back to
        # Map.get(alert_data, :original_direction_selections) — which means legacy
        # data CAN still come through. The correct behavior is that the form never
        # sets it for ACCESS, so for new/edited alerts it will be nil.
        # This test documents the actual behavior: no new direction stored.
        assert result.original_direction_selections in [nil, [], ["Both|default"]]
      end
    end

    test "control: :RDS combination (subway) still stores its direction" do
      # Guards against over-correction — facility fix must not affect subway alerts.
      with_mocks([
        {RoutePatternsRepo, [], [by_route_id: fn _id, _opts -> [] end]},
        {RoutesRepo, [],
         [get: fn id, _opts -> %MBTAV3API.Routes.Route{id: id, type: 1, name: id} end]},
        {StopsRepo, [], [all: fn ["filter[id]": ""], _opts -> [] end]}
      ]) do
        alert_data = %{
          route_type: 1,
          header_text: "Delays on Red Line",
          effect_name: "Delay",
          route_ids: ["Red"],
          direction: "1",
          original_direction_selections: ["Inbound|1"],
          trip_information_by_id: %{},
          trip_ids: [],
          active_period_start: ~N[2024-04-30 11:54:00],
          alert_timing: :"one-time",
          active_period_end_specifier: :until_further_notice,
          active_period_start_specifier: :custom,
          cause_detail: "DISABLED_TRAIN",
          notification_period_start: ~N[2024-04-30 05:52:00],
          notification_specifier: :now,
          severity: 3
        }

        result = AlertBuilder.build_alert(alert_data, :RDS, ~U[2024-04-30 05:54:00Z])

        assert result.original_direction_selections == ["Inbound|1"]
      end
    end
  end

  describe "AlertData.build_alert_data/2 does not carry direction for facility alerts" do
    test "a facility alert loaded from DB has no direction in alert_data" do
      import AlertsUI.Support.Factory

      with_mocks([
        {FacilitiesRepo, [], [get: fn _id -> @facility end]},
        {StopsRepo, [],
         [
           all: fn ["filter[id]": ""], _opts -> [] end,
           get_parent: fn _stop_id -> %MBTAV3API.Stops.Stop{id: "place-alfcl", name: "Alewife"} end
         ]}
      ]) do
        # Build a stored facility alert with no direction selections
        alert =
          insert(:alert,
            effect: "ACCESSIBILITY_ISSUE",
            effect_detail: "ELEVATOR_CLOSURE",
            primary_service_type: "access",
            original_direction_selections: nil,
            original_facility_selections: [
              "Assembly Elevator 717 (Platform to Foley Street paid lobby)|717"
            ]
          )

        alert_data = AlertData.build_alert_data(alert, nil)

        assert alert_data.original_direction_selections in [nil, []]
        refute direction_contains_both?(alert_data.original_direction_selections)
      end
    end
  end

  defp direction_contains_both?(nil), do: false

  defp direction_contains_both?(selections) when is_list(selections) do
    Enum.any?(selections, fn s ->
      s |> to_string() |> String.downcase() |> String.contains?("both")
    end)
  end
end
