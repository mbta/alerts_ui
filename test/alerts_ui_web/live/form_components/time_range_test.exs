defmodule AlertsUIWeb.FormComponents.TimeRangeTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.FormComponents.TimeRange
  alias AlertsUIWeb.Step
  alias MBTAV3API.Schedules.Trip

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

    test "editing does not check start time" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      live_assign(view, %{
        editing: true,
        alert_data: %{
          active_period_start: ~N[2024-04-30 11:54:00],
          active_period_end_specifier: "custom"
        }
      })

      assert view
             |> render() =~ "custom"

      refute_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:add_errors,
                       [{:active_period_start_date, {"Effect can't start in the past", []}}],
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
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      start_time =
        DateTime.utc_now()
        |> DateTime.add(1, :hour)
        |> DateTime.shift_zone!("America/New_York")
        |> DateTime.truncate(:second)
        |> DateTime.to_naive()

      live_assign(view, %{
        editing: true,
        alert_data: %{
          active_period_start: start_time,
          active_period_start_specifier: "custom",
          active_period_end_specifier: "until_further_notice",
          active_period_end: ""
        }
      })

      assert view
             |> render() =~ "custom"

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
      schedule = %EnhancedSchedule{
        trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
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
end
