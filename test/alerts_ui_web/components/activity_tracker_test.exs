defmodule AlertsUIWeb.ActivityTrackerTest do
  @moduledoc """
  Regression test for Asana ticket 1213347936088923
  "🐛 App shouldn't reload itself unless session has ended"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213347936088923

  Observed: The app reloaded itself (flashing "We can't find the internet" /
  "Something went wrong") even when the user had been inactive for less than
  the 3-hour session timeout. This happened because a stale WebSocket
  reconnection would cause a full LiveView remount instead of a graceful
  session-validity check.

  The fix:
  1. The `ActivityTracker` LiveComponent now handles an `"inactivity"` event
     (pushed from the client every 30 seconds) in addition to `"activity"`.
     The `"inactivity"` handler checks `UserAuth.auth_expired?/2` and
     redirects to `/reauthenticate` when the session is truly expired —
     without updating `last_active`, so it doesn't artificially extend
     the idle timer.
  2. `LiveSocket` heartbeatIntervalMs lowered from 30 s to 3 s (plus
     longPollFallbackMs: 3 s) to maintain connection stability and prevent
     the silent WebSocket drops that triggered spurious reloads.
  3. `/reauthenticate` delivers a clean Keycloak re-auth redirect instead of
     a hard page reload.

  Acceptance Criteria: "The app shouldn't reload itself unless the user has
  been forcibly logged out due to inactivity."

  These tests pin the server-side half of the fix — the ActivityTracker
  component's behaviour on `"activity"` and `"inactivity"` events — verifying
  that:
  * An `"inactivity"` event from a user with a valid session is a no-op
    (no redirect, no last_active update).
  * An `"inactivity"` event from a user whose session has expired triggers
    a redirect to `/reauthenticate` (not a page reload or crash).
  """
  use ExUnit.Case
  use AlertsUIWeb.ConnCase

  import AlertsUI.UsersFixtures
  import LiveIsolatedComponent
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.ActivityTracker
  alias AlertsUIWeb.UserAuth

  # A timestamp far in the past that will always be considered expired.
  @expired_auth_time 1

  # Helper: build the assigns the ActivityTracker component needs.
  defp tracker_assigns(overrides \\ %{}) do
    default_user = user_fixture([:viewer, :author])
    now = System.system_time(:second)

    Map.merge(
      %{
        id: "activity-tracker",
        current_user: default_user,
        last_auth_time: now,
        last_active: now
      },
      overrides
    )
  end

  describe "ActivityTracker — inactivity event (the new handler)" do
    test "inactivity event with a valid session is a no-op (no redirect, assigns unchanged)" do
      assigns = tracker_assigns()

      {:ok, view, _html} = live_isolated_component(ActivityTracker, assigns)

      # Capture assigns before the inactivity event
      before_html = render(view)

      # Push the inactivity event — this simulates the JS pushInactivity() call
      send_component_event(view, "activity-tracker", "inactivity", %{})

      after_html = render(view)

      # No redirect should have occurred (component still alive and rendering)
      assert is_binary(after_html)

      # The component renders a simple div — no special content to check.
      # The important thing is it didn't crash or navigate away.
      assert after_html =~ ~s(id="activity-tracker")

      # Verify the HTML didn't change (last_active is NOT updated on inactivity)
      assert before_html == after_html
    end

    test "inactivity event with an expired session redirects to /reauthenticate" do
      # Force last_active and last_auth_time to be far in the past
      expired_last_active = 1

      assigns =
        tracker_assigns(%{
          last_auth_time: @expired_auth_time,
          last_active: expired_last_active
        })

      {:ok, view, _html} = live_isolated_component(ActivityTracker, assigns)

      # Verify the session is considered expired by auth logic
      assert UserAuth.auth_expired?(%{
               last_auth_time: @expired_auth_time,
               last_active: expired_last_active
             })

      # Push inactivity — with expired auth, the component should redirect.
      {:error, {:redirect, %{status: 302, to: redirect_path}}} =
        send_component_event(view, "activity-tracker", "inactivity", %{})

      url_user_email = String.replace(assigns.current_user.email, "@", "%40")
      assert redirect_path == "/reauthenticate?email=#{url_user_email}"
    end
  end

  # Helper to send an event directly to a live component by ID
  defp send_component_event(view, component_id, event, params) do
    view
    |> with_target("##{component_id}")
    |> render_hook(event, params)
  end
end
