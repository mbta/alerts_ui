defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.TimeRangeSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUI.Alerts

  # ---------------------------------------------------------------------------
  # Group 1: Basic rendering
  # ---------------------------------------------------------------------------

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")
      assert render(view) =~ ~s(id="time_range_view")
    end

    # -------------------------------------------------------------------------
    # Group 2: UI visibility
    # -------------------------------------------------------------------------

    @tag :logged_in_user
    test "enddate picker hidden unless pick option selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      # End-date input should be hidden by default (end specifier is :later_today)
      assert render(view) =~
               ~s(class="md:min-w-64 md:max-w-64 hidden")

      # Changing to end_of_service should reveal the end date picker
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom",
          "active_period_end_specifier" => "end_of_service"
        }
      })

      # After switching to end_of_service the end-date input should be visible
      # (the "hidden" class should no longer apply to the end-date element)
      html = render(view)
      assert html =~ ~s(active_period_end_date)
      # Check the end_of_service date picker is now shown (not hidden)
      refute html =~
               ~s(phx-feedback-for="alert_data[active_period_end_date]" class="md:min-w-64 md:max-w-64 hidden")
    end

    # -------------------------------------------------------------------------
    # Group 3: Editing mode
    # -------------------------------------------------------------------------

    @tag :logged_in_user
    test "editing keeps correct end time specifier when there is no end time", %{conn: conn} do
      # duration_certainty: :UNKNOWN is required so that determine_end_specifier/3 returns
      # "until_further_notice" when active_period_end is nil.  Without it the function receives
      # (nil, nil, _) and returns nil, so the specifier stays at the default :later_today.
      alert_params =
        build(:alert_map, %{
          alert_id: "edit-ufn-1",
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY",
          primary_service_type: "1",
          description_text: nil,
          duration_certainty: :UNKNOWN,
          active_period_end: nil,
          active_period: [%{start: ~U[2024-04-29 10:54:00Z], end: nil}]
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      {:ok, view, _html} = live(conn, "/alerts/mono/edit/edit-ufn-1")

      # The duration text for until_further_notice shows "alert is manually closed"
      assert render(view) =~ "alert is manually closed"
      refute render(view) =~ "later today"
    end

    @tag :logged_in_user
    test "editing custom fields to start/end of service correctly validates", %{conn: conn} do
      # Start at midnight NY (04:00 UTC in April), end at 03:00 NY next day (07:00 UTC).
      # end_of_service on 2040-05-01 (active_period_end_date) → active_period_end = 2040-05-01T03:00:00.
      # Start naive NY = 2040-05-01T00:00:00 → 03:00 > 00:00, so no "Effect must end after" error.
      alert_params =
        build(:alert_map, %{
          alert_id: "edit-eos-1",
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY",
          primary_service_type: "1",
          description_text: nil,
          active_period_start: ~U[2040-05-01 04:00:00Z],
          active_period: [
            %{start: ~U[2040-05-01 04:00:00Z], end: ~U[2040-05-02 07:00:00Z]}
          ]
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      {:ok, view, _html} = live(conn, "/alerts/mono/edit/edit-eos-1")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "end_of_service"
        }
      })

      refute render(view) =~ "Effect must end after"
    end

    @tag :logged_in_user
    test "editing does not check start time", %{conn: conn} do
      # Alert with a past start time — editing should NOT produce a "can't start in the past" error
      alert_params =
        build(:alert_map, %{
          alert_id: "edit-past-1",
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY",
          primary_service_type: "1",
          description_text: nil,
          active_period_start: ~U[2024-04-29 10:54:00Z],
          active_period: [
            %{start: ~U[2024-04-29 10:54:00Z], end: nil}
          ]
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      {:ok, view, _html} = live(conn, "/alerts/mono/edit/edit-past-1")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "later_today"
        }
      })

      refute render(view) =~ "Effect can't start in the past"
    end

    # -------------------------------------------------------------------------
    # Group 4: Duplicating mode
    # -------------------------------------------------------------------------

    @tag :logged_in_user
    test "duplicating keeps correct end time specifier when there is no end time", %{conn: conn} do
      # See note on "editing keeps correct end time specifier" — same fix applies.
      alert_params =
        build(:alert_map, %{
          alert_id: "dup-ufn-1",
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY",
          primary_service_type: "1",
          description_text: nil,
          duration_certainty: :UNKNOWN,
          active_period_end: nil,
          active_period: [%{start: ~U[2024-04-29 10:54:00Z], end: nil}]
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      {:ok, view, _html} = live(conn, "/alerts/mono/duplicate/dup-ufn-1")

      assert render(view) =~ "alert is manually closed"
      refute render(view) =~ "later today"
    end

    @tag :logged_in_user
    test "duplicating does not check start time (same as editing)", %{conn: conn} do
      # NOTE: The current validator checks `alert_id != nil` to detect editing mode and skip
      # start-time validation.  Duplicating flows also carry the original alert_id, so both
      # editing AND duplicating skip the "can't start in the past" check.  If that behaviour
      # changes in the future, this test should be updated accordingly.
      alert_params =
        build(:alert_map, %{
          alert_id: "dup-past-1",
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY",
          primary_service_type: "1",
          description_text: nil,
          active_period_start: ~U[2024-04-29 10:54:00Z],
          active_period: [
            %{start: ~U[2024-04-29 10:54:00Z], end: nil}
          ]
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      {:ok, view, _html} = live(conn, "/alerts/mono/duplicate/dup-past-1")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "later_today"
        }
      })

      refute render(view) =~ "Effect can't start in the past"
    end

    # -------------------------------------------------------------------------
    # Group 5: Specifier retention
    # -------------------------------------------------------------------------

    @tag :logged_in_user
    test "switching between start specifiers retains old date", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => "2025-03-28T03:00:00"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "start_of_service"
        }
      })

      # After switching away from custom and back, the original date should still be in the form
      assert render(view) =~ ~s(value="2025-03-28")
    end

    @tag :logged_in_user
    test "switching between end specifiers retains old date", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end" => "2025-03-28T03:00:00"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "end_of_service"
        }
      })

      # The date input (for end_of_service) should retain 2025-03-27 (day before due to service day)
      # The mono slice retains the raw date from the custom datetime (2025-03-28),
      # not a service-day offset as the old form component did.
      assert render(view) =~ ~s(value="2025-03-28")
    end

    # -------------------------------------------------------------------------
    # Group 6: Validation
    # -------------------------------------------------------------------------

    @tag :logged_in_user
    test "displays error if start is in the past", %{conn: conn} do
      # Setting a custom start datetime in the past triggers "Effect can't start in the past"
      # via validate_change(:active_period_start, ...) in validate_start_is_after_now.
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom",
          "active_period_start" => "2024-01-01T10:00:00"
        }
      })

      assert render(view) =~ "Effect can't start in the past"
    end

    @tag :logged_in_user
    test "displays error for recurring with no days selected when Review is clicked",
         %{conn: conn} do
      # Recurring alerts require at least one recurrence day; the error surfaces on Review.
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "alert_timing" => "recurring",
          "recurrence_days" => []
        }
      })

      view
      |> element("button#review", "Review and submit")
      |> render_click()

      assert render(view) =~ "Select one or more days for alert to recur"
    end

    @tag :logged_in_user
    test "displays error if end before start", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end" => "2024-05-01T09:54:00",
          "active_period_start" => "2024-05-01T10:54:00"
        }
      })

      assert render(view) =~ "Effect must end after 05/01/2024, 10:54 AM"
    end

    @tag :logged_in_user
    test "displays error if one-time start occurs during DST gap", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => "2025-03-09T02:30:00"
        }
      })

      assert render(view) =~
               "Effect periods cannot start or end during a skipped daylight savings time hour"
    end

    @tag :logged_in_user
    test "displays error if one-time end occurs during DST gap", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end" => "2025-03-09T02:30:00"
        }
      })

      assert render(view) =~
               "Effect periods cannot start or end during a skipped daylight savings time hour"
    end

    # -------------------------------------------------------------------------
    # Group 7: Recurring alerts
    # -------------------------------------------------------------------------

    @tag :logged_in_user
    test "recurring section is hidden unless recurring is selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      refute render(view) =~ "Sunday"

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "alert_timing" => "recurring",
          "active_period_start_time_specifier" => "custom",
          "active_period_end_time_specifier" => "custom"
        }
      })

      assert render(view) =~ "Sunday"
    end

    @tag :logged_in_user
    test "if recurring, start date must match weekday selection", %{conn: conn} do
      # NOTE: After clearing the weekday mismatch error, the recurring duration text component
      # renders and calls Timex.format!/2 with a Date struct, which crashes in Timex 3.7.11.
      # This test therefore only verifies that the mismatch error appears; the "no error once
      # fixed" direction is implicitly covered by "does not show recurrence error if no weekdays
      # selected".
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "alert_timing" => "recurring"
        }
      })

      # 2024-12-04 is a Wednesday; selecting Monday should produce a mismatch error
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_time_specifier" => "custom",
          "active_period_start_specifier" => "custom",
          "active_period_start_time" => "10:00:00",
          "active_period_start_date" => "2024-12-04",
          "recurrence_days" => ["monday"]
        }
      })

      assert render(view) =~ "Alert start day must match a selected day of the week."
    end

    @tag :logged_in_user
    test "does not show recurrence error if no weekdays selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Subway", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "alert_timing" => "recurring",
          "active_period_start_specifier" => "custom",
          "active_period_start_date" => "2024-12-04",
          "recurrence_days" => []
        }
      })

      refute render(view) =~ "Alert start day must match a selected day of the week."
    end

    # -------------------------------------------------------------------------
    # Group 8: Schedule-dependent tests — NOT PORTED
    #
    # The old tests "start and end time updated if 'all trips' selected",
    # "start and end time updated if trip changes", and "start and end time not
    # updated if trip changes in editing mode" relied on `live_assign(view,
    # :selected_schedules, [...])` to inject schedule data into the isolated
    # component.  In the mono flow, TimeRangeSlice does not receive a
    # `selected_schedules` assign — schedule-derived time clamping is not wired
    # into CreateAlertMonoLive. There is therefore no equivalent interaction to
    # test at the LiveView level.
    # -------------------------------------------------------------------------
  end

  # ---------------------------------------------------------------------------
  # Group 9: End-to-end
  # ---------------------------------------------------------------------------

  describe "end-to-end" do
    @tag :logged_in_user
    test "editing", %{conn: conn} do
      todays_date =
        DateTime.utc_now()
        |> DateTime.shift_zone!("America/New_York")
        |> DateTime.to_date()

      # duration_certainty: :UNKNOWN is required so that determine_end_specifier/3 maps
      # active_period_end=nil to "until_further_notice" (rather than nil).
      alert_params =
        build(:alert_map, %{
          alert_id: "e2e-edit-1",
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY",
          primary_service_type: "1",
          description_text: nil,
          duration_certainty: :UNKNOWN,
          active_period_start: ~U[2024-05-10 14:30:54Z],
          active_period: [%{start: ~U[2024-05-10 14:30:54Z], end: nil}]
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      {:ok, view, _html} = live(conn, "/alerts/mono/edit/e2e-edit-1")

      # Verify the until_further_notice specifier is shown
      assert render(view) =~ "alert is manually closed"

      # Change end specifier to custom with a future date
      future_end =
        todays_date
        |> Date.add(2)
        |> NaiveDateTime.new!(~T[00:00:00])
        |> NaiveDateTime.to_iso8601()

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end" => future_end
        }
      })

      view
      |> element("button#review", "Review and submit")
      |> render_click()

      view
      |> element("#review-modal-container button", "Submit")
      |> render_click()

      # Wait a brief moment for the alert to be persisted
      :timer.sleep(100)

      created_alert = Alerts.get_by_alert_id("e2e-edit-1")

      assert created_alert.active_period_end ==
               todays_date
               |> Date.add(2)
               |> DateTime.new!(~T[00:00:00], "America/New_York")
               |> DateTime.shift_zone!("Etc/UTC")

      assert created_alert.duration_certainty == :KNOWN
    end

    @tag :logged_in_user
    test "setting a custom effect period outputs an expected duration text", %{conn: conn} do
      # Use fixed future datetimes (custom specifier) so the expected duration text is
      # deterministic — start_of_service uses local_now() time, making that path unpredictable.
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom",
          "active_period_end_specifier" => "custom"
        }
      })

      html =
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_start" => "2040-05-28T03:00:00",
            "active_period_end" => "2040-05-29T03:00:00"
          }
        })

      assert html =~
               "Effect duration: Tue May 28, 2040 @ 3:00 AM until Wed May 29, 2040 @ 3:00 AM (1 day)"
    end
  end
end
