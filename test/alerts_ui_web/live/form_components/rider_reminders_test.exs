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
    editing: false,
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

  test "shows error if time entered is before current time" do
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

    assert render(view) =~ ~s(Reminder can&#39;t be set in the past)
  end

  test "shows error if time entered is aftercurrent time" do
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

    assert rendered_view =~ ~s(Reminder must be before effect end)
  end

  test "works if editing" do
    {:ok, view, _html} =
      live_isolated_component(
        RiderReminders,
        @assigns
        |> Map.merge(%{
          editing: true,
          alert_data: %{reminder_times: [~N[2024-04-30 11:54:00], ~N[2024-04-30 12:54:00]]}
        })
      )

    rendered_view = render(view)

    assert rendered_view =~ ~s(value="2024-04-30T11:54")
    assert rendered_view =~ ~s(value="2024-04-30T12:54")
  end
end
