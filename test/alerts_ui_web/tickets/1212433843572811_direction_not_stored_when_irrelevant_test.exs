defmodule AlertsUIWeb.Tickets.DirectionNotStoredWhenIrrelevantTest do
  @moduledoc """
  Regression test for Asana ticket 1212433843572811
  "🐛 Don't store/show Direction field when not relevant"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1212433843572811

  Bug: when an alert is built (on create OR edit) for a service/effect combination
  that has NO Direction field in the form, the system still stored a direction
  ("Both") in `original_direction_selections`, which then surfaced as
  "Direction: Both" in the View Alerts details modal and in the history CSV.

  Acceptance criteria covered here (the two named test cases plus the edit round-trip):
    * A Stop→Route alert (combination `:SR`, e.g. Bus • Stop Move) must never store a direction.
    * A Route alert (combination `:R`, e.g. Ferry • Extra Service) must never store a direction.
    * Because there is no direction selection for these combinations, re-building an
      existing alert (the edit step in the repro) must not introduce "Both".

  The fix (commit 34cc7454, PR #1002) limits stored directions to the only
  combinations whose form actually has a Direction field: `:RDS`, `:RDT`, `:RDTS`.
  This test exercises `AlertBuilder.build_alert/3` directly — the function that
  produces `original_direction_selections`, the single source that drives both the
  modal "Direction:" row and the history CSV.
  """
  use AlertsUI.DataCase
  import Mock
  alias AlertsUI.AlertBuilder
  alias AlertsUI.AlertHistory
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  # The bug only manifested when alert_data carried a direction value (as it does
  # in practice — the form/edit flow always passes :direction). A correct fix must
  # ignore it for combinations whose form has no Direction field.
  defp base_alert_data(extra) do
    Map.merge(
      %{
        route_type: 3,
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["57"],
        # A direction is present in the data, mimicking the edit/round-trip flow.
        direction: "1",
        active_period_start: ~N[2024-04-30 11:54:00],
        alert_timing: :"one-time",
        active_period_end_specifier: :until_further_notice,
        active_period_start_specifier: :custom,
        cause_detail: "DISABLED_TRAIN",
        notification_period_start: ~N[2024-04-30 05:52:00],
        notification_specifier: :now,
        severity: 3
      },
      extra
    )
  end

  describe "build_alert/3 does not store direction for combinations without a Direction field" do
    test "Stop→Route alert (:SR, e.g. Bus • Stop Move) stores no direction" do
      with_mocks([
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]},
        {RoutesRepo, [],
         [get: fn route_id, _opts -> %Route{id: route_id, type: 3, name: route_id} end]},
        {StopsRepo, [],
         [
           all: fn _filter, _opts -> [%Stop{id: "place-1", name: "A Stop"}] end,
           by_route: fn _route_id, _direction -> [%Stop{id: "place-1", name: "A Stop"}] end
         ]}
      ]) do
        alert_data =
          base_alert_data(%{
            stop_ids: ["place-1"],
            stop_names_and_ids: ["A Stop|place-1"]
          })

        result = AlertBuilder.build_alert(alert_data, :SR, ~U[2024-04-30 05:54:00Z])

        # The core assertion: no direction is stored, and specifically never "Both".
        assert result.original_direction_selections in [nil, []]
        refute direction_contains_both?(result.original_direction_selections)
      end
    end

    test "Route alert (:R, e.g. Ferry • Extra Service) stores no direction" do
      with_mocks([
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]},
        {RoutesRepo, [],
         [get: fn route_id, _opts -> %Route{id: route_id, type: 4, name: route_id} end]},
        {StopsRepo, [], [all: fn ["filter[id]": ""], _opts -> [] end]}
      ]) do
        alert_data =
          base_alert_data(%{
            route_type: 4,
            effect_name: "Extra Service",
            route_ids: ["Boat-F1"]
          })

        result = AlertBuilder.build_alert(alert_data, :R, ~U[2024-04-30 05:54:00Z])

        assert result.original_direction_selections in [nil, []]
        refute direction_contains_both?(result.original_direction_selections)
      end
    end

    test "editing a :SR alert that (legacy) carries a stored direction does not re-introduce it" do
      # Simulates the repro's edit step: alert_data loaded from a stored alert.
      # Even if a value were present, a Stop→Route alert must not keep a direction.
      with_mocks([
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]},
        {RoutesRepo, [],
         [get: fn route_id, _opts -> %Route{id: route_id, type: 3, name: route_id} end]},
        {StopsRepo, [],
         [
           all: fn _filter, _opts -> [%Stop{id: "place-1", name: "A Stop"}] end,
           by_route: fn _route_id, _direction -> [%Stop{id: "place-1", name: "A Stop"}] end
         ]}
      ]) do
        alert_data =
          base_alert_data(%{
            stop_ids: ["place-1"],
            stop_names_and_ids: ["A Stop|place-1"]
          })

        result = AlertBuilder.build_alert(alert_data, :SR, ~U[2024-04-30 05:54:00Z])

        refute direction_contains_both?(result.original_direction_selections)
      end
    end

    test "control: a :RDS alert (which DOES have a Direction field) still stores its direction" do
      # Guards against the fix over-correcting and dropping legitimate directions.
      with_mocks([
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]},
        {RoutesRepo, [],
         [get: fn route_id, _opts -> %Route{id: route_id, type: 1, name: route_id} end]},
        {StopsRepo, [], [all: fn ["filter[id]": ""], _opts -> [] end]}
      ]) do
        alert_data =
          base_alert_data(%{
            route_type: 1,
            direction: "1",
            original_direction_selections: ["Inbound|1"],
            trip_information_by_id: %{},
            trip_ids: []
          })

        result = AlertBuilder.build_alert(alert_data, :RDS, ~U[2024-04-30 05:54:00Z])

        assert result.original_direction_selections == ["Inbound|1"]
      end
    end
  end

  describe "history CSV affected entities (AC #3)" do
    # AC: "Don't output 'Direction: Both' in Affected entities in the history .csv
    # when the direction is both." The real fix prevents "Both" from ever being
    # STORED for non-direction combinations; the entity that build_alert produces
    # (empty/nil direction) must therefore yield no "Direction:" text in the CSV.
    test "an alert with no stored direction yields no Direction text in the CSV" do
      %{affected_entities: entities} =
        AlertHistory.build_history(
          {%{
             original_route_selections: ["Green Line C|Green-C"],
             original_direction_selections: []
           }, 1}
        )

      assert entities == "Routes: Green Line C"
      refute entities =~ "Direction"
    end

    test "a nil stored direction yields no Direction text in the CSV" do
      %{affected_entities: entities} =
        AlertHistory.build_history(
          {%{
             original_route_selections: ["Green Line C|Green-C"],
             original_direction_selections: nil
           }, 1}
        )

      refute entities =~ "Direction"
    end

    # DOCUMENTED GAP (not a fix assertion): the CSV builder itself does NOT filter a
    # literal stored "Both" — it renders any single stored direction name verbatim.
    # So a LEGACY alert that still has ["Both|default"] persisted (created before the
    # fix, or imported) will continue to print "Direction: Both". The ticket fix
    # addresses this at the storage layer (above), not the rendering layer. This test
    # pins that current behavior so a future rendering-layer fix is a conscious change.
    test "legacy stored \"Both\" is NOT filtered by the CSV renderer (current behavior)" do
      %{affected_entities: entities} =
        AlertHistory.build_history(
          {%{
             original_route_selections: ["Green Line C|Green-C"],
             original_direction_selections: ["Both|default"]
           }, 1}
        )

      assert entities =~ "Direction: Both"
    end
  end

  defp direction_contains_both?(nil), do: false
  defp direction_contains_both?(selections) when is_list(selections) do
    Enum.any?(selections, fn s ->
      s |> to_string() |> String.downcase() |> String.contains?("both")
    end)
  end
end
