defmodule AlertsUIWeb.FormComponents.TimeRangeTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers
  alias AlertsUI.Alerts
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.FormComponents.TimeRange
  alias AlertsUIWeb.Step
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @assigns %{
    id: "time_range",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Time Range"
    },
    alert_data: %{trip_ids: ["CR-683322-595"]},
    current_time: ~N[2024-04-30 15:54:00],
    edited: false,
    editing: false,
    selected_schedules: []
  }

  @schedule %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: nil,
    departure_time: DateTime.utc_now() |> DateTime.add(-1, :hour),
    time_of_last_trip_arrival:
      ~U[2024-05-01 13:15:00.00Z] |> DateTime.shift_zone!("America/New_York")
  }

  @schedule_2 %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: DateTime.utc_now(),
    departure_time: nil
  }

  @route %Route{
    direction_names: %{0 => "Westbound", 1 => "Eastbound"},
    sort_order: 3,
    id: "CR-Worcester",
    type: 2,
    name: "Framingham/Worcester Line"
  }

  @stop %Stop{id: "place-sstat", name: "South Station"}

  describe "component" do
    test "renders" do
      assert render_component(TimeRange, @assigns) =~ ~s(id="time_range_form")
    end

    test "enddate picker hidden unless pick option selected" do
      {:ok, view, _html} =
        live_isolated_component(
          TimeRange,
          @assigns
        )

      assert view
             |> render() =~
               ~s(phx-feedback-for="time_range[active_period_end_date]" class="min-w-[16rem] max-w-[16rem] hidden")

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_start_specifier" => "custom",
          "active_period_end_specifier" => "end_of_service"
        }
      })

      refute view
             |> render() =~
               ~s(phx-feedback-for="time_range[active_period_end_date]" class="min-w-[16rem] max-w-[16rem] hidden")
    end

    test "editing keeps correct end time specifier when there is no end time" do
      {:ok, view, _html} =
        live_isolated_component(
          TimeRange,
          Map.merge(
            @assigns,
            %{
              editing: true,
              alert_data: %{
                active_period_start_specifier: "custom",
                active_period_start: ~N[2024-04-29 10:54:00],
                active_period_end_specifier: "until_further_notice",
                active_period_end: ~N[2024-04-30 11:59:00]
              }
            }
          )
        )

      assert view
             |> render() =~ "until alert is manually closed"

      refute view
             |> render() =~ "later today"
    end

    test "editing does not check start time" do
      {:ok, view, _html} =
        live_isolated_component(
          TimeRange,
          Map.merge(
            @assigns,
            %{
              editing: true,
              alert_data: %{
                active_period_start_specifier: "custom",
                active_period_start: ~N[2024-04-29 10:54:00],
                active_period_end_specifier: "until_further_notice",
                active_period_end: ~N[2024-04-30 11:59:00]
              }
            }
          )
        )

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end_specifier" => "later_today"
        }
      })

      refute_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:add_errors,
                       [{:active_period_start, {"Effect can't start in the past", []}}],
                       AlertsUIWeb.FormComponents.TimeRange}}
    end

    test "editing with error field sends error" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      live_assign(view, %{
        editing: true,
        alert_data: %{
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end: ~N[2024-04-30 10:54:00],
          active_period_end_specifier: "custom"
        }
      })

      assert view
             |> render() =~ "custom"

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:add_errors,
                       [{:active_period_end, {"Effect must end after 04/30/2024, 11:54 AM", []}}],
                       AlertsUIWeb.FormComponents.TimeRange}}
    end

    test "editing with no errors sends data" do
      start_time =
        DateTime.utc_now()
        |> DateTime.add(1, :hour)
        |> DateTime.shift_zone!("America/New_York")
        |> DateTime.truncate(:second)
        |> DateTime.to_naive()

      {:ok, view, _html} =
        live_isolated_component(
          TimeRange,
          Map.merge(
            @assigns,
            %{
              editing: true,
              alert_data: %{
                active_period_start: start_time,
                active_period_start_specifier: "custom",
                active_period_end_specifier: "later_today",
                active_period_end: NaiveDateTime.add(start_time, 1, :hour)
              }
            }
          )
        )

      assert view
             |> element("#time_range_active_period_start_specifier")
             |> render() =~ "custom"

      assert view
             |> render() =~ "until later today"

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end_specifier" => "until_further_notice"
        }
      })

      refute view
             |> render() =~ "until later today"

      assert view
             |> render() =~ "until alert is manually closed (indefinite)"

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:add_errors, [], AlertsUIWeb.FormComponents.TimeRange}}

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:section_completed,
                       %TimeRange{
                         active_period_start: ^start_time
                       }}}
    end

    test "displays error if start invalid" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_start" => "a"
        }
      })

      assert render(view) =~ ~s(Enter a valid datetime)
    end

    test "displays error if end invalid" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end" => "s"
        }
      })

      assert render(view) =~ ~s(Enter a valid datetime)
    end

    test "displays error if end before start" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end" => "2024-05-01T09:54:00",
          "active_period_start" => "2024-05-01T10:54:00"
        }
      })

      assert render(view) =~ ~s(Effect must end after 05/01/2024, 10:54 AM)
    end

    test "displays error if start after trip end when start changes" do
      schedule = %EnhancedSchedule{
        trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
        arrival_time: nil,
        time_of_last_trip_arrival:
          ~U[2024-05-01 13:15:00.00Z] |> DateTime.shift_zone!("America/New_York"),
        departure_time: ~U[2024-05-01 12:15:00.00Z] |> DateTime.shift_zone!("America/New_York")
      }

      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns |> Map.put(:selected_schedules, [schedule]))

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end" => "2024-05-01T11:54:00",
          "active_period_start" => "2024-05-01T10:16:00"
        }
      })

      assert render(view) =~ ~s(Effect must start before 05/01/2024, 10:15 AM)
    end

    test "displays error if start after trip end when 'start of service' is selected" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns |> Map.put(:selected_schedules, [@schedule]))

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "start_of_service"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_start" => ~N[2025-03-28 03:00:00],
          "active_period_end" => ~N[2025-03-28 19:43:00],
          "active_period_start_date" => ~D[2025-03-28],
          "active_period_start_time" => ~T[03:00:00]
        }
      })

      assert view |> element("#time_range_active_period_start_date-root-element") |> render =~
               ~s(Effect must start before 05/01/2024, 10:15 AM)
    end

    test "start and end time updated if 'all trips' selected" do
      {:ok, view, _html} =
        live_isolated_component(
          TimeRange,
          @assigns
          |> Map.put(:current_time, ~N[2024-05-01 08:15:00])
          |> Map.put(:selected_schedules, [@schedule])
        )

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end" => "2024-05-01T11:54:00",
          "active_period_start" => "2024-05-01T10:16:00"
        }
      })

      live_assign(view, :selected_schedules, [])

      assert render(view) =~ ~s(value=\"now\")
      assert render(view) =~ ~s(value=\"later_today\")
      assert render(view) =~ ~s(value=\"2024-05-01T08:15\")
    end

    test "start and end time updated if trip changes and departure before current time" do
      schedule = %EnhancedSchedule{
        trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
        arrival_time: nil,
        time_of_last_trip_arrival:
          ~U[2024-05-01 13:15:00.00Z] |> DateTime.shift_zone!("America/New_York"),
        departure_time: ~U[2024-05-01 12:15:00.00Z] |> DateTime.shift_zone!("America/New_York")
      }

      {:ok, view, _html} =
        live_isolated_component(
          TimeRange,
          @assigns |> Map.put(:current_time, ~N[2024-05-01 08:15:00])
        )

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end" => "2024-05-01T11:54:00",
          "active_period_start" => "2024-05-01T10:16:00"
        }
      })

      live_assign(view, :selected_schedules, [schedule])

      assert render(view) =~ ~s(value=\"now\")
      assert render(view) =~ ~s(value=\"2024-05-01T10:15\")
    end

    test "doesn't display error if start within 1 hour of trip end" do
      schedule = %EnhancedSchedule{
        trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
        arrival_time: nil,
        time_of_last_trip_arrival: ~U[2024-05-01 09:15:00.00Z],
        departure_time: ~U[2024-05-01 08:15:00.00Z]
      }

      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns |> Map.put(:selected_schedules, [schedule]))

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end" => "2024-05-01T11:54:00",
          "active_period_start" => "2024-05-01T10:14:00"
        }
      })

      refute render(view) =~ ~s(Effect must start before 05/01/2024, 10:15 AM)
    end

    test "recurring section is hidden unless recurring is selected" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      refute view |> render() =~ ~s(Sunday)

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "alert_timing" => "recurring",
          "active_period_start_time_specifier" => "custom",
          "active_period_end_time_specifier" => "custom"
        }
      })

      assert view |> render() =~ ~s(Sunday)
    end

    test "if recurring, start date must match weekday selection" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "alert_timing" => "recurring"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_start_time_specifier" => "custom",
          "active_period_start_date_specifier" => "custom",
          "active_period_start_time" => "10:00:00",
          "active_period_start_date" => ~D[2024-12-04],
          "recurrence_days" => ["monday"]
        }
      })

      assert view |> render() =~ ~s(Alert start day must match a selected day of the week.)

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "recurrence_days" => ["tuesday"]
        }
      })

      refute view |> render() =~ ~s(Alert start day must match a selected day of the week.)
    end

    test "does not show reccurrence error if no weekdays selected" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      refute view |> render() =~ ~s(Sunday)

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "alert_timing" => "recurring",
          "active_period_start_date_specifier" => "custom",
          "active_period_start_date" => "2024-12-04",
          "recurrence_days" => []
        }
      })

      refute view |> render() =~ ~s(Alert start day must match a selected day of the week.)
    end

    test "it sends section_completed if no error in changeset" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end" => "2024-05-01T09:54:00",
          "active_period_start" => "2024-05-01T08:54:00"
        }
      })

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:section_completed,
                       %TimeRange{
                         active_period_end: ~N[2024-05-01 09:54:00],
                         active_period_end_specifier: :custom,
                         active_period_start: ~N[2024-05-01 08:54:00]
                       }}}
    end
  end

  describe "end-to-end" do
    @tag :logged_in_user
    test "editing", %{conn: conn} do
      todays_date =
        DateTime.utc_now()
        |> DateTime.shift_zone!("America/New_York")
        |> DateTime.to_date()

      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _stop_id, _ -> [@route] end,
           by_type: fn _types -> [@route] end,
           all: fn _opts -> [@route] end,
           get: fn _, _ -> @route end,
           get: fn _ -> @route end
         ]},
        {SchedulesRepo, [],
         [
           all: fn _trip_id -> [@schedule, @schedule_2] end,
           by_route_ids: fn _route_ids, _opts ->
             [@schedule, @schedule_2]
           end,
           end_of_rating: fn -> Date.add(todays_date, 1) end,
           trip: fn _ ->
             %Trip{id: "CR-683322-595", name: "595", direction_id: 0}
           end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type -> [@stop] end,
           by_route: fn _, _ -> [@stop] end,
           get_parent: fn
             "place-sstat" -> @stop
           end,
           get: fn _ -> @stop end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [] end,
           included_stops_by_route_id: fn "CR-Worcester", _ ->
             [@stop]
           end
         ]}
      ]) do
        conn = put_resp_cookie(conn, "show_created_alert", "true")
        trip = build(:trip_descriptor, %{trip_id: @schedule.trip.id})
        ap = build(:active_period, %{start: ~U[2024-05-10 14:30:54Z]})

        ie =
          build(:informed_entity, %{
            route_id: @route.id,
            route_type: @route.type,
            activities: [:BOARD],
            stop_id: @stop.id,
            trip: Map.from_struct(trip),
            direction_id: 0
          })

        alert_params =
          build(
            :alert_map,
            %{
              alert_id: "123",
              header_text: "example header text",
              informed_entity: [Map.from_struct(ie)],
              effect: :SIGNIFICANT_DELAYS,
              effect_detail: "DELAY",
              original_route_selections: [@route.id],
              reminder_times: [],
              active_period: [Map.from_struct(ap)],
              active_period_start: ~U[2024-05-10 14:30:54Z],
              duration_certainty: :UNKNOWN,
              severity: 4
            }
          )

        {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

        {:ok, view, _html} = live(conn, "/alerts/edit?alert_id=123")

        rendered_view = render(view)

        assert rendered_view =~ ~s(Until further notice)

        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_end_specifier" => "custom"
          }
        })

        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_end" =>
              todays_date
              |> Date.add(2)
              |> NaiveDateTime.new!(~T[00:00:00])
              |> NaiveDateTime.to_iso8601()
          }
        })

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        view
        |> element("button", "Submit")
        |> render_click()

        # wait a smidge for the alert to get persisted to the database
        :timer.sleep(100)
        created_alert = Alerts.get_by_alert_id("123")

        assert created_alert.active_period_end ==
                 todays_date
                 |> Date.add(2)
                 |> DateTime.new!(~T[00:00:00], "America/New_York")
                 |> DateTime.shift_zone!("Etc/UTC")

        assert created_alert.duration_certainty == :KNOWN
      end
    end

    @tag :logged_in_user
    test "setting effect to end of service outputs an expected duration text", %{conn: conn} do
      todays_date =
        DateTime.utc_now()
        |> DateTime.shift_zone!("America/New_York")
        |> DateTime.to_date()

      # Effect starts first thing tomorrow
      tomorrows_date = Date.add(todays_date, 1)
      # Effect ends at end of service same day, which is morning of next day
      next_day_date = Date.add(todays_date, 2)

      with_mocks([]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Bus", "Delay")

        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_start_specifier" => "start_of_service",
            "active_period_end_specifier" => "end_of_service"
          }
        })

        html =
          view
          |> element("#time_range_form")
          |> render_change(%{
            "time_range" => %{
              "active_period_start_date" => tomorrows_date,
              "active_period_end_date" => tomorrows_date
            }
          })

        assert html =~
                 "Effect duration: #{Calendar.strftime(tomorrows_date, "%a %b %-d, %Y")} @ 3:00 AM until #{Calendar.strftime(next_day_date, "%a %b %-d, %Y")} @ 3:00 AM (1 day)"
      end
    end
  end
end
