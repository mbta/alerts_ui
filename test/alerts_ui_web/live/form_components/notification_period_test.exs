defmodule AlertsUIWeb.FormComponents.NotificationPeriodTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest
  import Mock
  alias AlertsUIWeb.FormComponents.NotificationPeriod
  alias AlertsUIWeb.Step

  @assigns %{
    id: "notification_period",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Notification Period"
    },
    alert_data: %{
      alert_timing: :"one-time",
      active_period_start: ~N[2024-04-30 15:54:00Z]
    },
    current_time: ~U[2024-04-30 15:54:00Z],
    edited: false,
    form_type: :creating
  }

  describe "component" do
    test "renders" do
      assert render_component(NotificationPeriod, @assigns) =~ ~s(id="notification_period_form")
    end

    test "'when alert is closed' hidden unless pick option selected" do
      {:ok, view, _html} =
        live_isolated_component(
          NotificationPeriod,
          @assigns
        )

      view
      |> element("form")
      |> render_change(%{
        "notification_period" => %{
          "notification_specifier" => "same_as_effect_period"
        }
      })

      refute view
             |> render() =~
               ~s(id="closed-placeholder" value="When alert is closed" placeholder="When alert is closed" disabled="disabled")

      view
      |> element("form")
      |> render_change(%{
        "notification_period" => %{
          "notification_specifier" => "now"
        }
      })

      refute view
             |> render() =~
               ~s(id="closed-placeholder" value="When alert is closed" placeholder="When alert is closed" disabled="disabled")
    end

    test "works if editing" do
      {:ok, view, _html} =
        live_isolated_component(NotificationPeriod, @assigns)

      live_assign(view, %{
        form_type: :editing,
        alert_data: %{
          notification_period_start: ~N[2024-04-30 11:54:00],
          notification_specifier: "custom"
        }
      })

      assert view
             |> render() =~ "custom"
    end

    test "displays error if start invalid" do
      {:ok, view, _html} =
        live_isolated_component(NotificationPeriod, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "notification_period" => %{
          "notification_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "notification_period" => %{
          "notification_period_start" => "a"
        }
      })

      assert render(view) =~ ~s(Enter a valid date and time)
    end

    test "scheduled start time must be after current time" do
      {:ok, view, _html} =
        live_isolated_component(NotificationPeriod, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "notification_period" => %{
          "notification_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "notification_period" => %{
          "notification_period_start" => "2024-04-29T10:54:00"
        }
      })

      assert render(view) =~ ~s(Notifications can’t be set in the past)
    end

    test "scheduled start time must be before active period start" do
      new_alert_data = %{
        alert_timing: :"one-time",
        active_period_start_specifier: :custom,
        active_period_start: ~N[2024-05-01 10:54:00Z]
      }

      {:ok, view, _html} =
        live_isolated_component(NotificationPeriod, %{@assigns | alert_data: new_alert_data})

      view
      |> element("form")
      |> render_change(%{
        "notification_period" => %{
          "notification_specifier" => "start_of_service",
          "notification_period_start_date" => "2024-05-02"
        }
      })

      assert render(view) =~ ~s(Notification period must start on or before 05/01/2024, 10:54 AM)
    end

    test "notification period start is current time by default" do
      with_mock(AlertsUIWeb.FormComponents.Helpers.DateTimeHelpers,
        current_time: fn -> ~N[2024-04-30 15:54:00Z] end
      ) do
        {:ok, _view, _html} =
          live_isolated_component(NotificationPeriod, @assigns)

        assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                        {:section_completed,
                         %NotificationPeriod{
                           notification_period_start: ~N[2024-04-30 15:54:00]
                         }}}
      end
    end

    test "it sends section_completed if no error in changeset" do
      {:ok, view, _html} =
        live_isolated_component(NotificationPeriod, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "notification_period" => %{
          "notification_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "notification_period" => %{
          "notification_period_start" => "2024-04-30T15:53:00"
        }
      })

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:section_completed,
                       %NotificationPeriod{
                         notification_period_start: ~N[2024-04-30 15:54:00]
                       }}}
    end
  end
end
