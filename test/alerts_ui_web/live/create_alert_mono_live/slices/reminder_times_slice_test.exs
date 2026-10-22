defmodule AlertsUIWeb.CreateAlertLive.Slices.ReminderTimesSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import AlertsUI.Support.Factory
  import Test.Support.Helpers
  import Mock

  alias AlertsUI.Alerts
  alias AlertsUIWeb.CreateAlertLive.AlertData
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Detour")
      assert render(view) =~ ~s(id="reminder_times_form")
    end

    @tag :logged_in_user
    test "reminder picker appears with error message when Add Reminder is pressed", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Detour")

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
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Detour")

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
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Detour")

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
    test "reminder validates against notification start, not current time, when specifier is same_as_effect_period",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Detour")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom",
          "notification_specifier" => "same_as_effect_period"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => "2030-01-01T10:00:00"
        }
      })

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"reminder_sort" => ["new"]}})

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "reminder_times" => %{
            "0" => %{"reminder_time" => "2029-01-01T00:00:00"}
          }
        }
      })

      min_time_element =
        element(view, "#alert_data_reminder_times_0_reminder_time-root-element") |> render()

      assert min_time_element =~
               ~s(Reminder time must be after notification period starts (01/01/2030, 10:00 AM\))
    end

    @tag :logged_in_user
    test "reminder has no upper bound when active period specifier is until further notice",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Detour")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "until_further_notice",
          "notification_specifier" => "same_as_effect_period"
        }
      })

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"reminder_sort" => ["new"]}})

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "reminder_times" => %{
            "0" => %{"reminder_time" => "3030-01-01T00:00:00"}
          }
        }
      })

      max_time_element =
        element(view, "#alert_data_reminder_times_0_reminder_time-root-element") |> render()

      refute max_time_element =~
               ~s(Reminder time must be before notification period)
    end

    @tag :logged_in_user
    test "doesn't error if time entered is within notification period", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Detour")

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
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Detour")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => "2024-09-26T04:00:00",
          "notification_specifier" => "same_as_effect_period"
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
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Detour")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => "2024-09-26T02:00:00",
          "notification_specifier" => "custom",
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
              "reminder_time" => "2024-09-25T12:12:12",
              "reminder_time_specifier" => "custom"
            }
          }
        }
      })

      assert render(view) =~ ~s(Reminder time must be after notification period starts)
    end

    @tag :logged_in_user
    test "reminder validates when the notification period changes",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Detour")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom",
          "active_period_end_specifier" => "until_further_notice",
          "notification_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "reminder_times" => %{
            "0" => %{"reminder_time" => "2028-01-01T10:00:00"}
          }
        }
      })

      min_time_element =
        element(view, "#alert_data_reminder_times_0_reminder_time-root-element") |> render()

      refute min_time_element =~
               ~s(Reminder time must be after notification period starts)

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "notification_period_start" => "2029-01-01T10:00:00"
        }
      })

      min_time_element =
        element(view, "#alert_data_reminder_times_0_reminder_time-root-element") |> render()

      assert min_time_element =~
               ~s(Reminder time must be after notification period starts (01/01/2029, 10:00 AM\))
    end

    @tag :logged_in_user
    test "shows error if time entered is after effect start", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Detour")

      # End of service for 2024-09-25 lands at 2024-09-26 03:00, before the reminder.
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "notification_specifier" => "custom",
          "notification_period_start" => "2024-09-25T03:00:00",
          "active_period_end_specifier" => "end_of_service",
          "active_period_end_date" => "2024-09-25"
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
    test "shows errors in flash if there are any", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Detour")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => "2024-09-26T04:00:00",
          "notification_specifier" => "same_as_effect_period"
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
          "reminder_sort" => ["0", "new"],
          "reminder_times" => %{
            "0" => %{
              "_persistent_id" => "0",
              "reminder_time" => "2024-09-25T12:12:12",
              "reminder_time_specifier" => "custom"
            }
          }
        }
      })

      assert render(view) =~ ~s(Reminder time must be after notification period starts)
      assert render(view) =~ ~s(Select reminder time)

      render_async(view, 1000)

      view
      |> element("button#review", "Review and submit")
      |> render_click()

      flash = element(view, "#flash")

      assert render(flash) =~ ~s(Reminder time must be after notification period starts)
      assert render(flash) =~ ~s(Select reminder time)
    end

    @tag :logged_in_user
    test "renders if editing", %{conn: conn} do
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

      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           by_route_type: fn _route_type, _ -> [] end,
           get_parent: fn _ -> nil end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/123")

        rendered_view = render(view)

        # reminder_times are stored as UTC and shifted to America/New_York on load
        assert rendered_view =~ ~s(value="2024-04-30T07:54")
        assert rendered_view =~ ~s(value="2024-04-30T08:54")
      end
    end

    @tag :logged_in_user
    test "allows adding more if editing", %{conn: conn} do
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

      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           by_route_type: fn _route_type, _ -> [] end,
           get_parent: fn _ -> nil end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/123")

        render(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"reminder_sort" => ["0", "1", "new"]}
        })

        rendered_view =
          view
          |> element("form")
          |> render_change(%{
            "alert_data" => %{
              "reminder_sort" => ["0", "1", "2"],
              "reminder_times" => %{
                "2" => %{
                  "_persistent_id" => "2",
                  "reminder_time" => "2025-06-01T12:12:12",
                  "reminder_time_specifier" => "custom"
                }
              }
            }
          })

        # reminder_times are stored as UTC and shifted to America/New_York on load
        assert rendered_view =~ ~s(value="2024-04-30T07:54")
        assert rendered_view =~ ~s(value="2024-04-30T08:54")
        # But this one was typed in, so we check for that value.
        assert rendered_view =~ ~s(value="2025-06-01T12:12")
      end
    end

    @tag :logged_in_user
    test "only keep future reminders if duplicating", %{conn: conn} do
      now = DateTime.utc_now()
      past_reminders = [now |> DateTime.add(-2, :minute), now |> DateTime.add(-1, :day)]
      future_reminders = [now |> DateTime.add(2, :minute), now |> DateTime.add(1, :day)]

      alert_params =
        build(:alert_map, %{
          alert_id: "123",
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY",
          severity: 3,
          cause_detail: "UNKNOWN",
          active_period_start: ~U[2024-04-30 11:45:00Z],
          reminder_times: [
            %{reminder_time: hd(past_reminders)},
            %{reminder_time: List.last(past_reminders)},
            %{reminder_time: hd(future_reminders)},
            %{reminder_time: List.last(future_reminders)}
          ]
        })

      {:ok, _} =
        Alerts.create_or_update_alert(alert_params, build(:user))

      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           by_route_type: fn _route_type, _ -> [] end,
           get_parent: fn _ -> nil end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/duplicate/123")

        Enum.each(past_reminders, fn reminder ->
          converted =
            DateTime.shift_zone!(reminder, "America/New_York")
            |> Calendar.strftime("%Y-%m-%dT%H:%M")

          refute view |> element("#reminder_times_form") |> render =~
                   ~s(value=\"#{converted}\")
        end)

        Enum.each(future_reminders, fn reminder ->
          converted =
            DateTime.shift_zone!(reminder, "America/New_York")
            |> Calendar.strftime("%Y-%m-%dT%H:%M")

          assert view |> element("#reminder_times_form") |> render =~
                   ~s(value=\"#{converted}\")
        end)
      end
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
      {:ok, view, _html} = live(conn, "/alerts/new/bus/delay")
      initial_socket = :sys.get_state(view.pid).socket

      # Add a reminder while the form is invalid (effect start in the past). The
      # {:error, _} branch fires so the new entry lives in changes[:reminder_times],
      # never in data.
      after_add = sync!(initial_socket, invalid_form_params(%{"reminder_sort" => ["new"]}))

      assert after_add.assigns.form.source.action == :validate,
             "form should be invalid for this regression to be meaningful"

      created_reminders = reminders(after_add)

      assert length(created_reminders) == 1,
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
              "0" => %{"id" => hd(created_reminders).id}
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
      {:ok, view, _html} = live(conn, "/alerts/new/bus/delay")
      initial_socket = :sys.get_state(view.pid).socket

      after_add = sync!(initial_socket, invalid_form_params(%{"reminder_sort" => ["new"]}))
      created_reminder_id = hd(reminders(after_add)).id

      after_fill =
        sync!(
          after_add,
          invalid_form_params(%{
            "reminder_sort" => ["0"],
            "reminder_times" => %{
              "0" => %{
                "id" => created_reminder_id,
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
                "id" => created_reminder_id,
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
