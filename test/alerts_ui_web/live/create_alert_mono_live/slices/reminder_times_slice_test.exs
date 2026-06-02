defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.ReminderTimesSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import AlertsUI.Support.Factory
  alias AlertsUI.Alerts
  import Test.Support.Helpers
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Detour")
      assert render(view) =~ ~s(id="reminder_times_form")
    end

    @tag :logged_in_user
    test "reminder picker appears with error message when Add Reminder is pressed", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Detour")

      rendered =
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"reminder_sort" => ["new"]}
        })

      assert rendered =~ ~s(id="reminder-time-component-0")
      assert rendered =~ ~s(Select reminder time)
    end

    @tag :logged_in_user
    test "generates a new empty entry when a filled one exists", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Detour")

      refute view
             |> render() =~ ~s(id="reminder-time-component-0")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"reminder_sort" => ["new"]}
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "reminder_sort" => ["0"],
          "reminder_times" => %{
            "0" => %{
              "_persistent_id" => "0",
              "max_time" => "2024-09-27T03:00:00",
              "min_time" => "2024-09-26 02:00:00",
              "reminder_time" => "2024-09-26T03:00",
              "reminder_time_specifier" => "custom"
            }
          }
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "reminder_sort" => ["0", "new"],
          "reminder_times" => %{
            "0" => %{
              "_persistent_id" => "0",
              "max_time" => "2024-09-27T03:00:00",
              "min_time" => "2024-09-26 02:00:00",
              "reminder_time" => "2024-09-26T03:00",
              "reminder_time_specifier" => "custom"
            }
          }
        }
      })

      input0 =
        element(view, "input[name='alert_data[reminder_times][0][reminder_time]']")
        |> render()

      input1 =
        element(view, "input[name='alert_data[reminder_times][1][reminder_time]']")
        |> render()

      assert input0 =~ ~s(value="2024-09-26T03:00")
      refute input1 =~ ~s(value="2024-09-26T03:00")
    end

    @tag :logged_in_user
    test "reminder picker disappears when X is pressed", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Detour")

      rendered =
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"reminder_sort" => ["new"]}
        })

      assert rendered =~ ~s(id="reminder-time-component-0")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"reminder_drop" => ["0"]}
      })

      refute view
             |> render() =~ ~s(id="reminder-time-component-0")
    end

    @tag :logged_in_user
    test "doesn't error if time entered is within notification period", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Detour")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom",
          "notification_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => "2024-09-26T04:00:00",
          "notification_period_start" => "2024-09-26T02:00:00"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"reminder_sort" => ["new"]}
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "reminder_sort" => ["0"],
          "reminder_times" => %{
            "0" => %{
              "_persistent_id" => "0",
              "max_time" => "2024-09-27T03:00:00",
              "min_time" => "2024-09-26 02:00:00",
              "reminder_time" => "2024-09-26T03:00",
              "reminder_time_specifier" => "custom"
            }
          }
        }
      })

      refute render(view) =~ ~s(Reminder time must be after notification period starts)
    end

    @tag :logged_in_user
    test "shows error if time entered is before effect start", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Detour")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"active_period_start" => "2024-09-26T04:00:00"}
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"reminder_sort" => ["new"]}
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "reminder_sort" => ["0"],
          "reminder_times" => %{
            "0" => %{
              "_persistent_id" => "0",
              "max_time" => "2024-09-26T04:00:00",
              "min_time" => "2024-09-25T13:04:12",
              "reminder_time" => "2024-09-25T12:12:12",
              "reminder_time_specifier" => "custom"
            }
          }
        }
      })

      assert render(view) =~ ~s(Reminder time must be after notification period starts)
    end

    @tag :logged_in_user
    test "shows error if time entered is before notification period", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Detour")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => "2024-09-26T02:00:00",
          "notification_period_start" => "2024-09-26T04:00:00"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"reminder_sort" => ["new"]}
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "reminder_sort" => ["0"],
          "reminder_times" => %{
            "0" => %{
              "_persistent_id" => "0",
              "max_time" => "2024-09-26T03:00:00",
              "min_time" => "2024-09-25T13:04:12",
              "reminder_time" => "2024-09-25T12:12:12",
              "reminder_time_specifier" => "custom"
            }
          }
        }
      })

      assert render(view) =~ ~s(Reminder time must be after notification period starts)
    end

    @tag :logged_in_user
    test "shows error if time entered is after effect start", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Detour")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => "2024-09-25T13:04:12",
          "notification_period_start" => "2024-09-25T03:00:00"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{"reminder_sort" => ["new"]}
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "reminder_sort" => ["0"],
          "reminder_times" => %{
            "0" => %{
              "_persistent_id" => "0",
              "max_time" => "2024-09-25T03:00:00",
              "min_time" => "2024-09-24T13:04:12",
              "reminder_time" => "2024-09-26T12:12:12",
              "reminder_time_specifier" => "custom"
            }
          }
        }
      })

      rendered_view = render(view)

      assert rendered_view =~ ~s(Reminder time must be before notification period ends)
    end

    @tag :logged_in_user
    test "works if editing", %{conn: conn} do
      alert_params =
        build(:alert_map, %{
          alert_id: "123",
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY",
          header_text: "cool header text",
          severity: 3,
          severity_level: :WARNING,
          cause_detail: "UNKNOWN",
          active_period_start: ~U[2024-04-30 11:45:00Z],
          reminder_times: [
            %{reminder_time: ~U[2024-04-30 11:54:00Z]},
            %{reminder_time: ~U[2024-04-30 12:54:00Z]}
          ]
        })

      {:ok, _} =
        Alerts.create_or_update_alert(alert_params, build(:user))

      {:ok, view, _html} = live(conn, "/alerts/mono/edit/123")

      rendered_view = render(view)

      # reminder_times are stored as UTC and shifted to America/New_York on load
      assert rendered_view =~ ~s(value="2024-04-30T07:54")
      assert rendered_view =~ ~s(value="2024-04-30T08:54")
    end
  end

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
  defp invalid_form_params(extra) do
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
