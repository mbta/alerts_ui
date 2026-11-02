defmodule AlertsUIWeb.Tickets.AlertDurationShowEndTimeTodayTest do
  @moduledoc """
  Regression test for Asana ticket 1213905421595760
  "🐛 alert_duration should show end time today"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213905421595760

  Background: a prior change (ticket 1210713126508990) suppressed the end time in
  the `alert_duration` auto-text variable for "trip based" alerts so they'd read
  just "today". That designation was too broad: it keyed off whether the alert
  TYPE has a trip selector at all, not whether a trip was actually SELECTED.

  Acceptance criterion: for an alert whose type HAS a trip selector (e.g.
  Commuter Rail • Track Change => combination :RDTS) but where NO trip is
  selected (`schedules: []`), `alert_duration` must still show the end time
  (e.g. "until 3:00 PM"), exactly as it does for alerts without trip selectors.
  Once a trip IS selected, the existing trip-based behavior ("today") still holds.

  Verified manually on dev-green (2026-06-06): CR • Track Change, route + stop,
  no trip, effect end Custom -> Main Message read "... until 11:30 PM."; selecting
  a trip reverted the same field to "... today.".
  """
  use AlertsUIWeb.ConnCase, async: true

  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.CreateAlertLive.Helpers.AutoText.{AutoTextDuration, BuildAutoText}

  # Midday "now" so that a 3:00 PM end is "later today" within the same service day.
  @current_time ~N[2025-05-09 13:00:00]

  # CR • Track Change => combination :RDTS (a trip combination, i.e. has a trip selector).
  @cr_track_change %{route_type: 2, effect_name: "Track Change"}

  defp base_data(extra) do
    Map.merge(
      %BuildAutoText{
        alert_timing: :"one-time",
        route_type: @cr_track_change.route_type,
        effect_name: @cr_track_change.effect_name,
        start_specifier: :now,
        end_specifier: :custom,
        start_datetime: ~N[2025-05-09 13:00:00],
        end_datetime: ~N[2025-05-09 15:00:00]
      },
      extra
    )
  end

  describe "alert_duration for a trip-selector alert type with NO trip selected" do
    test ~s(shows the end time ("until 3:00 PM"\) instead of a bare "today") do
      data = base_data(%{schedules: []})

      actual = AutoTextDuration.build_duration_text(data, @current_time)

      assert actual == "until 3:00 PM"
      # Guard against the regression: must NOT collapse to a bare "today".
      refute actual == "today"
    end
  end

  describe "alert_duration when a trip IS selected (existing trip-based behavior preserved)" do
    test "still reads \"today\" for the same CR Track Change timing" do
      schedule = %EnhancedSchedule{departure_time: ~U[2025-05-09 17:00:00.00Z]}
      data = base_data(%{schedules: [schedule]})

      actual = AutoTextDuration.build_duration_text(data, @current_time)

      assert actual == "today"
    end
  end
end
