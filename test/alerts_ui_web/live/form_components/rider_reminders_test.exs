defmodule AlertsUIWeb.FormComponents.RiderRemindersTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest
  alias AlertsUIWeb.FormComponents.RiderReminders
  alias AlertsUIWeb.Step

  @assigns %{
    id: "time_range",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Rider Reminders"
    },
    alert_data: %{},
    form_type: :creating,
    edited: false
  }

  describe "component" do
    test "renders" do
      assert render_component(RiderReminders, @assigns) =~ ~s(id="rider_reminder_form")
    end
  end

  test "reminder picker appears when Add Reminder is pressed" do
    {:ok, view, _html} =
      live_isolated_component(
        RiderReminders,
        @assigns
      )

    refute view
           |> render() =~ ~s(id="reminder-time-component-0")

    view
    |> element("form")
    |> render_change(%{
      "rider_reminders" => %{"reminder_sort" => ["new"]}
    })

    assert view
           |> render() =~ ~s(id="reminder-time-component-0")
  end

  test "reminder picker disappears when X is pressed" do
    {:ok, view, _html} =
      live_isolated_component(
        RiderReminders,
        @assigns
      )

    view
    |> element("form")
    |> render_change(%{
      "rider_reminders" => %{"reminder_sort" => ["new"]}
    })

    assert view
           |> render() =~ ~s(id="reminder-time-component-0")

    view
    |> element("form")
    |> render_change(%{
      "rider_reminders" => %{"reminder_drop" => ["0"]}
    })

    refute view
           |> render() =~ ~s(id="reminder-time-component-0")
  end

  test "doesn't error if time entered is within notification period" do
    {:ok, view, _html} =
      live_isolated_component(
        RiderReminders,
        @assigns
        |> Map.put(:alert_data, %{
          active_period_start: ~N[2024-09-26 04:00:00],
          notification_start: ~N[2024-09-26 02:00:00]
        })
      )

    view
    |> element("form")
    |> render_change(%{
      "rider_reminders" => %{"reminder_sort" => ["new"]}
    })

    view
    |> element("form")
    |> render_change(%{
      "rider_reminders" => %{
        "reminder_sort" => ["0"],
        "reminder_times" => %{
          "0" => %{
            "_persistent_id" => "0",
            "max_time" => "2024-09-27T03:00:00",
            "min_time" => "2024-09-26 02:00:00",
            "reminder_time" => "2024-09-26 03:00:00",
            "reminder_time_specifier" => "custom"
          }
        }
      }
    })

    refute render(view) =~ ~s(Reminder time must be after notification period starts)
  end

  test "shows error if time entered is before effect start" do
    {:ok, view, _html} =
      live_isolated_component(
        RiderReminders,
        @assigns |> Map.put(:alert_data, %{active_period_start: ~N[2024-09-26 04:00:00]})
      )

    view
    |> element("form")
    |> render_change(%{
      "rider_reminders" => %{"reminder_sort" => ["new"]}
    })

    view
    |> element("form")
    |> render_change(%{
      "rider_reminders" => %{
        "reminder_sort" => ["0"],
        "reminder_times" => %{
          "0" => %{
            "_persistent_id" => "0",
            "max_time" => "2024-09-26T04:00:00",
            "min_time" => "2024-09-25T13:04:12",
            "reminder_time" => "2024-09-25T12:12:12",
            "reminder_time_specifier" => "custom"
          }
        }
      }
    })

    assert render(view) =~ ~s(Reminder time must be after notification period starts)
  end

  test "shows error if time entered is before notification period" do
    {:ok, view, _html} =
      live_isolated_component(
        RiderReminders,
        @assigns
        |> Map.put(:alert_data, %{
          active_period_start: ~N[2024-09-26 02:00:00],
          notification_start: ~N[2024-09-26 04:00:00]
        })
      )

    view
    |> element("form")
    |> render_change(%{
      "rider_reminders" => %{"reminder_sort" => ["new"]}
    })

    view
    |> element("form")
    |> render_change(%{
      "rider_reminders" => %{
        "reminder_sort" => ["0"],
        "reminder_times" => %{
          "0" => %{
            "_persistent_id" => "0",
            "max_time" => "2024-09-26T03:00:00",
            "min_time" => "2024-09-25T13:04:12",
            "reminder_time" => "2024-09-25T12:12:12",
            "reminder_time_specifier" => "custom"
          }
        }
      }
    })

    assert render(view) =~ ~s(Reminder time must be after notification period starts)
  end

  test "shows error if time entered is after effect start" do
    {:ok, view, _html} =
      live_isolated_component(
        RiderReminders,
        @assigns
        |> Map.put(:alert_data, %{
          active_period_start: ~N[2024-09-25 13:04:12],
          active_period_end: ~N[2024-09-25 03:00:00]
        })
      )

    view
    |> element("form")
    |> render_change(%{
      "rider_reminders" => %{"reminder_sort" => ["new"]}
    })

    view
    |> element("form")
    |> render_change(%{
      "rider_reminders" => %{
        "reminder_sort" => ["0"],
        "reminder_times" => %{
          "0" => %{
            "_persistent_id" => "0",
            "max_time" => "2024-09-25T03:00:00",
            "min_time" => "2024-09-24T13:04:12",
            "reminder_time" => "2024-09-26T12:12:12",
            "reminder_time_specifier" => "custom"
          }
        }
      }
    })

    rendered_view = render(view)

    assert rendered_view =~ ~s(Reminder time must be before notification period ends)
  end

  test "works if editing" do
    {:ok, view, _html} =
      live_isolated_component(
        RiderReminders,
        @assigns
        |> Map.merge(%{
          form_type: :editing,
          alert_data: %{
            reminder_times: [
              %{id: "1", time: ~N[2024-04-30 11:54:00]},
              %{id: "2", time: ~N[2024-04-30 12:54:00]}
            ],
            active_period_start: ~N[2024-04-30 11:45:00]
          }
        })
      )

    rendered_view = render(view)

    assert rendered_view =~ ~s(value="2024-04-30T11:54")
    assert rendered_view =~ ~s(value="2024-04-30T12:54")
  end
end
