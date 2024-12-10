defmodule AlertsUIWeb.FormComponents.TimeRangeTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest
  alias AlertsUIWeb.FormComponents.TimeRange
  alias AlertsUIWeb.Step

  @assigns %{
    id: "time_range",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Time Range"
    },
    alert_data: %{},
    current_time: ~U[2024-04-30 15:54:00Z],
    edited: false,
    editing: false
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
               ~s(<div phx-feedback-for="time_range[active_period_end_date]" class="min-w-[16rem] h-10 hidden">)

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
               ~s(<div phx-feedback-for="time_range[active_period_end_date]" class="min-w-[16rem] h-10 hidden">)
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

    test "displays error if end after start" do
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

    test "scheduled datetime is hidden unless selection is made" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      refute view |> render() =~ ~s(id="time_range_notification_period_start")

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "notification_specifier" => "custom"
        }
      })

      assert view |> render() =~ ~s(id="time_range_notification_period_start")
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

    test "scheduled start time must be after current time" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "alert_timing" => "recurring",
          "active_period_start_specifier" => "custom",
          "active_period_start" => "2024-05-01T10:54:00",
          "notification_specifier" => "custom",
          "notification_period_start" => "2024-04-29T10:54:00"
        }
      })

      assert render(view) =~ ~s(Notifications can’t be set in the past)
    end

    test "scheduled start time must be before active period start" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      view
      |> element("#time_range_notification_specifier")
      |> render_change(%{
        "time_range" => %{
          "alert_timing" => "one-time",
          "active_period_start_specifier" => "custom",
          "active_period_start" => "2024-05-01T10:54:00",
          "notification_specifier" => "custom",
          "notification_period_start" => "2024-05-02T10:54:00"
        }
      })

      assert render(view) =~ ~s(Notification period must start on or before 05/01/2024, 10:54 AM)
    end

    test "it sends section_completed if no error in changeset" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "custom",
          "notification_specifier" => "now"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end" => "2024-05-01T09:54:00",
          "active_period_start" => "2024-05-01T08:54:00",
          "notification_period_start" => "2024-05-01T08:55:00"
        }
      })

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:section_completed,
                       %TimeRange{
                         active_period_end: ~N[2024-05-01 09:54:00],
                         active_period_end_specifier: :custom,
                         active_period_start: ~N[2024-05-01 08:54:00],
                         notification_period_start: ~N[2024-05-01 08:55:00]
                       }}}
    end
  end
end
