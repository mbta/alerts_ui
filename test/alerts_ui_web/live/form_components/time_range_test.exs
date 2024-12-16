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

      refute view |> render() =~ ~s(Sunday)

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "alert_timing" => "recurring",
          "active_period_start_date_specifier" => "custom",
          "active_period_start_date" => "2024-12-04",
          "recurrence_days" => ["monday"]
        }
      })

      assert view |> render() =~ ~s(Alert start day must match a selected day of the week.)
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
