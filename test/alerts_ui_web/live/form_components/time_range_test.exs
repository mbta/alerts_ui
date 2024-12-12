defmodule AlertsUIWeb.FormComponents.TimeRangeTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest
  alias AlertsUIWeb.FormComponents.TimeRange
  alias AlertsUIWeb.Step
  alias MBTAV3API.Schedules.{Schedule, Trip}

  @assigns %{
    id: "time_range",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Time Range"
    },
    alert_data: %{trip_ids: ["CR-683322-595"]},
    current_time: ~U[2024-04-30 15:54:00Z],
    edited: false,
    editing: false,
    selected_trips: []
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
               ~s(<div phx-feedback-for="time_range[active_period_end_date]" class="min-w-[16rem] max-w-[16rem] h-10 hidden">)

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
               ~s(<div phx-feedback-for="time_range[active_period_end_date]" class="min-w-[16rem] max-w-[16rem] h-10 hidden">)
    end

    test "works if editing" do
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

    test "displays error if start after trip end" do
      schedule = %Schedule{
        trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
        arrival_time: ~U[2024-05-01 09:15:00.00Z],
        departure_time: ~U[2024-05-01 08:15:00.00Z]
      }

      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns |> Map.put(:selected_trips, [schedule]))

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

    test "doesn't display error if start within 1 hour of trip end" do
      schedule = %Schedule{
        trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
        arrival_time: ~U[2024-05-01 09:15:00.00Z],
        departure_time: ~U[2024-05-01 08:15:00.00Z]
      }

      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns |> Map.put(:selected_trips, [schedule]))

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
