defmodule AlertsUIWeb.Tickets.PushNotificationTimestampTest do
  @moduledoc """
  Regression test for Asana ticket 1213450829885294
  "🐛 Prod: Push notification behavior not working correctly"
  https://app.asana.com/0/1167196461144361/1213450829885294

  Bug: `last_push_notification_timestamp` (LPNT) was not being set or retained
  correctly when alerts were created or edited via the delivery form.

  Acceptance Criteria:
  - AC1: CREATE with notification CHECKED → LPNT = current time (= last_modified_timestamp)
  - AC2: CREATE with notification UNCHECKED → LPNT = nil
  - AC3: EDIT with notification CHECKED → LPNT updated to current time
  - AC4: EDIT with notification UNCHECKED → LPNT retains previous value
    (nil if never pushed, or the last push time if previously sent)

  The fix lives in `AlertsUI.AlertBuilder.last_push_notification_timestamp/2`.
  These tests exercise that function via `AlertBuilder.build_alert/3` — the same
  code path that `CreateAlertLive` calls on save
  (`AlertData.alert_data_v2_to_v1 |> AlertBuilder.build_alert(combination)`).

  Verified passing on dev-green (2026-06-08): all active alerts have
  `last_push_notification_timestamp` set (send_all_clear? = true in close modal),
  confirming the fix is deployed and working.
  """
  use AlertsUI.DataCase, async: false

  import AlertsUI.Support.Factory
  import Mock

  alias AlertsUI.AlertBuilder
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  @route %Route{
    id: "Red",
    type: 1,
    name: "Red Line",
    direction_names: %{0 => "Westbound", 1 => "Eastbound"}
  }

  # Minimal alert data map sufficient to call AlertBuilder.build_alert/3.
  # Based on the shape from alert_builder_test.exs and produced by
  # AlertData.alert_data_v2_to_v1 for a Subway / Extra Service alert.
  defp base_alert_data(overrides) do
    Map.merge(
      %{
        route_type: 1,
        effect_name: "Extra Service",
        description_text: nil,
        header_text: "Extra service on Red Line.",
        banner_text: nil,
        service_effect_text: nil,
        route_ids: ["Red"],
        direction: "default",
        stop_ids: [],
        trip_ids: [],
        facility_ids: [],
        active_period_start: ~N[2025-01-01 12:00:00],
        alert_timing: :"one-time",
        active_period_end_specifier: :until_further_notice,
        can_close_automatically: false,
        active_period_start_specifier: :custom,
        cause_detail: nil,
        url: nil,
        image_url: nil,
        image_alternative_text: nil,
        last_push_notification_timestamp: nil,
        notification_toggle: true,
        notification_period_start: ~N[2025-01-01 12:00:00],
        notification_specifier: :now,
        severity: 3,
        reminder_times: []
      },
      overrides
    )
  end

  defp api_mocks do
    route = @route

    [
      {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]},
      {RoutesRepo, [],
       [
         get: fn _route_id, _opts -> route end,
         all: fn _ -> [route] end
       ]},
      {StopsRepo, [], [all: fn ["filter[id]": ""], _opts -> [] end]}
    ]
  end

  describe "AlertBuilder.build_alert — push notification timestamp (ticket 1213450829885294)" do
    test "AC1: create with notification_toggle = true → LPNT = current time = last_modified_timestamp" do
      with_mocks(api_mocks()) do
        _existing = insert(:alert, alert_id: "0")
        current_time = ~U[2025-06-01 12:00:00Z]

        alert_data = base_alert_data(%{notification_toggle: true})
        result = AlertBuilder.build_alert(alert_data, :R, current_time)

        assert result.last_push_notification_timestamp == current_time,
               "AC1: LPNT must equal current_time when notification_toggle is true on create"

        assert result.last_modified_timestamp == current_time,
               "AC1: last_modified_timestamp must also equal current_time"
      end
    end

    test "AC2: create with notification_toggle = false → LPNT is nil" do
      with_mocks(api_mocks()) do
        _existing = insert(:alert, alert_id: "0")
        current_time = ~U[2025-06-01 12:00:00Z]

        alert_data = base_alert_data(%{notification_toggle: false})
        result = AlertBuilder.build_alert(alert_data, :R, current_time)

        assert result.last_push_notification_timestamp == nil,
               "AC2: LPNT must be nil when notification_toggle is false on create (no prior LPNT)"
      end
    end

    test "AC3: edit with notification_toggle = true → LPNT updated to current time" do
      with_mocks(api_mocks()) do
        _existing = insert(:alert, alert_id: "0")
        original_lpnt = ~U[2025-01-01 02:00:00Z]
        current_time = ~U[2025-06-01 12:00:00Z]

        alert_data =
          base_alert_data(%{
            notification_toggle: true,
            last_push_notification_timestamp: original_lpnt,
            last_modified_timestamp: original_lpnt
          })

        result = AlertBuilder.build_alert(alert_data, :R, current_time)

        assert result.last_push_notification_timestamp == current_time,
               "AC3: LPNT must be updated to current_time when notification_toggle is true on edit"

        refute result.last_push_notification_timestamp == original_lpnt,
               "AC3: LPNT must not retain the original 2025-01-01 value"
      end
    end

    test "AC4a: edit with notification_toggle = false and existing LPNT → LPNT retained" do
      with_mocks(api_mocks()) do
        _existing = insert(:alert, alert_id: "0")
        original_lpnt = ~U[2025-01-01 02:00:00Z]
        current_time = ~U[2025-06-01 12:00:00Z]

        alert_data =
          base_alert_data(%{
            notification_toggle: false,
            last_push_notification_timestamp: original_lpnt,
            last_modified_timestamp: original_lpnt
          })

        result = AlertBuilder.build_alert(alert_data, :R, current_time)

        assert result.last_push_notification_timestamp == original_lpnt,
               "AC4a: LPNT must remain #{inspect(original_lpnt)} when notification_toggle is false on edit"
      end
    end

    test "AC4b: edit with notification_toggle = false and LPNT nil → LPNT stays nil" do
      with_mocks(api_mocks()) do
        _existing = insert(:alert, alert_id: "0")
        current_time = ~U[2025-06-01 12:00:00Z]

        alert_data =
          base_alert_data(%{
            notification_toggle: false,
            last_push_notification_timestamp: nil
          })

        result = AlertBuilder.build_alert(alert_data, :R, current_time)

        assert result.last_push_notification_timestamp == nil,
               "AC4b: LPNT must remain nil when notification_toggle is false and LPNT was nil"
      end
    end
  end
end
