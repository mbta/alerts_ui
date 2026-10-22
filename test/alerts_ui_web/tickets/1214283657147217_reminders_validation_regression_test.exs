defmodule AlertsUIWeb.Tickets.RemindersValidationRegressionTest do
  @moduledoc """
  Regression test for Asana ticket 1214283657147217 —
  "🐛 Making reminders doesn't work properly anymore"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214283657147217

  Bug: Creating reminders on iOS Safari (any time) or desktop Chrome (for today)
  silently created a "sent" reminder at the current time instead of showing a
  validation error.

  Root cause was in `ReminderTimesSlice.reminder_time_changeset`: it lacked a
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

  @min_time ~N[2024-09-25 08:00:00]
  @max_time ~N[2024-09-26 03:00:00]

  describe "reminder_time_changeset/4 — blank value" do
    test "blank reminder_time produces 'Select reminder time' error" do
      changeset =
        ReminderTimesSlice.reminder_time_changeset(
          %AlertsUIWeb.CreateAlertMonoLive.AlertData.ReminderTime{id: "", reminder_time: ""},
          %{},
          @min_time,
          @max_time
        )

      refute changeset.valid?

      assert {:reminder_time, {"Select reminder time", [validation: :required]}} in changeset.errors
    end

    test "nil reminder_time produces 'Select reminder time' error" do
      changeset =
        ReminderTimesSlice.reminder_time_changeset(
          %AlertsUIWeb.CreateAlertMonoLive.AlertData.ReminderTime{id: nil, reminder_time: nil},
          %{},
          @min_time,
          @max_time
        )

      refute changeset.valid?

      assert {:reminder_time, {"Select reminder time", [validation: :required]}} in changeset.errors
    end
  end

  describe "reminder_time_changeset/4 — past value" do
    test "reminder_time before notification start produces 'after notification period starts' error for new entries" do
      changeset =
        ReminderTimesSlice.reminder_time_changeset(
          %AlertsUIWeb.CreateAlertMonoLive.AlertData.ReminderTime{
            id: "new-123",
            reminder_time: nil
          },
          %{
            "_persistent_id" => "0",
            "id" => "new-123",
            "reminder_time" => "2024-09-25T06:00:00"
          },
          @min_time,
          @max_time
        )

      refute changeset.valid?

      error_messages = Keyword.get_values(changeset.errors, :reminder_time)

      assert Enum.any?(error_messages, fn {msg, _opts} ->
               String.contains?(msg, "Reminder time must be after notification period starts")
             end)
    end

    test "existing reminder (has id) before notification start does NOT produce a past-time error" do
      changeset =
        ReminderTimesSlice.reminder_time_changeset(
          %AlertsUIWeb.CreateAlertMonoLive.AlertData.ReminderTime{
            id: "some-existing-uuid",
            # existing record: past times are allowed (already sent)
            reminder_time: ~N[2024-09-25 06:00:00]
          },
          %{
            "_persistent_id" => "0",
            "id" => "some-existing-uuid",
            "reminder_time" => "2024-09-25T06:00:00"
          },
          @min_time,
          @max_time
        )

      # existing records bypass the notification-start check
      past_time_errors = Keyword.get_values(changeset.errors, :reminder_time)

      refute Enum.any?(past_time_errors, fn {msg, _opts} ->
               String.contains?(msg, "Reminder time must be after notification period starts")
             end)
    end
  end

  describe "reminder_time_changeset/4 — valid future value" do
    test "future reminder time within notification end has no errors" do
      params = %{
        "_persistent_id" => "0",
        "reminder_time" => "2024-09-25T12:00:00",
        "id" => "new-123"
      }

      changeset =
        ReminderTimesSlice.reminder_time_changeset(
          %AlertsUIWeb.CreateAlertMonoLive.AlertData.ReminderTime{
            id: "new-123",
            reminder_time: nil
          },
          params,
          @min_time,
          @max_time
        )

      assert changeset.valid?
      assert changeset.errors == []
    end

    test "nil notification end (until further notice) skips the upper-bound check" do
      params = %{
        "_persistent_id" => "0",
        "reminder_time" => "3030-01-01T00:00:00",
        "id" => "new-123"
      }

      changeset =
        ReminderTimesSlice.reminder_time_changeset(
          %AlertsUIWeb.CreateAlertMonoLive.AlertData.ReminderTime{
            id: "new-123",
            reminder_time: nil
          },
          params,
          @min_time,
          nil
        )

      assert changeset.valid?
      assert changeset.errors == []
    end
  end

  # ---------------------------------------------------------------------------
  # LiveView integration tests
  # ---------------------------------------------------------------------------

  describe "LiveView — reminder validation end-to-end" do
    @tag :logged_in_user
    test "past reminder date shows validation error in rendered HTML; no 'Sent' indicator", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Detour")

      # Add a reminder entry
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"reminder_sort" => ["new"]}
      })

      # Submit a reminder time in the past. Bounds come from the notification period,
      # which defaults to "now" for a new alert, so 2020 is before it.
      rendered =
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "reminder_sort" => ["0"],
            "reminder_times" => %{
              "0" => %{
                "_persistent_id" => "0",
                "id" => "new-123",
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
    test "blank reminder date shows 'Select reminder time' error; no 'Sent' indicator", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Detour")

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
                "id" => "new-123",
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
