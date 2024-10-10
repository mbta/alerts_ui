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
        live_isolated_component(
          TimeRange,
          @assigns
          |> Map.merge(%{
            editing: true,
            alert_data: %{
              active_period_start: ~N[2024-04-30 11:54:00],
              active_period_end_specifier: :custom
            }
          })
        )

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
          "active_period_start" => "",
          "active_period_start_specifier" => "custom"
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
          "active_period_end" => "s",
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "custom"
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
          "active_period_end" => "2024-05-01T09:54:00",
          "active_period_start" => "2024-05-01T10:54:00",
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "custom"
        }
      })

      assert render(view) =~ ~s(Effect must end after 05/01/2024, 10:54 AM)
    end

    test "scheduled section is hidden unless scheduled is selected" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      refute view |> render() =~ ~s(id="scheduled-selector-div")

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "alert_timing" => "scheduled"
        }
      })

      assert view |> render() =~ ~s(id="scheduled-selector-div")
    end

    test "scheduled start time must be after active period start" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "alert_timing" => "scheduled",
          "active_period_start" => "2024-05-01T10:54:00",
          "active_period_start_specifier" => "custom",
          "notification_period_start" => "2024-04-29T10:54:00"
        }
      })

      assert render(view) =~ ~s(Effect must start after 05/01/2024, 10:54 AM)
    end

    test "scheduled start time must be before active period end" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "alert_timing" => "scheduled",
          "active_period_end_specifier" => "custom",
          "active_period_end" => "2024-05-01T10:54:00",
          "notification_period_start" => "2024-05-02T10:54:00"
        }
      })

      assert render(view) =~ ~s(Effect must end before 05/01/2024, 10:54 AM)
    end

    test "it sends section_completed if no error in changeset" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end" => "2024-05-01T09:54:00",
          "active_period_start" => "2024-05-01T08:54:00",
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "custom"
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
