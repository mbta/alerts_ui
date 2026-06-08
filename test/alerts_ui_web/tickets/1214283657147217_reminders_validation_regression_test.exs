defmodule AlertsUIWeb.Tickets.RemindersValidationRegressionTest do
  @moduledoc """
  Regression test for Asana ticket 1214283657147217 —
  "🐛 Making reminders doesn't work properly anymore"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214283657147217

  Bug: Creating reminders on iOS Safari (any time) or desktop Chrome (for today)
  silently created a "sent" reminder at the current time instead of showing a
  validation error.

  Root cause was in `ReminderTimesSlice.reminder_time_changeset/2`: it lacked a
  `validate_required` call, so a blank `reminder_time` (what iOS Safari's lack of
  `datetime-local` support produces) or a past time would pass without error.
  The `validate` callback in the `Slice` impl was also a no-op before the fix.

  Acceptance criteria:
    * Users should never be able to create a sent reminder under any circumstances.
    * It should throw a validation error if the reminder time is now or before now.
    * Testing added so this regression cannot recur.

  This test covers:
    1. Blank reminder time → "Select reminder time" changeset error.
    2. Past reminder time → "Reminder time must be after notification period starts"
       changeset error.
    3. Future reminder time within range → no changeset error.
    4. End-to-end via LiveView: past reminder date shows error in rendered HTML;
       no "Sent" indicator appears.
    5. End-to-end via LiveView: blank reminder date shows "Select reminder time"
       in rendered HTML; no "Sent" indicator appears.
  """
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUIWeb.CreateAlertMonoLive.Slices.ReminderTimesSlice

  # ---------------------------------------------------------------------------
  # Changeset-level unit tests (fast, no browser required)
  # ---------------------------------------------------------------------------

  describe "reminder_time_changeset/2 — blank value" do
    test "blank reminder_time produces 'Select reminder time' error" do
      params = %{
        "reminder_time" => "",
        "min_time" => "2024-09-25T08:00:00",
        "max_time" => "2024-09-26T03:00:00",
        "id" => ""
      }

      changeset = ReminderTimesSlice.reminder_time_changeset(%AlertsUIWeb.CreateAlertMonoLive.AlertData.ReminderTime{}, params)

      refute changeset.valid?
      assert {:reminder_time, {"Select reminder time", [validation: :required]}} in changeset.errors
    end

    test "nil reminder_time produces 'Select reminder time' error" do
      params = %{
        "min_time" => "2024-09-25T08:00:00",
        "max_time" => "2024-09-26T03:00:00",
        "id" => ""
      }

      changeset = ReminderTimesSlice.reminder_time_changeset(%AlertsUIWeb.CreateAlertMonoLive.AlertData.ReminderTime{}, params)

      refute changeset.valid?
      assert {:reminder_time, {"Select reminder time", [validation: :required]}} in changeset.errors
    end
  end

  describe "reminder_time_changeset/2 — past value" do
    test "reminder_time before min_time produces 'after notification period starts' error for new entries" do
      # new entry: id is blank
      params = %{
        "reminder_time" => "2024-09-25T06:00:00",
        "min_time" => "2024-09-25T08:00:00",
        "max_time" => "2024-09-26T03:00:00",
        "id" => ""
      }

      changeset = ReminderTimesSlice.reminder_time_changeset(%AlertsUIWeb.CreateAlertMonoLive.AlertData.ReminderTime{}, params)

      refute changeset.valid?

      error_messages = Keyword.get_values(changeset.errors, :reminder_time)
      assert Enum.any?(error_messages, fn {msg, _opts} ->
        String.contains?(msg, "Reminder time must be after notification period starts")
      end)
    end

    test "existing reminder (has id) before min_time does NOT produce a past-time error" do
      # existing record: past times are allowed (already sent)
      params = %{
        "reminder_time" => "2024-09-25T06:00:00",
        "min_time" => "2024-09-25T08:00:00",
        "max_time" => "2024-09-26T03:00:00",
        "id" => "some-existing-uuid"
      }

      changeset = ReminderTimesSlice.reminder_time_changeset(%AlertsUIWeb.CreateAlertMonoLive.AlertData.ReminderTime{}, params)

      # existing records bypass the min_time check
      past_time_errors = Keyword.get_values(changeset.errors, :reminder_time)
      refute Enum.any?(past_time_errors, fn {msg, _opts} ->
        String.contains?(msg, "Reminder time must be after notification period starts")
      end)
    end
  end

  describe "reminder_time_changeset/2 — valid future value" do
    test "future reminder time within max_time has no errors" do
      params = %{
        "reminder_time" => "2024-09-25T12:00:00",
        "min_time" => "2024-09-25T08:00:00",
        "max_time" => "2024-09-26T03:00:00",
        "id" => ""
      }

      changeset = ReminderTimesSlice.reminder_time_changeset(%AlertsUIWeb.CreateAlertMonoLive.AlertData.ReminderTime{}, params)

      assert changeset.valid?
      assert changeset.errors == []
    end
  end

  # ---------------------------------------------------------------------------
  # LiveView integration tests
  # ---------------------------------------------------------------------------

  describe "LiveView — reminder validation end-to-end" do
    @tag :logged_in_user
    test "past reminder date shows validation error in rendered HTML; no 'Sent' indicator", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Detour")

      # Add a reminder entry
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"reminder_sort" => ["new"]}
      })

      # Submit a past reminder time with min_time set to a clearly later time
      rendered =
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "reminder_sort" => ["0"],
            "reminder_times" => %{
              "0" => %{
                "_persistent_id" => "0",
                "id" => "",
                "min_time" => "2026-01-01T08:00:00",
                "max_time" => "2026-12-31T23:00:00",
                "reminder_time" => "2020-01-01T10:00:00"
              }
            }
          }
        })

      # Must show a validation error
      assert rendered =~ "Reminder time must be after notification period starts"
      # Must NOT show the "Sent" check-circle
      refute rendered =~ "hero-check-circle-solid"
    end

    @tag :logged_in_user
    test "blank reminder date shows 'Select reminder time' error; no 'Sent' indicator", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Detour")

      # Add a reminder entry with no reminder_time value
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"reminder_sort" => ["new"]}
      })

      rendered =
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "reminder_sort" => ["0"],
            "reminder_times" => %{
              "0" => %{
                "_persistent_id" => "0",
                "id" => "",
                "min_time" => "2026-01-01T08:00:00",
                "max_time" => "2026-12-31T23:00:00",
                "reminder_time" => ""
              }
            }
          }
        })

      # Must show the required-field error
      assert rendered =~ "Select reminder time"
      # Must NOT show the "Sent" check-circle
      refute rendered =~ "hero-check-circle-solid"
    end
  end
end
