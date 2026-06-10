defmodule AlertsUIWeb.Tickets.RecurringToOneTimeTest do
  @moduledoc """
  Regression test for Asana ticket 1213402732501477
  "🐛 Can't change recurring alert to 1-time"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213402732501477

  Bug: editing a recurring alert to be "one-time" and submitting would not
  persist the timing change — re-opening the edit form still showed the alert
  as recurring.

  Root cause: the `alert_data_v2_to_v1/1` conversion function was not clearing
  `recurrence_days` when converting a "one-time" alert. The lingering recurrence
  days caused the changeset to classify the alert as recurring.

  Fix: `strip_recurrence_days_if_one_time/1` in AlertData clears `recurrence_days`
  to `[]` whenever `alert_timing` is `:"one-time"` or `"one-time"`, called
  from `alert_data_v2_to_v1/1` before passing to `AlertBuilder`.

  Acceptance criteria:
    1. Editing a recurring alert to one-time and submitting stays one-time
    2. The alert's recurrence_days are empty (no lingering recurring data)

  Tests:
    * `alert_data_v2_to_v1/1` clears `recurrence_days` when alert_timing is one-time
    * `alert_data_v2_to_v1/1` preserves `recurrence_days` when alert_timing is recurring
    * Full LiveView edit round-trip: create recurring → edit to one-time → verify persisted
  """
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUI.Alerts
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  @facility %Facility{
    id: "931",
    type: "ELEVATOR",
    short_name: "Wonderland platform to paid pedestrian bridge",
    long_name: "Airport Elevator 931 (Wonderland platform to paid pedestrian bridge)"
  }

  # --- Unit tests for strip_recurrence_days_if_one_time via alert_data_v2_to_v1 ---

  describe "alert_data_v2_to_v1/1 recurrence clearing (ticket 1213402732501477)" do
    test "clears recurrence_days when alert_timing is :\"one-time\"" do
      v2_alert_data = %AlertData{
        alert_timing: :"one-time",
        recurrence_days: [:monday, :wednesday, :friday],
        active_period_start_specifier: :now,
        active_period_end_specifier: :end_of_service,
        notification_specifier: :now,
        active_period_start_time_specifier: :start_of_service,
        active_period_end_time_specifier: :end_of_service
      }

      result = AlertData.alert_data_v2_to_v1(v2_alert_data)

      # After converting to v1 for a one-time alert, recurrence_days must be empty
      assert result.recurrence_days == [],
             "recurrence_days must be cleared when alert_timing is one-time; got: #{inspect(result.recurrence_days)}"
    end

    test "clears recurrence_days when alert_timing is string \"one-time\"" do
      v2_alert_data = %AlertData{
        alert_timing: "one-time",
        recurrence_days: [:monday, :tuesday, :saturday],
        active_period_start_specifier: :now,
        active_period_end_specifier: :end_of_service,
        notification_specifier: :now,
        active_period_start_time_specifier: :start_of_service,
        active_period_end_time_specifier: :end_of_service
      }

      result = AlertData.alert_data_v2_to_v1(v2_alert_data)

      assert result.recurrence_days == [],
             "recurrence_days must be cleared for string \"one-time\" alert_timing"
    end

    test "preserves recurrence_days when alert_timing is :recurring" do
      v2_alert_data = %AlertData{
        alert_timing: :recurring,
        recurrence_days: [:monday, :wednesday, :friday],
        active_period_start_specifier: :now,
        active_period_end_specifier: :end_of_service,
        notification_specifier: :now,
        active_period_start_time_specifier: :start_of_service,
        active_period_end_time_specifier: :end_of_service
      }

      result = AlertData.alert_data_v2_to_v1(v2_alert_data)

      assert result.recurrence_days == [:monday, :wednesday, :friday],
             "recurrence_days must be preserved when alert_timing is :recurring"
    end

    test "clears recurrence_days for one-time when it was previously set (the specific bug scenario)" do
      # Simulate the exact bug scenario: a recurring alert had Mon/Wed/Fri days,
      # user edited to one-time, but the days were NOT cleared → alert stayed recurring.
      # This test ensures the days ARE cleared.
      recurring_data = %AlertData{
        alert_timing: :"one-time",
        # These are the "lingering" values that caused the bug
        recurrence_days: [:monday, :wednesday, :friday],
        active_period_start_specifier: :now,
        active_period_end_specifier: :end_of_service,
        notification_specifier: :now,
        active_period_start_time_specifier: :start_of_service,
        active_period_end_time_specifier: :end_of_service
      }

      result = AlertData.alert_data_v2_to_v1(recurring_data)

      # The bug would have left recurrence_days as [:monday, :wednesday, :friday]
      # The fix should make it []
      assert result.recurrence_days == [],
             "Bug regression: lingering recurrence_days from a recurring alert must be cleared when switching to one-time"
    end
  end

  # --- Integration test: full LiveView round-trip ---

  describe "edit recurring alert to one-time (ticket 1213402732501477)" do
    @tag :logged_in_user
    test "recurrence_days are empty after editing a recurring alert to one-time", %{conn: conn} do
      with_mocks([
        {SchedulesRepo, [], [by_route_ids: fn _ids, _opts -> [] end]},
        {FacilitiesRepo, [],
         [
           get: fn _id -> @facility end,
           all: fn _opts -> [@facility] end,
           get_by_type: fn _types, _opts -> [@facility] end
         ]},
        {StopsRepo, [],
         [
           all: fn _, _ -> [] end,
           by_route: fn _route, _direction, _opts -> [] end,
           get: fn _id -> nil end,
           get_parent: fn _id -> nil end
         ]}
      ]) do
        # Step 1: Create a recurring facility alert via the form
        today_day =
          DateTime.utc_now()
          |> DateTime.shift_zone!("America/New_York")
          |> DateTime.to_date()
          |> Date.day_of_week()

        # day_of_week/1 returns 1=Mon..7=Sun; convert to atom
        today_atom =
          case today_day do
            1 -> :monday
            2 -> :tuesday
            3 -> :wednesday
            4 -> :thursday
            5 -> :friday
            6 -> :saturday
            7 -> :sunday
          end

        # Build recurring active periods — recurring alerts use start/end recurrence times.
        # The active_period_start must be on one of the recurrence days.
        # Use today's date with a start time, so today's day matches the recurrence days.
        now_et =
          DateTime.utc_now()
          |> DateTime.shift_zone!("America/New_York")

        alert_params = %{
          alert_id: "recurring-test-#{System.unique_integer([:positive])}",
          effect: "ACCESSIBILITY_ISSUE",
          effect_detail: "ELEVATOR_CLOSURE",
          effect_name: "Elevator Closure",
          primary_service_type: "access",
          recurring: true,
          recurrence_days: [today_atom, :monday, :wednesday] |> Enum.uniq(),
          recurrence_start_time: ~T[09:00:00],
          recurrence_end_time: ~T[23:00:00],
          active_period_start: DateTime.to_naive(now_et),
          active_period_end: nil,
          header_text: "Airport Elevator 931 is unavailable.",
          informed_entity: [%{facility_id: "931", activities: [:BOARD, :EXIT, :RIDE]}],
          active_period: [%{start: DateTime.to_naive(now_et), end: nil}],
          severity: 3,
          last_modified_timestamp: DateTime.utc_now(),
          reminder_times: []
        }

        user = build(:user)
        {:ok, alert} = Alerts.create_or_update_alert(alert_params, user)

        # Step 2: Load the edit form for the recurring alert
        # The recurring flag should be set in the DB
        db_alert = Alerts.get_by_id(alert.id)

        assert db_alert.recurring == true,
               "pre-condition: alert must be recurring before the edit"

        {:ok, view, html} =
          live(conn, "/alerts/mono/edit/#{db_alert.alert_id}/facility/elevator_closure")

        # Verify it renders as recurring in the form
        assert html =~ "recurring" or
                 has_element?(view, "select[name='alert_data[alert_timing]']"),
               "form should render for this alert"

        # Step 3: Submit with alert_timing = one-time (simulating the user changing it)
        # Use render_change to set alert_timing to one-time, keeping recurrence_days in payload
        # (this simulates the exact bug: the old recurrence_days are still in the submitted form)
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "alert_timing"],
          "alert_data" => %{
            "alert_timing" => "one-time",
            # Deliberately include old recurrence_days to reproduce the bug scenario
            "recurrence_days" => ["monday", "wednesday", today_atom |> Atom.to_string()]
          }
        })

        # Step 4: Open the review modal and submit
        open_review_modal(view)

        if has_element?(view, "#review-modal-container") do
          view
          |> element("#review-modal-container button", "Submit")
          |> render_click()

          # Wait for redirect (returns to "/" or configured return_to path)
          {_redirect_path, flash} = assert_redirect(view)

          assert flash["info"] =~ "updated" or flash["info"] =~ "created",
                 "Expected a success flash, got: #{inspect(flash)}"

          # Step 5: Verify the saved alert has recurrence_days = [] and recurring = false
          updated_alert = Alerts.get_by_alert_id(db_alert.alert_id)

          assert updated_alert.recurrence_days == [] or updated_alert.recurrence_days == nil,
                 "AC2: recurrence_days must be empty after converting to one-time; got: #{inspect(updated_alert.recurrence_days)}"

          assert updated_alert.recurring == false or is_nil(updated_alert.recurring),
                 "AC1: alert must not be recurring after converting to one-time; got: #{inspect(updated_alert.recurring)}"
        else
          # The form may have validation errors — it won't open the review modal.
          # In this case we verify that the fix (strip_recurrence_days_if_one_time) is
          # present at the model level, which is covered by the unit tests above.
          # This is acceptable because the LiveView test setup can't fully populate the
          # facility form (FacilitiesRepo mock returns @facility but the select may need more).
          # The unit tests above directly verify the fix function; this test covers the flow.
          flunk(
            "Expected review modal to open — the form may have validation errors. " <>
              "Check that the facility alert form is fully populated. " <>
              "Rendered HTML: #{render(view) |> String.slice(0, 500)}"
          )
        end
      end
    end
  end
end
