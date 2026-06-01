defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.TimeRangeSliceTest do
  @moduledoc false
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  import Phoenix.LiveViewTest
  import Test.Support.Helpers
  import Mock

  alias AlertsUI.Alerts
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.AffectedServiceSlice
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.TimeRangeSlice
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop
  alias Phoenix.LiveView.AsyncResult

  defp create_test_alert(alert_id, opts \\ []) do
    ap =
      build(
        :active_period,
        Keyword.get(opts, :active_period_attrs, %{start: ~U[2024-05-10 14:30:54Z]})
      )

    params =
      build(:alert_map, %{
        alert_id: alert_id,
        active_period: [Map.from_struct(ap)],
        active_period_start: ~U[2024-05-10 14:30:54Z],
        duration_certainty: Keyword.get(opts, :duration_certainty, :UNKNOWN),
        effect: Keyword.get(opts, :effect, :OTHER_EFFECT),
        effect_detail: Keyword.get(opts, :effect_detail, "DELAY"),
        informed_entity: [%{route_type: 3, activities: [:BOARD]}],
        original_route_selections: Keyword.get(opts, :original_route_selections, nil),
        reminder_times: [],
        severity: 4,
        primary_service_type: "3",
        # Keep description_text nil so description_sync_toggle stays true, preventing a
        # crash in AlertDetailsSlice when autotext is built with %{} (pre-existing bug).
        description_text: nil
      })

    {:ok, _} = Alerts.create_or_update_alert(params, build(:user))
  end

  # Fixtures for trip selection unit tests
  @future_departure ~U[2040-01-01 10:00:00Z]
  @future_arrival ~U[2040-01-01 13:00:00Z]
  @past_departure ~U[2024-01-01 10:00:00Z]
  @past_arrival ~U[2024-01-01 13:00:00Z]

  defp trip_changeset(attrs \\ %{}) do
    Ecto.Changeset.cast(%AlertData{}, Map.merge(%{trip_ids: []}, attrs), [:trip_ids])
  end

  defp trip_validate_changeset(trip_ids, active_period_start) do
    Ecto.Changeset.cast(
      %AlertData{},
      %{trip_ids: trip_ids, active_period_start: active_period_start, alert_timing: :"one-time"},
      [:trip_ids, :active_period_start, :alert_timing]
    )
  end

  defp socket_with_trip_selections(schedules) do
    %{
      assigns: %{
        selections: %AsyncResult{
          ok?: true,
          result: %AffectedServiceSlice.Selections{available_schedules: schedules}
        }
      }
    }
  end

  defp socket_for_transform(schedules, form_type \\ :creating) do
    %{
      assigns: %{
        form_type: form_type,
        selections: %AffectedServiceSlice.Selections{available_schedules: schedules}
      }
    }
  end

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Delay")
      assert render(view) =~ ~s(id="time_range_view")
    end

    @tag :logged_in_user
    test "enddate picker hidden unless end_of_service option selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Delay")

      assert view
             |> render() =~
               ~s(phx-feedback-for="alert_data[active_period_end_date]" class="md:min-w-64 md:max-w-64 hidden")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "end_of_service"
        }
      })

      refute view
             |> render() =~
               ~s(phx-feedback-for="alert_data[active_period_end_date]" class="md:min-w-64 md:max-w-64 hidden")
    end

    @tag :logged_in_user
    test "switching between start specifiers retains old date", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Delay")

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
          "active_period_start" => ~N[2025-03-28 03:00:00]
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "start_of_service"
        }
      })

      assert render(view) =~ ~s(value="2025-03-28")
    end

    @tag :logged_in_user
    test "switching between end specifiers retains old date", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Delay")

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
          "active_period_end" => ~N[2025-03-28 03:00:00]
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "end_of_service"
        }
      })

      assert render(view) =~ ~s(value="2025-03-28")
    end

    @tag :logged_in_user
    test "displays error if end before start", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Delay")

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

      assert render(view) =~ ~s(Effect must end after 05/01/2024, 10:54 AM)
    end

    @tag :logged_in_user
    test "displays error if one-time start occurs during DST gap", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Delay")

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
               ~s(Effect periods cannot start or end during a skipped daylight savings time hour)
    end

    @tag :logged_in_user
    test "displays error if one-time end occurs during DST gap", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Delay")

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
               ~s(Effect periods cannot start or end during a skipped daylight savings time hour)
    end

    @tag :logged_in_user
    test "recurring section is hidden unless recurring is selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Delay")

      refute view |> render() =~ ~s(Sunday)

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "alert_timing" => "recurring",
          "active_period_start_time_specifier" => "custom",
          "active_period_end_time_specifier" => "custom"
        }
      })

      assert view |> render() =~ ~s(Sunday)
    end

    @tag :logged_in_user
    test "if recurring, start date must match weekday selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "alert_timing" => "recurring"
        }
      })

      # 2024-12-03 is a Tuesday
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_time_specifier" => "custom",
          "active_period_start_specifier" => "custom",
          "active_period_start_time" => "10:00:00",
          "active_period_start" => "2024-12-03T10:00:00",
          "recurrence_days" => ["monday"]
        }
      })

      assert view |> render() =~ ~s(Alert start day must match a selected day of the week.)

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "recurrence_days" => ["tuesday"]
        }
      })

      refute view |> render() =~ ~s(Alert start day must match a selected day of the week.)
    end

    @tag :logged_in_user
    test "does not show recurrence error if no weekdays selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "alert_timing" => "recurring",
          "active_period_start_specifier" => "custom",
          "active_period_start" => "2024-12-04T10:00:00",
          "recurrence_days" => []
        }
      })

      refute view |> render() =~ ~s(Alert start day must match a selected day of the week.)
    end

    @tag :logged_in_user
    test "setting effect to end of service outputs an expected duration text", %{conn: conn} do
      # Use a fixed far-future start time so the start is not "in the past"
      # and the end_of_service end (3:00 AM next day) is guaranteed after it.
      start_dt = ~N[2040-12-16 03:00:00]
      end_date = ~D[2040-12-17]
      # end_of_service sets active_period_end to end_date @ 3:00 AM
      end_dt = NaiveDateTime.new!(end_date, ~T[03:00:00])

      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom",
          "active_period_end_specifier" => "end_of_service"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => NaiveDateTime.to_iso8601(start_dt),
          "active_period_end_date" => Date.to_iso8601(end_date)
        }
      })

      start_text = Calendar.strftime(start_dt, "%a %b %-d, %Y @ %-I:%M %p")
      end_text = Calendar.strftime(end_dt, "%a %b %-d, %Y @ %-I:%M %p")

      assert render(view) =~ "Effect duration: #{start_text} until #{end_text} (1 day)"
    end

    @tag :logged_in_user
    test "displays error if start invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"active_period_start_specifier" => "custom"}})

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"active_period_start" => "a"}})

      assert render(view) =~ "Enter a valid datetime"
    end

    @tag :logged_in_user
    test "displays error if end invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Bus", "Delay")

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
      |> render_change(%{"alert_data" => %{"active_period_end" => "s"}})

      assert render(view) =~ "Enter a valid datetime"
    end
  end

  describe "editing" do
    @tag :logged_in_user
    test "editing keeps correct end time specifier when there is no end time", %{conn: conn} do
      create_test_alert("tr-edit-1", duration_certainty: :UNKNOWN)

      {:ok, view, _html} = live(conn, "/alerts/mono/edit/tr-edit-1")

      assert view |> render() =~ "alert is manually closed"
      refute view |> render() =~ "until later today"
    end

    @tag :logged_in_user
    test "editing custom fields to start/end of service correctly validates", %{conn: conn} do
      create_test_alert("tr-edit-2",
        duration_certainty: :KNOWN,
        active_period_attrs: %{start: ~U[2040-04-29 10:54:00Z], end: ~U[2040-04-30 15:59:00Z]}
      )

      {:ok, view, _html} = live(conn, "/alerts/mono/edit/tr-edit-2")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "end_of_service"
        }
      })

      refute view |> render() =~ "Effect must end after"
    end

    @tag :logged_in_user
    test "editing saves updated end time to database", %{conn: conn} do
      bus_route = %Route{id: "22", type: 3, name: "Route 22"}

      create_test_alert("tr-edit-db-1",
        duration_certainty: :UNKNOWN,
        active_period_attrs: %{start: ~U[2024-05-10 14:30:54Z]},
        original_route_selections: ["Route 22|22"]
      )

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> [bus_route] end,
           get: fn _id, _opts -> bus_route end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           get_parent: fn _stop_id -> nil end
         ]},
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]},
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/edit/tr-edit-db-1")
        render_async(view, 3000)

        future_end =
          NaiveDateTime.utc_now()
          |> NaiveDateTime.add(2, :day)
          |> NaiveDateTime.truncate(:second)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_end_specifier" => "custom",
            "active_period_end" => NaiveDateTime.to_iso8601(future_end)
          }
        })

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        :timer.sleep(50)
        updated = Alerts.get_by_alert_id("tr-edit-db-1")
        assert updated.duration_certainty == :KNOWN
      end
    end

    @tag :logged_in_user
    test "editing does not check start time", %{conn: conn} do
      create_test_alert("tr-edit-3", duration_certainty: :UNKNOWN)

      {:ok, view, _html} = live(conn, "/alerts/mono/edit/tr-edit-3")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "later_today"
        }
      })

      refute view |> render() =~ "Effect can't start in the past"
    end
  end

  describe "duplicating" do
    @tag :logged_in_user
    test "duplicating keeps correct end time specifier when there is no end time", %{conn: conn} do
      create_test_alert("tr-dup-1", duration_certainty: :UNKNOWN)

      {:ok, view, _html} = live(conn, "/alerts/mono/duplicate/tr-dup-1")

      assert view |> render() =~ "alert is manually closed"
      refute view |> render() =~ "until later today"
    end

    @tag :logged_in_user
    test "duplicating DOES check start time", %{conn: conn} do
      create_test_alert("tr-dup-2", duration_certainty: :UNKNOWN)

      {:ok, view, _html} = live(conn, "/alerts/mono/duplicate/tr-dup-2")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "later_today"
        }
      })

      assert view |> render() =~ "Effect can&#39;t start in the past"
    end
  end

  describe "trip selection" do
    test "populates start and end from trip when departure is in the future" do
      schedule = %EnhancedSchedule{
        route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @future_departure,
        time_of_last_trip_arrival: @future_arrival
      }

      changeset = trip_changeset(%{trip_ids: ["trip-595"]})
      socket = socket_with_trip_selections([schedule])

      result =
        Slice.transform(
          %TimeRangeSlice{},
          changeset,
          %{"_target" => ["alert_data", "trip_ids"], "alert_data" => %{}},
          socket
        )

      assert Ecto.Changeset.get_field(result, :active_period_start_specifier) == :custom

      assert Ecto.Changeset.get_field(result, :active_period_start) ==
               DateTime.to_naive(@future_departure)

      assert Ecto.Changeset.get_field(result, :active_period_end_specifier) == :custom

      expected_end = DateTime.to_naive(@future_arrival) |> NaiveDateTime.add(1, :hour)
      assert Ecto.Changeset.get_field(result, :active_period_end) == expected_end
    end

    test "sets start specifier to now when trip departure has already passed" do
      schedule = %EnhancedSchedule{
        route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @past_departure,
        time_of_last_trip_arrival: @past_arrival
      }

      changeset = trip_changeset(%{trip_ids: ["trip-595"]})
      socket = socket_with_trip_selections([schedule])

      result =
        Slice.transform(
          %TimeRangeSlice{},
          changeset,
          %{"_target" => ["alert_data", "trip_ids"], "alert_data" => %{}},
          socket
        )

      assert Ecto.Changeset.get_field(result, :active_period_start_specifier) == :now
      assert Ecto.Changeset.get_field(result, :active_period_end_specifier) == :custom

      expected_end = DateTime.to_naive(@past_arrival) |> NaiveDateTime.add(1, :hour)
      assert Ecto.Changeset.get_field(result, :active_period_end) == expected_end
    end

    test "displays error if start after trip end when start changes" do
      schedule = %EnhancedSchedule{
        route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @future_departure,
        time_of_last_trip_arrival: @future_arrival
      }

      late_start = DateTime.to_naive(@future_arrival) |> NaiveDateTime.add(61, :minute)
      changeset = trip_validate_changeset(["trip-595"], late_start)
      socket = socket_with_trip_selections([schedule])

      result = Slice.validate(%TimeRangeSlice{}, changeset, %{}, socket)

      deadline = DateTime.to_naive(@future_arrival) |> NaiveDateTime.add(1, :hour)

      expected_msg =
        "Effect must start before #{Calendar.strftime(deadline, "%m/%d/%Y, %I:%M %p")}"

      assert {^expected_msg, []} = result.errors[:active_period_start]
    end

    test "no error if start after trip end when start changes on recurring alert" do
      schedule = %EnhancedSchedule{
        route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @future_departure,
        time_of_last_trip_arrival: @future_arrival
      }

      late_start = DateTime.to_naive(@future_arrival) |> NaiveDateTime.add(61, :minute)

      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{trip_ids: ["trip-595"], active_period_start: late_start, alert_timing: :recurring},
          [:trip_ids, :active_period_start, :alert_timing]
        )

      socket = socket_with_trip_selections([schedule])

      result = Slice.validate(%TimeRangeSlice{}, changeset, %{}, socket)

      refute Keyword.has_key?(result.errors, :active_period_start)
    end

    test "displays error if start after trip end when 'start of service' is selected" do
      schedule = %EnhancedSchedule{
        route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @future_departure,
        time_of_last_trip_arrival: @future_arrival
      }

      late_start = DateTime.to_naive(@future_arrival) |> NaiveDateTime.add(61, :minute)

      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{
            trip_ids: ["trip-595"],
            active_period_start: late_start,
            active_period_start_specifier: :start_of_service,
            alert_timing: :"one-time"
          },
          [:trip_ids, :active_period_start, :active_period_start_specifier, :alert_timing]
        )

      socket = socket_with_trip_selections([schedule])

      result = Slice.validate(%TimeRangeSlice{}, changeset, %{}, socket)

      deadline = DateTime.to_naive(@future_arrival) |> NaiveDateTime.add(1, :hour)

      expected_msg =
        "Effect must start before #{Calendar.strftime(deadline, "%m/%d/%Y, %I:%M %p")}"

      assert {^expected_msg, []} = result.errors[:active_period_start]
    end

    test "doesn't display error if start within 1 hour of trip end" do
      schedule = %EnhancedSchedule{
        route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @future_departure,
        time_of_last_trip_arrival: @future_arrival
      }

      # exactly 60 minutes after arrival — the diff is NOT > 60, so no error
      on_time_start = DateTime.to_naive(@future_arrival) |> NaiveDateTime.add(60, :minute)
      changeset = trip_validate_changeset(["trip-595"], on_time_start)
      socket = socket_with_trip_selections([schedule])

      result = Slice.validate(%TimeRangeSlice{}, changeset, %{}, socket)

      refute Keyword.has_key?(result.errors, :active_period_start)
    end

    test "if recurring, active_period_end should be the last active period end" do
      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{
            alert_timing: "recurring",
            active_period_end_specifier: :custom,
            active_period_end_date: ~D[2024-12-17],
            active_period_end: ~N[2024-12-17 10:00:00],
            recurrence_days: [:tuesday]
          },
          [
            :alert_timing,
            :active_period_end_specifier,
            :active_period_end_date,
            :active_period_end,
            :recurrence_days
          ]
        )

      socket = socket_with_trip_selections([])

      result =
        Slice.transform(
          %TimeRangeSlice{},
          changeset,
          %{"_target" => ["alert_data", "active_period_end_date"], "alert_data" => %{}},
          socket
        )

      assert Ecto.Changeset.get_field(result, :active_period_end_date) == ~D[2024-12-17]
      assert Ecto.Changeset.get_field(result, :active_period_end_specifier) == :custom
    end

    test "if recurring and no end time, active_period_end should reflect that" do
      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{
            alert_timing: "recurring",
            active_period_end_specifier: :until_further_notice,
            recurrence_days: [:tuesday]
          },
          [:alert_timing, :active_period_end_specifier, :recurrence_days]
        )

      socket = socket_with_trip_selections([])

      result =
        Slice.transform(
          %TimeRangeSlice{},
          changeset,
          %{"_target" => ["alert_data", "active_period_end_specifier"], "alert_data" => %{}},
          socket
        )

      assert Ecto.Changeset.get_field(result, :active_period_end_specifier) ==
               :until_further_notice

      # until_further_notice sets active_period_end to today's 23:59:59 as a sentinel value
      refute is_nil(Ecto.Changeset.get_field(result, :active_period_end))
    end

    test "resets start and end to defaults when all trips are deselected" do
      schedule = %EnhancedSchedule{
        route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @future_departure,
        time_of_last_trip_arrival: @future_arrival
      }

      # Simulate the state after a trip was selected: custom specifiers are set
      changeset =
        trip_changeset()
        |> Ecto.Changeset.put_change(:active_period_start_specifier, :custom)
        |> Ecto.Changeset.put_change(:active_period_end_specifier, :custom)

      socket = socket_with_trip_selections([schedule])

      result =
        Slice.transform(
          %TimeRangeSlice{},
          changeset,
          %{"_target" => ["alert_data", "trip_ids"], "alert_data" => %{}},
          socket
        )

      assert Ecto.Changeset.get_field(result, :active_period_start_specifier) == :now
      assert Ecto.Changeset.get_field(result, :active_period_end_specifier) == :later_today
    end

    test "start and end time updated if 'all trips' selected" do
      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{
            trip_ids: [],
            active_period_start_specifier: :custom,
            active_period_end_specifier: :custom,
            active_period_start: ~N[2040-01-01 10:16:00],
            active_period_end: ~N[2040-01-01 11:54:00]
          },
          [
            :trip_ids,
            :active_period_start_specifier,
            :active_period_end_specifier,
            :active_period_start,
            :active_period_end
          ]
        )

      socket = socket_for_transform([])

      result =
        Slice.transform(
          %TimeRangeSlice{},
          changeset,
          %{"_target" => ["alert_data", "trip_ids"], "alert_data" => %{}},
          socket
        )

      assert Ecto.Changeset.get_field(result, :active_period_start_specifier) == :now
      assert Ecto.Changeset.get_field(result, :active_period_end_specifier) == :later_today
      refute Ecto.Changeset.get_field(result, :active_period_start) == ~N[2040-01-01 10:16:00]
      refute Ecto.Changeset.get_field(result, :active_period_end) == ~N[2040-01-01 11:54:00]
    end

    test "start and end time updated if trip changes and departure before current time" do
      schedule = %EnhancedSchedule{
        route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @past_departure,
        time_of_last_trip_arrival: @past_arrival
      }

      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{
            trip_ids: ["trip-595"],
            active_period_start_specifier: :custom,
            active_period_end_specifier: :custom,
            active_period_start: ~N[2040-01-01 10:16:00],
            active_period_end: ~N[2040-01-01 11:54:00]
          },
          [
            :trip_ids,
            :active_period_start_specifier,
            :active_period_end_specifier,
            :active_period_start,
            :active_period_end
          ]
        )

      socket = socket_for_transform([schedule])

      result =
        Slice.transform(
          %TimeRangeSlice{},
          changeset,
          %{"_target" => ["alert_data", "trip_ids"], "alert_data" => %{}},
          socket
        )

      assert Ecto.Changeset.get_field(result, :active_period_start_specifier) == :now
      assert Ecto.Changeset.get_field(result, :active_period_end_specifier) == :custom
      expected_end = DateTime.to_naive(@past_arrival) |> NaiveDateTime.add(1, :hour)
      assert Ecto.Changeset.get_field(result, :active_period_end) == expected_end
    end

    test "start and end time not updated if trip changes and departure before current time but form is in editing mode" do
      schedule = %EnhancedSchedule{
        route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @past_departure,
        time_of_last_trip_arrival: @past_arrival
      }

      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{
            trip_ids: ["trip-595"],
            active_period_start_specifier: :custom,
            active_period_end_specifier: :custom,
            active_period_start: ~N[2040-01-01 10:16:00],
            active_period_end: ~N[2040-01-01 11:54:00]
          },
          [
            :trip_ids,
            :active_period_start_specifier,
            :active_period_end_specifier,
            :active_period_start,
            :active_period_end
          ]
        )

      socket = socket_for_transform([schedule], :editing)

      result =
        Slice.transform(
          %TimeRangeSlice{},
          changeset,
          %{"_target" => ["alert_data", "trip_ids"], "alert_data" => %{}},
          socket
        )

      assert Ecto.Changeset.get_field(result, :active_period_start_specifier) == :custom
      assert Ecto.Changeset.get_field(result, :active_period_end_specifier) == :custom
      assert Ecto.Changeset.get_field(result, :active_period_start) == ~N[2040-01-01 10:16:00]
      assert Ecto.Changeset.get_field(result, :active_period_end) == ~N[2040-01-01 11:54:00]
    end
  end
end
