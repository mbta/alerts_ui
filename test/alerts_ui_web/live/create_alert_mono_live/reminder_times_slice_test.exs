defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.ReminderTimesSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AlertsUIWeb.CreateAlertMonoLive.AlertData

  # Drives AlertData.sync end-to-end, returning the resulting socket regardless of
  # whether validation succeeded.
  defp sync!(socket, params) do
    case AlertData.sync(socket.assigns.form.source, socket, params) do
      {:ok, s} -> s
      {:error, s} -> s
    end
  end

  defp reminders(socket) do
    Ecto.Changeset.get_field(socket.assigns.form.source, :reminder_times, [])
  end

  # Returns a params map that puts the form into an invalid state by setting the
  # active period start to a date in the past. We merge `extra` (typically reminder
  # params) into the alert_data portion so the bug condition is reproducible.
  defp invalid_form_params(extra \\ %{}) do
    base = %{
      "active_period_start_specifier" => "start_of_service",
      "active_period_start_date" => "2020-01-01"
    }

    %{"alert_data" => Map.merge(base, extra)}
  end

  describe "dropping the last reminder while overall validation fails" do
    @tag :logged_in_user
    test "removes a freshly-added empty reminder even when other validation errors exist", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/alerts/mono/new/bus/delay")
      initial_socket = :sys.get_state(view.pid).socket

      # Add a reminder while the form is invalid (effect start in the past). The
      # {:error, _} branch fires so the new entry lives in changes[:reminder_times],
      # never in data.
      after_add = sync!(initial_socket, invalid_form_params(%{"reminder_sort" => ["new"]}))

      assert after_add.assigns.form.source.action == :validate,
             "form should be invalid for this regression to be meaningful"

      assert length(reminders(after_add)) == 1,
             "reminder should be added even when validation fails"

      # Drop the only entry. Without the materialize step, cast_embed would short-circuit
      # at relation.ex:306 (cast_or_change(:many, [], [], …) — data and the new value
      # list are both empty), leaving the stale insert in changes.
      after_drop =
        sync!(
          after_add,
          invalid_form_params(%{
            "reminder_sort" => ["0"],
            "reminder_drop" => ["", "0"],
            "reminder_times" => %{
              "0" => %{"id" => "", "min_time" => "2026-05-22T15:00:00", "max_time" => ""}
            }
          })
        )

      assert reminders(after_drop) == [],
             "the only reminder should be dropped even when the form is still invalid"
    end

    @tag :logged_in_user
    test "removes a reminder that has a datetime value while form is invalid", %{conn: conn} do
      # The "drop the last one" case called out in the f2f10fb6 commit message —
      # specifically a reminder that has a real value, not just a blank row.
      {:ok, view, _html} = live(conn, "/alerts/mono/new/bus/delay")
      initial_socket = :sys.get_state(view.pid).socket

      after_add = sync!(initial_socket, invalid_form_params(%{"reminder_sort" => ["new"]}))

      after_fill =
        sync!(
          after_add,
          invalid_form_params(%{
            "reminder_sort" => ["0"],
            "reminder_times" => %{
              "0" => %{
                "id" => "",
                "min_time" => "2026-05-22T15:00:00",
                "max_time" => "",
                "reminder_time" => "2222-02-22T22:22:00"
              }
            }
          })
        )

      assert [%{reminder_time: %NaiveDateTime{year: 2222}}] = reminders(after_fill),
             "the entered datetime should have been cast onto the reminder"

      after_drop =
        sync!(
          after_fill,
          invalid_form_params(%{
            "reminder_sort" => ["0"],
            "reminder_drop" => ["", "0"],
            "reminder_times" => %{
              "0" => %{
                "id" => "",
                "min_time" => "2026-05-22T15:00:00",
                "max_time" => "",
                "reminder_time" => "2222-02-22T22:22:00"
              }
            }
          })
        )

      assert reminders(after_drop) == [],
             "a reminder with a datetime should drop cleanly even when other validations fail"
    end
  end
end
