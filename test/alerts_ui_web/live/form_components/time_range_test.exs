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
    editing: false,
    current_time: "2024-04-30T09:33:20"
  }

  describe "component" do
    test "renders" do
      assert render_component(TimeRange, @assigns) =~ ~s(id="time_range_form")
    end

    test "enddate picker only active if pick option selected" do
      {:ok, view, _html} =
        live_isolated_component(
          TimeRange,
          @assigns
        )

      assert view
             |> render() =~ ~s(\" type=\"date\" disabled=\"disabled\")

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "active_period_start_specifier" => "custom",
          "active_period_end_specifier" => "custom"
        }
      })

      refute view
             |> render() =~ ~s(\" type=\"date\" disabled=\"disabled\")
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

    test "it sends section_completed if no error in changeset" do
      {:ok, view, _html} =
        live_isolated_component(TimeRange, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "time_range" => %{
          "end_date" => "2024-05-01",
          "end_time" => "09:54",
          "active_period_end_specifier" => "custom",
          "start_date" => "2024-05-01",
          "start_time" => "08:54"
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
