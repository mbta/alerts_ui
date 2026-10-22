defmodule AlertsUIWeb.CreateAlertLive.Slices.TimeRangeSliceTest do
  @moduledoc false
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  import Phoenix.LiveViewTest
  import Test.Support.Helpers
  import Mock

  alias AlertsUI.Alerts
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.CreateAlertLive.AlertData
  alias AlertsUIWeb.CreateAlertLive.Slice
  alias AlertsUIWeb.CreateAlertLive.Slices.AffectedServiceSlice
  alias AlertsUIWeb.CreateAlertLive.Slices.TimeRangeSlice
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop
  alias Phoenix.LiveView.AsyncResult

  defp create_test_alert(alert_id, opts) do
    ap =
      build(
        :active_period,
        Keyword.get(opts, :active_period_attrs, %{start: ~U[2024-05-10 14:30:54Z]})
      )

    params =
      build(:alert_map, %{
        alert_id: alert_id,
        active_period: [Map.from_struct(ap)],
        active_period_start: ap.start,
        active_period_end: opts[:active_period_attrs][:end],
        duration_certainty: Keyword.get(opts, :duration_certainty, :UNKNOWN),
        effect_detail: Keyword.get(opts, :effect_detail, "DELAY"),
        original_route_selections: Keyword.get(opts, :original_route_selections, nil)
      })

    {:ok, _} = Alerts.create_or_update_alert(params, build(:user))
  end

  # Fixtures for trip selection unit tests
  @future_departure ~U[2040-01-01 10:00:00Z]
  @future_arrival ~U[2040-01-01 13:00:00Z]
  @past_departure ~U[2024-01-01 10:00:00Z]
  @past_arrival ~U[2024-01-01 13:00:00Z]

  @stop_sstat %Stop{id: "place-sstat", name: "South Station"}
  @facility %Facility{
    id: "814",
    long_name: "Example Facility",
    stop: @stop_sstat
  }

  @todays_datetime DateTime.now!("America/New_York")
  @todays_date DateTime.to_date(@todays_datetime)

  @detour_bus_route %Route{
    direction_names: %{0 => "Outbound", 1 => "Inbound"},
    sort_order: 1,
    id: "1",
    type: 3,
    name: "1"
  }

  defp trip_changeset(attrs \\ %{}) do
    Ecto.Changeset.cast(%AlertData{}, Map.merge(%{trip_ids: []}, attrs), [:trip_ids])
    |> Ecto.Changeset.change(%{active_period_end_specifier: :custom})
  end

  defp trip_validate_changeset(trip_ids, active_period_start) do
    Ecto.Changeset.cast(
      %AlertData{},
      %{trip_ids: trip_ids, active_period_start: active_period_start, alert_timing: :"one-time"},
      [:trip_ids, :active_period_start, :alert_timing]
    )
  end

  defp socket_with_trip_selections(schedules) do
    %{
      assigns: %{
        current_time: DateTime.to_naive(@todays_datetime),
        selections: %AsyncResult{
          ok?: true,
          result: %AffectedServiceSlice.Selections{available_schedules: schedules}
        },
        skate_detours: %AsyncResult{
          ok?: true,
          result: []
        }
      }
    }
  end

  defp socket_for_transform(schedules, form_type \\ :creating) do
    %{
      assigns: %{
        form_type: form_type,
        current_time: DateTime.to_naive(@todays_datetime),
        selections: %AffectedServiceSlice.Selections{available_schedules: schedules},
        skate_detours: %AsyncResult{
          ok?: true,
          result: []
        }
      }
    }
  end

  defp to_eastern_naive(utc_datetime),
    do: utc_datetime |> DateTime.shift_zone!("America/New_York") |> DateTime.to_naive()

  defp selected_start_specifier(view) do
    view
    |> render()
    |> Floki.parse_document!()
    |> Floki.find(~s(select[name="alert_data[active_period_start_specifier]"] option[selected]))
    |> Floki.attribute("value")
    |> List.first()
  end

  defp selected_end_specifier(view) do
    view
    |> render()
    |> Floki.parse_document!()
    |> Floki.find(~s(select[name="alert_data[active_period_end_specifier]"] option[selected]))
    |> Floki.attribute("value")
    |> List.first()
  end

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")
      assert render(view) =~ ~s(id="time_range_view")
    end

    @tag :logged_in_user
    test "enddate picker hidden unless end_of_service option selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      assert view
             |> render() =~
               ~s(phx-feedback-for="alert_data[active_period_end_date]" class="md:min-w-64 md:max-w-64 hidden")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "end_of_service"
        }
      })

      refute view
             |> render() =~
               ~s(phx-feedback-for="alert_data[active_period_end_date]" class="md:min-w-64 md:max-w-64 hidden")
    end

    @tag :logged_in_user
    test "switching between start specifiers retains old date", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => ~N[2025-03-28 03:00:00]
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "start_of_service"
        }
      })

      assert render(view) =~ ~s(value="2025-03-28")
    end

    @tag :logged_in_user
    test "switching from end of custom to end-of-service retains old service date", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "custom",
          "active_period_end_date" => ~D[2025-03-27]
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "end_of_service"
        }
      })

      assert view |> element("#alert_data_active_period_end_date") |> render =~
               ~s(value="2025-03-27")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end" => NaiveDateTime.new!(Date.add(@todays_date, 2), ~T[03:00:00]),
          "active_period_end_date" => Date.add(@todays_date, 1)
        }
      })

      assert render(view) =~ ~s(value="#{Date.add(@todays_date, 1) |> Date.to_iso8601()}")
    end

    @tag :logged_in_user
    test "switching from end of end-of-service to custom has default of 11:59", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "end_of_service"
        }
      })

      expected_value = @todays_date |> Date.to_iso8601()

      assert view |> element("#alert_data_active_period_end_date") |> render =~
               ~s(value="#{expected_value}")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "custom"
        }
      })

      expected_value =
        @todays_date
        |> DateTime.new!(~T[23:59:59])
        |> DateTime.to_iso8601()
        |> String.slice(0, 16)

      assert view |> element("#alert_data_active_period_end") |> render =~
               ~s(value="#{expected_value}")
    end

    @tag :logged_in_user
    test "switching from end of 'later today' to custom has default of 11:59", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      assert view |> element("#time_range_view") |> render =~ "Later today"

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "custom"
        }
      })

      expected_value =
        @todays_date
        |> NaiveDateTime.new!(~T[23:59:59])
        |> NaiveDateTime.to_iso8601()
        |> String.slice(0, 16)

      assert view |> element("#alert_data_active_period_end") |> render =~
               ~s(value="#{expected_value}")

      # test that we can change the datetime and it works
      new_expected_datetime = NaiveDateTime.new!(Date.add(@todays_date, 3), ~T[13:00:00])

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end" => new_expected_datetime
        }
      })

      expected_value =
        new_expected_datetime
        |> NaiveDateTime.to_iso8601()
        |> String.slice(0, 16)

      assert view |> element("#alert_data_active_period_end") |> render =~
               ~s(value="#{expected_value}")
    end

    @tag :logged_in_user
    test "switching from end of 'further notice' to custom has default of current datetime", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "until_further_notice"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "custom"
        }
      })

      render_async(view, 1000)

      expected_value =
        @todays_datetime
        |> NaiveDateTime.to_iso8601()
        |> String.slice(0, 14)

      assert view |> element("#alert_data_active_period_end") |> render =~
               ~s(value="#{expected_value})
    end

    @tag :logged_in_user
    test "switching from end of 'custom' to end-of-service has default of current date", %{
      conn: conn
    } do
      start_time = NaiveDateTime.new!(Date.add(@todays_date, 1), ~T[12:00:00])
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => start_time,
          "active_period_end" => NaiveDateTime.new!(Date.add(@todays_date, 2), ~T[14:00:00])
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "end_of_service"
        }
      })

      expected_date_value =
        Date.add(@todays_date, 2)
        |> Date.to_iso8601()

      expected_start_text = start_time |> Calendar.strftime("%a %b %-d, %Y @ %-I:%M %p")

      expected_end_text =
        Date.add(@todays_date, 3)
        |> NaiveDateTime.new!(~T[03:00:00])
        |> Calendar.strftime("%a %b %-d, %Y @ %-I:%M %p")

      assert view |> element("#alert_data_active_period_end_date") |> render =~
               ~s(value="#{expected_date_value})

      assert view |> element("#duration-text") |> render =~
               ~s(Effect duration: #{expected_start_text} until #{expected_end_text} \(1 day, 15 hours\))
    end

    @tag :logged_in_user
    test "auto-selects 'when work order is closed' for an elevator closure alert", %{conn: conn} do
      with_mock(FacilitiesRepo,
        get_by_type: fn _types, _opts -> [@facility] end,
        get: fn _id -> @facility end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Facility", "Elevator closure")

        assert selected_end_specifier(view) == "when_work_order_is_closed"
      end
    end

    @tag :logged_in_user
    test "auto-selects 'when work order is closed' for an escalator closure alert", %{conn: conn} do
      with_mock(FacilitiesRepo,
        get_by_type: fn _types, _opts -> [@facility] end,
        get: fn _id -> @facility end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Facility", "Escalator closure")

        assert selected_end_specifier(view) == "when_work_order_is_closed"
      end
    end

    @tag :logged_in_user
    test "keeps the user's end specifier after auto-selecting for an elevator closure", %{
      conn: conn
    } do
      with_mock(FacilitiesRepo,
        get_by_type: fn _types, _opts -> [@facility] end,
        get: fn _id -> @facility end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Facility", "Elevator closure")
        assert selected_end_specifier(view) == "when_work_order_is_closed"

        view
        |> element("form")
        |> render_change(%{"alert_data" => %{"active_period_end_specifier" => "end_of_service"}})

        assert selected_end_specifier(view) == "end_of_service"
      end
    end

    @tag :logged_in_user
    test "autoselects start time of 'now' and end time of 'later_today' when skate detour with no end selected",
         %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@detour_bus_route] end,
           get: fn _, _ -> @detour_bus_route end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [] end]}
      ]) do
        conn = put_resp_cookie(conn, "show_new_bus_detours", "true")
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Detour")

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "route_ids" => ["1"],
            "single_route_id" => "1",
            "active_period_start_specifier" => "custom",
            "active_period_end_specifier" => "custom"
          }
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "skate_detour_id"],
          "alert_data" => %{"skate_detour_id" => 9}
        })

        assert selected_start_specifier(view) == "now"
        assert selected_end_specifier(view) == "later_today"
      end
    end

    @tag :logged_in_user
    test "autoselects custom end time when skate detour has autoclose_on field", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@detour_bus_route] end,
           get: fn _, _ -> @detour_bus_route end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [] end]}
      ]) do
        conn = put_resp_cookie(conn, "show_new_bus_detours", "true")
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Detour")

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "route_ids" => ["1"],
            "single_route_id" => "1"
          }
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "skate_detour_id"],
          "alert_data" => %{"skate_detour_id" => 10}
        })

        assert selected_start_specifier(view) == "now"
        assert selected_end_specifier(view) == "custom"

        assert view |> element("#alert_data_active_period_end") |> render =~
                 ~s(value="2026-04-10T03:00")
      end
    end

    @tag :logged_in_user
    test "switching from one-time to recurring has correct defaults", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "alert_timing" => "recurring"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_date" => Date.add(@todays_date, 1),
          "recurrence_days" => [
            :sunday,
            :monday,
            :tuesday,
            :wednesday,
            :thursday,
            :friday,
            :saturday,
            :sunday
          ]
        }
      })

      assert view |> element("#duration-text-recurring") |> render =~
               ~s(Effect duration: 3:00 AM – 3:00 AM<sup>+1</sup> \(1 day\) )

      assert view |> element("#duration-text-recurring") |> render =~
               ~s(until alert is manually closed)
    end

    @tag :logged_in_user
    test "Correctly displays warning border on active period start if trip arrival time is before start",
         %{conn: conn} do
      route = %Route{
        direction_names: %{0 => "Westbound", 1 => "Eastbound"},
        sort_order: 3,
        id: "CR-Worcester",
        type: 2,
        name: "Framingham/Worcester Line"
      }

      schedule = %EnhancedSchedule{
        route_id: "CR-Worcester",
        trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: Date.utc_today() |> DateTime.new!(~T[22:00:00], "America/New_York")
      }

      schedule_2 = %EnhancedSchedule{
        route_id: "CR-Worcester",
        trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: Date.utc_today() |> DateTime.new!(~T[22:00:00], "America/New_York"),
        departure_time: nil
      }

      with_mocks([
        {SchedulesRepo, [], by_route_ids: fn _route_ids, _opts -> [schedule, schedule_2] end},
        {StopsRepo, [], by_route: fn _, _, _opts -> [] end, by_trip: fn _trip_id -> [] end},
        {RoutesRepo, [], [by_type: fn _type -> [route] end, get: fn _id, _opts -> route end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "route_ids" => [route.id],
            "trip_ids" => ["CR-683322-595"],
            "active_period_start_specifier" => :custom
          }
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_start" => Date.utc_today() |> NaiveDateTime.new!(~T[23:00:00])
          }
        })

        assert view |> element("#alert_data_active_period_start") |> render() =~
                 "border-warning"
      end
    end

    @tag :logged_in_user
    test "displays error if end before start", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end" => "2024-05-01T09:54:00",
          "active_period_start" => "2024-05-01T10:54:00"
        }
      })

      assert render(view) =~ ~s(Effect must end after 05/01/2024, 10:54 AM)
    end

    @tag :logged_in_user
    test "displays error if one-time start occurs during DST gap", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => "2025-03-09T02:30:00"
        }
      })

      assert render(view) =~
               ~s(Effect periods cannot start or end during a skipped daylight savings time hour)
    end

    @tag :logged_in_user
    test "displays error if one-time end occurs during DST gap", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end" => "2025-03-09T02:30:00"
        }
      })

      assert render(view) =~
               ~s(Effect periods cannot start or end during a skipped daylight savings time hour)
    end

    @tag :logged_in_user
    test "recurring section is hidden unless recurring is selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      refute view |> render() =~ ~s(Sunday)

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "alert_timing" => "recurring",
          "active_period_start_time_specifier" => "custom",
          "active_period_end_time_specifier" => "custom"
        }
      })

      assert view |> render() =~ ~s(Sunday)
    end

    @tag :logged_in_user
    test "if recurring, start date must match weekday selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "alert_timing" => "recurring"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_time_specifier" => "custom",
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_time" => "10:00:00",
          "active_period_start_date" => "2024-12-03",
          "recurrence_days" => ["monday"]
        }
      })

      assert view |> element("#alert_data_active_period_start_date-root-element") |> render() =~
               ~s(Alert start day must match a selected day of the week.)

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "recurrence_days" => ["tuesday"]
        }
      })

      refute view |> element("#alert_data_active_period_start_date-root-element") |> render() =~
               ~s(Alert start day must match a selected day of the week.)
    end

    @tag :logged_in_user
    test "if recurring, renders error when recurrence day is not selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "alert_timing" => "recurring"
        }
      })

      assert view |> element("#time_range_view") |> render() =~
               ~s(Select one or more days for alert to recur),
             "Error should render if recurrence day is not selected"
    end

    @tag :logged_in_user
    test "does not show recurrence error if no weekdays selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "alert_timing" => "recurring",
          "active_period_start_specifier" => "custom",
          "active_period_start" => "2024-12-04T10:00:00",
          "recurrence_days" => []
        }
      })

      refute view |> render() =~ ~s(Alert start day must match a selected day of the week.)
    end

    @tag :logged_in_user
    test "setting effect to end of service outputs an expected duration text", %{conn: conn} do
      # Use a fixed far-future start time so the start is not "in the past"
      # and the end_of_service end (3:00 AM next day) is guaranteed after it.
      start_dt = ~N[2040-12-16 03:00:00]
      end_date = ~D[2040-12-17]
      # end_of_service sets active_period_end to end_date @ 3:00 AM
      end_dt = NaiveDateTime.new!(Date.add(end_date, 1), ~T[03:00:00])

      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom",
          "active_period_end_specifier" => "end_of_service"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => NaiveDateTime.to_iso8601(start_dt),
          "active_period_end_date" => Date.to_iso8601(end_date)
        }
      })

      start_text = Calendar.strftime(start_dt, "%a %b %-d, %Y @ %-I:%M %p")
      end_text = Calendar.strftime(end_dt, "%a %b %-d, %Y @ %-I:%M %p")

      assert view |> element("#duration-text") |> render =~
               "Effect duration: #{start_text} until #{end_text} (2 days)"
    end

    @tag :logged_in_user
    test "displays error if start invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"active_period_start_specifier" => "custom"}})

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"active_period_start" => "a"}})

      assert render(view) =~ "Enter a valid datetime"
    end

    @tag :logged_in_user
    test "displays error if end invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_end_specifier" => "custom",
          "active_period_start_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"active_period_end" => "s"}})

      assert render(view) =~ "Enter a valid datetime"
    end

    @tag :logged_in_user
    test "allows a 'when work order is closed' value for Elevator alerts", %{conn: conn} do
      with_mock(FacilitiesRepo,
        get_by_type: fn _types, _opts -> [@facility] end,
        get: fn _id -> @facility end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Facility", "Elevator closure")
        render_async(view)

        # option is present in the dropdown for Elevator alerts
        assert render(view) =~ "When work order is closed"

        # selecting it doesn't cause an error
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "single_facility_id" => "Facility-3",
            "active_period_end_specifier" => "when_work_order_is_closed"
          }
        })

        refute render(view) =~ "Enter a valid time range end"
      end
    end

    @tag :logged_in_user
    test "valid creating form with future custom times shows no errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom",
          "active_period_end_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start" => "2040-05-01T08:00:00",
          "active_period_end" => "2040-05-01T10:00:00"
        }
      })

      refute view |> render() =~ "text-text-error"
    end
  end

  describe "editing" do
    @tag :logged_in_user
    test "keeps correct end time specifier when there is no end time", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           get_parent: fn _stop_id -> nil end
         ]}
      ]) do
        create_test_alert("tr-edit-1", duration_certainty: :UNKNOWN)

        {:ok, view, _html} = live(conn, "/alerts/edit/tr-edit-1")

        assert view |> render() =~ "alert is manually closed"
        refute view |> render() =~ "until later today"
      end
    end

    @tag :logged_in_user
    test "does not secretly change end specifier of elevator alerts", %{conn: conn} do
      params =
        build(:alert_map, %{
          alert_id: "123",
          active_period: [%{start: ~U[2024-05-10 15:30:54Z]}],
          active_period_start: ~U[2024-05-10 15:30:54Z],
          active_period_end: nil,
          duration_certainty: :UNKNOWN,
          effect: :ACCESSIBILITY_ISSUE,
          effect_detail: "ELEVATOR_CLOSURE",
          informed_entity: [%{facility_id: @facility.id}],
          original_facility_selections: ["#{@facility.long_name}|#{@facility.id}"],
          primary_service_type: "access"
        })

      {:ok, _} = Alerts.create_or_update_alert(params, build(:user))

      with_mock(FacilitiesRepo,
        get_by_type: fn _types, _opts -> [@facility] end,
        get: fn _id -> @facility end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/edit/123")

        assert view |> element("#duration-text") |> render() =~ "alert is manually closed"

        refute view |> element("#duration-text") |> render() =~
                 "until a work order with this facility ID is closed"
      end
    end

    @tag :logged_in_user
    test "custom fields to start/end of service correctly validates", %{conn: conn} do
      create_test_alert("tr-edit-2",
        duration_certainty: :KNOWN,
        active_period_attrs: %{start: ~U[2040-04-29 10:54:00Z], end: ~U[2040-04-30 15:59:00Z]}
      )

      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           get_parent: fn _stop_id -> nil end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/tr-edit-2")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_end_specifier" => "end_of_service"
          }
        })

        refute view |> element("#time_range_view") |> render() =~ "Effect must end after"
      end
    end

    @tag :logged_in_user
    test "saves updated end time to database", %{conn: conn} do
      bus_route = %Route{id: "22", type: 3, name: "Route 22"}

      create_test_alert("tr-edit-db-1",
        duration_certainty: :UNKNOWN,
        active_period_attrs: %{start: ~U[2024-05-10 14:30:54Z]},
        original_route_selections: ["Route 22|22"]
      )

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> [bus_route] end,
           get: fn _id, _opts -> bus_route end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           get_parent: fn _stop_id -> nil end,
           all: fn _filters, _opts -> [] end
         ]},
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _route_ids, _opts -> [] end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/tr-edit-db-1")
        render_async(view, 3000)

        future_end =
          NaiveDateTime.utc_now()
          |> NaiveDateTime.add(2, :day)
          |> NaiveDateTime.truncate(:second)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_end_specifier" => "custom",
            "active_period_end" => NaiveDateTime.to_iso8601(future_end)
          }
        })

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        :timer.sleep(50)
        updated = Alerts.get_by_alert_id("tr-edit-db-1")
        assert updated.duration_certainty == :KNOWN
      end
    end

    @tag :logged_in_user
    test "does not check start time", %{conn: conn} do
      create_test_alert("tr-edit-3", duration_certainty: :UNKNOWN)

      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           get_parent: fn _stop_id -> nil end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/tr-edit-3")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_end_specifier" => "later_today"
          }
        })

        refute view |> render() =~ "Effect can't start in the past"
      end
    end

    @tag :logged_in_user
    test "editing with end before start shows inline error", %{conn: conn} do
      create_test_alert("tr-edit-err-1",
        duration_certainty: :KNOWN,
        active_period_attrs: %{start: ~U[2024-05-10 14:30:54Z], end: ~U[2024-05-11 14:00:00Z]}
      )

      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           get_parent: fn _stop_id -> nil end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/tr-edit-err-1")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_end_specifier" => "custom",
            "active_period_end" => "2024-05-10T08:00:00"
          }
        })

        assert view |> render() =~ "Effect must end after"
      end
    end

    @tag :logged_in_user
    test "editing with valid change shows no errors", %{conn: conn} do
      create_test_alert("tr-edit-ok-1", duration_certainty: :UNKNOWN)

      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           get_parent: fn _stop_id -> nil end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/tr-edit-ok-1")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_end_specifier" => "until_further_notice"
          }
        })

        refute view |> render() =~ "text-text-error"
        assert view |> render() =~ "alert is manually closed"
      end
    end

    @tag :logged_in_user
    test "custom start and end loads date picker", %{conn: conn} do
      create_test_alert("tr-edit-4",
        duration_certainty: :KNOWN,
        active_period_attrs: %{start: ~U[2040-04-29 10:54:00Z], end: ~U[2040-04-30 15:59:00Z]}
      )

      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           get_parent: fn _stop_id -> nil end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/tr-edit-4")
        html = render(view)

        # specifier for start and end should be 'Custom'
        {:ok, document} = Floki.parse_document(html)

        selected_start =
          Floki.find(document, "select#alert_data_active_period_start_specifier option[selected]")
          |> Floki.attribute("value")

        assert selected_start === ["custom"]

        selected_end =
          Floki.find(document, "select#alert_data_active_period_end_specifier option[selected]")
          |> Floki.attribute("value")

        assert selected_end === ["custom"]

        # the effect start and end should not be hidden
        assert has_element?(view, "#alert_data_active_period_start-root-element")
        refute has_element?(view, "#alert_data_active_period_start-root-element.hidden")
        assert has_element?(view, "#alert_data_active_period_end-root-element")
        refute has_element?(view, "#alert_data_active_period_end-root-element.hidden")

        # and they should have the right values
        start_date =
          Floki.find(document, "input#alert_data_active_period_start")
          |> Floki.attribute("value")

        assert start_date === ["2040-04-29T06:54"]

        end_date =
          Floki.find(document, "input#alert_data_active_period_end")
          |> Floki.attribute("value")

        assert end_date === ["2040-04-30T11:59"]
      end
    end

    @tag :logged_in_user
    test "correctly shows recurrence days for recurring alert", %{conn: conn} do
      params =
        build(:alert_map, %{
          alert_id: "tr-edit-5",
          active_period: [
            %{start: ~U[2026-06-24 14:30:54Z], end: ~U[2026-06-24 16:30:54Z]},
            %{start: ~U[2026-06-25 14:30:54Z], end: ~U[2026-06-25 16:30:54Z]}
          ],
          active_period_start: ~U[2026-06-24 14:30:54Z],
          active_period_end: ~U[2026-06-25 16:30:54Z],
          recurrence_days: [:tuesday, :wednesday],
          recurring: true,
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY"
        })

      {:ok, _} = Alerts.create_or_update_alert(params, build(:user))

      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           get_parent: fn _stop_id -> nil end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/tr-edit-5")

        refute view |> element("#time_range_view") |> render() =~
                 "Alert start day must match a selected day of the week."

        assert view |> render() =~ ~s(value="tuesday" checked="")
        assert view |> render() =~ ~s(value="wednesday" checked="")
      end
    end
  end

  describe "duplicating" do
    @tag :logged_in_user
    test "keeps correct end time specifier when there is no end time", %{conn: conn} do
      create_test_alert("tr-dup-2", duration_certainty: :UNKNOWN)

      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           get_parent: fn _stop_id -> nil end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/duplicate/tr-dup-2")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_end_specifier" => "later_today"
          }
        })

        refute view |> render() =~ "Effect can&#39;t start in the past"
      end
    end

    # is this actually the desired behavior? it looks like this currently
    # wipes APE on duplicate
    @tag :logged_in_user
    @tag :skip
    test "with end before start shows end and start-in-past errors", %{conn: conn} do
      create_test_alert("tr-dup-err-1", duration_certainty: :UNKNOWN)

      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           get_parent: fn _stop_id -> nil end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/duplicate/tr-dup-err-1")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_end_specifier" => "custom"
          }
        })

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_end" => "2024-05-10T08:00:00"
          }
        })

        assert view |> element("#time_range_view") |> render() =~ "Effect must end after"

        assert view |> element("#time_range_view") |> render() =~
                 "Effect can&#39;t start in the past"
      end
    end

    @tag :logged_in_user
    test "with valid change shows no errors", %{conn: conn} do
      create_test_alert("tr-dup-ok-1", duration_certainty: :UNKNOWN)

      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           get_parent: fn _stop_id -> nil end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/duplicate/tr-dup-ok-1")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_start_specifier" => "now",
            "active_period_end_specifier" => "until_further_notice"
          }
        })

        refute view |> render() =~ "text-text-error"
        assert view |> render() =~ "alert is manually closed"
      end
    end

    @tag :logged_in_user
    test "1-time with end in past has correct defaults", %{conn: conn} do
      params =
        build(:alert_map, %{
          alert_id: "123",
          active_period: [
            %{start: ~U[2026-06-24 14:30:54Z], end: ~U[2026-06-24 16:30:54Z]}
          ],
          active_period_start: ~U[2026-06-24 14:30:54Z],
          active_period_end: ~U[2026-06-25 16:30:54Z],
          duration_certainty: :KNOWN,
          recurring: false,
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY"
        })

      {:ok, _} = Alerts.create_or_update_alert(params, build(:user))

      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           get_parent: fn _stop_id -> nil end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/duplicate/123")

        assert view |> element("#alert_data_active_period_start_specifier") |> render() =~ "Now"

        assert view |> element("#alert_data_active_period_end_specifier") |> render() =~
                 "Later today"

        # test that we don't now crash when we go from 1-time to recurring
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "alert_timing" => "recurring"
          }
        })

        assert view |> element("#alert_data_active_period_start_time_specifier") |> render() =~
                 "Start of service"

        assert view |> element("#alert_data_active_period_end_time_specifier") |> render() =~
                 "End of service"
      end
    end

    @tag :logged_in_user
    test "recurring with end in past has correct defaults", %{conn: conn} do
      params =
        build(:alert_map, %{
          alert_id: "123",
          active_period: [
            %{start: ~U[2026-06-24 14:30:54Z], end: ~U[2026-06-24 16:30:54Z]},
            %{start: ~U[2026-06-25 14:30:54Z], end: ~U[2026-06-25 16:30:54Z]}
          ],
          active_period_start: ~U[2026-06-24 14:30:54Z],
          active_period_end: ~U[2026-06-25 16:30:54Z],
          recurrence_days: [:tuesday, :wednesday],
          recurring: true,
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY"
        })

      {:ok, _} = Alerts.create_or_update_alert(params, build(:user))

      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [] end,
           get_parent: fn _stop_id -> nil end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/duplicate/123")

        assert view |> element("#alert_data_active_period_start_specifier") |> render() =~ "Now"

        assert view |> element("#alert_data_active_period_end_specifier") |> render() =~
                 "When alert is closed"
      end
    end
  end

  describe "trip selection" do
    test "populates start and end from trip when departure is in the future" do
      schedule = %EnhancedSchedule{
        route_id: "CR-Worcester",
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @future_departure,
        time_of_last_trip_arrival: @future_arrival
      }

      changeset = trip_changeset(%{trip_ids: ["trip-595"]})

      socket = socket_for_transform([schedule])

      result =
        Slice.transform(
          %TimeRangeSlice{},
          changeset,
          %{"_target" => ["alert_data", "trip_ids"], "alert_data" => %{}},
          socket
        )

      assert Ecto.Changeset.get_field(result, :active_period_start_specifier) == :custom

      assert Ecto.Changeset.get_field(result, :active_period_start) ==
               to_eastern_naive(@future_departure)

      assert Ecto.Changeset.get_field(result, :active_period_end_specifier) == :custom

      expected_end = to_eastern_naive(@future_arrival) |> NaiveDateTime.add(1, :hour)
      assert Ecto.Changeset.get_field(result, :active_period_end) == expected_end
    end

    test "sets start specifier to now when trip departure has already passed" do
      schedule = %EnhancedSchedule{
        route_id: "CR-Worcester",
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @past_departure,
        time_of_last_trip_arrival: @past_arrival
      }

      changeset = trip_changeset(%{trip_ids: ["trip-595"]})
      socket = socket_for_transform([schedule])

      result =
        Slice.transform(
          %TimeRangeSlice{},
          changeset,
          %{"_target" => ["alert_data", "trip_ids"], "alert_data" => %{}},
          socket
        )

      assert Ecto.Changeset.get_field(result, :active_period_start_specifier) == :now
      assert Ecto.Changeset.get_field(result, :active_period_end_specifier) == :custom

      expected_end = to_eastern_naive(@past_arrival) |> NaiveDateTime.add(1, :hour)
      assert Ecto.Changeset.get_field(result, :active_period_end) == expected_end
    end

    test "displays error if start after trip end when start changes" do
      schedule = %EnhancedSchedule{
        route_id: "CR-Worcester",
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @future_departure,
        time_of_last_trip_arrival: @future_arrival
      }

      late_start = to_eastern_naive(@future_arrival) |> NaiveDateTime.add(61, :minute)
      changeset = trip_validate_changeset(["trip-595"], late_start)
      socket = socket_with_trip_selections([schedule])

      result = Slice.validate(%TimeRangeSlice{}, changeset, %{}, socket)

      deadline = to_eastern_naive(@future_arrival) |> NaiveDateTime.add(1, :hour)

      expected_msg =
        "Effect must start before #{Calendar.strftime(deadline, "%m/%d/%Y, %I:%M %p")}"

      assert {^expected_msg, []} = result.errors[:active_period_start]
    end

    test "no error if start after trip end when start changes on recurring alert" do
      schedule = %EnhancedSchedule{
        route_id: "CR-Worcester",
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @future_departure,
        time_of_last_trip_arrival: @future_arrival
      }

      late_start = to_eastern_naive(@future_arrival) |> NaiveDateTime.add(61, :minute)

      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{trip_ids: ["trip-595"], active_period_start: late_start, alert_timing: :recurring},
          [:trip_ids, :active_period_start, :alert_timing]
        )

      socket = socket_with_trip_selections([schedule])

      result = Slice.validate(%TimeRangeSlice{}, changeset, %{}, socket)

      refute Keyword.has_key?(result.errors, :active_period_start)
    end

    test "displays error if start after trip end when 'start of service' is selected" do
      schedule = %EnhancedSchedule{
        route_id: "CR-Worcester",
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @future_departure,
        time_of_last_trip_arrival: @future_arrival
      }

      late_start = to_eastern_naive(@future_arrival) |> NaiveDateTime.add(61, :minute)

      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{
            trip_ids: ["trip-595"],
            active_period_start: late_start,
            active_period_start_specifier: :start_of_service,
            alert_timing: :"one-time"
          },
          [:trip_ids, :active_period_start, :active_period_start_specifier, :alert_timing]
        )

      socket = socket_with_trip_selections([schedule])

      result = Slice.validate(%TimeRangeSlice{}, changeset, %{}, socket)

      deadline = to_eastern_naive(@future_arrival) |> NaiveDateTime.add(1, :hour)

      expected_msg =
        "Effect must start before #{Calendar.strftime(deadline, "%m/%d/%Y, %I:%M %p")}"

      assert {^expected_msg, []} = result.errors[:active_period_start]
    end

    test "doesn't display error if start within 1 hour of trip end" do
      schedule = %EnhancedSchedule{
        route_id: "CR-Worcester",
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @future_departure,
        time_of_last_trip_arrival: @future_arrival
      }

      # exactly 60 minutes after arrival — the diff is NOT > 60, so no error
      on_time_start = to_eastern_naive(@future_arrival) |> NaiveDateTime.add(60, :minute)
      changeset = trip_validate_changeset(["trip-595"], on_time_start)
      socket = socket_with_trip_selections([schedule])

      result = Slice.validate(%TimeRangeSlice{}, changeset, %{}, socket)

      refute Keyword.has_key?(result.errors, :active_period_start)
    end

    test "if recurring, active_period_end should be the last active period end" do
      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{
            alert_timing: "recurring",
            active_period_end_specifier: :custom,
            active_period_end_date: ~D[2024-12-17],
            active_period_end: ~N[2024-12-17 10:00:00],
            recurrence_days: [:tuesday]
          },
          [
            :alert_timing,
            :active_period_end_specifier,
            :active_period_end_date,
            :active_period_end,
            :recurrence_days
          ]
        )

      socket = socket_with_trip_selections([])

      result =
        Slice.transform(
          %TimeRangeSlice{},
          changeset,
          %{"_target" => ["alert_data", "active_period_end_date"], "alert_data" => %{}},
          socket
        )

      assert Ecto.Changeset.get_field(result, :active_period_end_date) == ~D[2024-12-17]
      assert Ecto.Changeset.get_field(result, :active_period_end_specifier) == :custom
    end

    test "if recurring and no end time, active_period_end should reflect that" do
      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{
            alert_timing: "recurring",
            active_period_end_specifier: :until_further_notice,
            recurrence_days: [:tuesday]
          },
          [:alert_timing, :active_period_end_specifier, :recurrence_days]
        )

      socket = socket_with_trip_selections([])

      result =
        Slice.transform(
          %TimeRangeSlice{},
          changeset,
          %{"_target" => ["alert_data", "active_period_end_specifier"], "alert_data" => %{}},
          socket
        )

      assert Ecto.Changeset.get_field(result, :active_period_end_specifier) ==
               :until_further_notice

      # until_further_notice sets active_period_end to nil
      assert is_nil(Ecto.Changeset.get_field(result, :active_period_end))
    end

    test "resets start and end to defaults when all trips are deselected" do
      schedule = %EnhancedSchedule{
        route_id: "CR-Worcester",
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @future_departure,
        time_of_last_trip_arrival: @future_arrival
      }

      # Simulate the state after a trip was selected: custom specifiers are set
      changeset =
        trip_changeset()
        |> Ecto.Changeset.put_change(:active_period_start_specifier, :custom)
        |> Ecto.Changeset.put_change(:active_period_end_specifier, :custom)

      socket = socket_with_trip_selections([schedule])

      result =
        Slice.transform(
          %TimeRangeSlice{},
          changeset,
          %{"_target" => ["alert_data", "trip_ids"], "alert_data" => %{}},
          socket
        )

      assert Ecto.Changeset.get_field(result, :active_period_start_specifier) == :now
      assert Ecto.Changeset.get_field(result, :active_period_end_specifier) == :later_today
    end

    test "start and end time updated if 'all trips' selected" do
      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{
            trip_ids: [],
            active_period_start_specifier: :custom,
            active_period_end_specifier: :custom,
            active_period_start: ~N[2040-01-01 10:16:00],
            active_period_end: ~N[2040-01-01 11:54:00]
          },
          [
            :trip_ids,
            :active_period_start_specifier,
            :active_period_end_specifier,
            :active_period_start,
            :active_period_end
          ]
        )

      socket = socket_for_transform([])

      result =
        Slice.transform(
          %TimeRangeSlice{},
          changeset,
          %{"_target" => ["alert_data", "trip_ids"], "alert_data" => %{}},
          socket
        )

      assert Ecto.Changeset.get_field(result, :active_period_start_specifier) == :now
      assert Ecto.Changeset.get_field(result, :active_period_end_specifier) == :later_today
      refute Ecto.Changeset.get_field(result, :active_period_start) == ~N[2040-01-01 10:16:00]
      refute Ecto.Changeset.get_field(result, :active_period_end) == ~N[2040-01-01 11:54:00]
    end

    test "start and end time updated if trip changes and departure before current time" do
      schedule = %EnhancedSchedule{
        route_id: "CR-Worcester",
        trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: @past_departure,
        time_of_last_trip_arrival: @past_arrival
      }

      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{
            trip_ids: ["trip-595"],
            active_period_start_specifier: :custom,
            active_period_end_specifier: :custom,
            active_period_start: ~N[2040-01-01 10:16:00],
            active_period_end: ~N[2040-01-01 11:54:00]
          },
          [
            :trip_ids,
            :active_period_start_specifier,
            :active_period_end_specifier,
            :active_period_start,
            :active_period_end
          ]
        )

      socket = socket_for_transform([schedule])

      result =
        Slice.transform(
          %TimeRangeSlice{},
          changeset,
          %{"_target" => ["alert_data", "trip_ids"], "alert_data" => %{}},
          socket
        )

      assert Ecto.Changeset.get_field(result, :active_period_start_specifier) == :now
      assert Ecto.Changeset.get_field(result, :active_period_end_specifier) == :custom
      expected_end = to_eastern_naive(@past_arrival) |> NaiveDateTime.add(1, :hour)
      assert Ecto.Changeset.get_field(result, :active_period_end) == expected_end
    end

    test "get_trip_arrival_time_for_validate/2 converts UTC to Eastern Standard Time (UTC-5 in January)" do
      # 19:00 UTC → 14:00 EST
      arrival_utc = ~U[2024-01-15 19:00:00Z]

      schedule = %EnhancedSchedule{
        route_id: "CR-Worcester",
        trip: %Trip{id: "trip-tz-1", name: "1", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: arrival_utc,
        time_of_last_trip_arrival: arrival_utc
      }

      result =
        TimeRangeSlice.get_trip_arrival_time_for_validate(
          ["trip-tz-1"],
          %AsyncResult{
            ok?: true,
            result: %AffectedServiceSlice.Selections{available_schedules: [schedule]}
          }
        )

      assert result == ~N[2024-01-15 14:00:00]
    end

    test "get_trip_arrival_time_for_validate/2 converts UTC to Eastern Daylight Time (UTC-4 in July)" do
      # 19:00 UTC → 15:00 EDT
      arrival_utc = ~U[2024-07-15 19:00:00Z]

      schedule = %EnhancedSchedule{
        route_id: "CR-Worcester",
        trip: %Trip{id: "trip-tz-2", name: "2", direction_id: 0},
        stop: %Stop{id: "place-sstat", name: "South Station"},
        arrival_time: nil,
        departure_time: arrival_utc,
        time_of_last_trip_arrival: arrival_utc
      }

      result =
        TimeRangeSlice.get_trip_arrival_time_for_validate(
          ["trip-tz-2"],
          %AsyncResult{
            ok?: true,
            result: %AffectedServiceSlice.Selections{available_schedules: [schedule]}
          }
        )

      assert result == ~N[2024-07-15 15:00:00]
    end

    test "get_trip_arrival_time_for_validate/2 returns nil when no schedules match" do
      result =
        TimeRangeSlice.get_trip_arrival_time_for_validate(
          ["trip-unknown"],
          %AsyncResult{
            ok?: true,
            result: %AffectedServiceSlice.Selections{available_schedules: []}
          }
        )

      assert is_nil(result)
    end
  end

  describe "validate/4 recurring start-in-the-past error placement" do
    @weekday_atoms ~w(monday tuesday wednesday thursday friday saturday sunday)a

    # Recurring, "now" start specifier, with a past start time on the given
    # recurrence days. start_date shares the weekday of the recurrence day so the
    # start-date/weekday check is satisfied and only the "in the past" error fires.
    defp recurring_past_start(recurrence_days, start_date) do
      Ecto.Changeset.cast(
        %AlertData{},
        %{
          alert_timing: :recurring,
          active_period_start_specifier: :now,
          active_period_start_date: start_date,
          active_period_start_time: ~T[09:00:00],
          active_period_end_specifier: :until_further_notice,
          recurrence_days: recurrence_days
        },
        [
          :alert_timing,
          :active_period_start_specifier,
          :active_period_start_date,
          :active_period_start_time,
          :active_period_end_specifier,
          :recurrence_days
        ]
      )
    end

    test "when today is a recurrence day, the time error is on the start time specifier" do
      today = Enum.at(@weekday_atoms, Date.day_of_week(@todays_date) - 1)
      # a week ago: in the past, same weekday as today
      start_date = Date.add(@todays_date, -7)

      result =
        Slice.validate(
          %TimeRangeSlice{form_type: :new},
          recurring_past_start([today], start_date),
          %{},
          socket_with_trip_selections([])
        )

      assert result.errors[:active_period_start_time_specifier] ==
               {"Effect can't start in the past", []}

      refute Keyword.has_key?(result.errors, :active_period_start_specifier)
    end

    test "when today is not a recurrence day, the time error is on the start specifier" do
      # the day after today, which is not today
      other = Enum.at(@weekday_atoms, rem(Date.day_of_week(@todays_date), 7))
      # six days ago: in the past, same weekday as `other`
      start_date = Date.add(@todays_date, -6)

      result =
        Slice.validate(
          %TimeRangeSlice{form_type: :new},
          recurring_past_start([other], start_date),
          %{},
          socket_with_trip_selections([])
        )

      assert result.errors[:active_period_start_specifier] ==
               {"Effect can't start in the past", []}

      refute Keyword.has_key?(result.errors, :active_period_start_time_specifier)
    end
  end

  describe "ensure_start_values/5 with :now specifier" do
    test "does not advance active_period_start when target is unrelated (e.g. header_sync_toggle)" do
      existing_dt = ~N[2024-01-15 10:30:00]

      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{
            active_period_start_specifier: :custom,
            active_period_start: existing_dt,
            active_period_start_date: ~D[2024-01-15]
          },
          [:active_period_start_specifier, :active_period_start, :active_period_start_date]
        )

      result =
        TimeRangeSlice.ensure_start_values(
          changeset,
          :custom,
          nil,
          DateTime.to_naive(@todays_datetime),
          "one-time"
        )

      assert Ecto.Changeset.get_field(result, :active_period_start) == existing_dt
    end

    test "updates active_period_start when target is active_period_start_specifier" do
      existing_dt = ~N[2020-01-01 00:00:00]

      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{
            active_period_start_specifier: :now,
            active_period_start: existing_dt,
            active_period_start_date: ~D[2020-01-01]
          },
          [:active_period_start_specifier, :active_period_start, :active_period_start_date]
        )

      result =
        TimeRangeSlice.ensure_start_values(
          changeset,
          :custom,
          nil,
          DateTime.to_naive(@todays_datetime),
          "one-time"
        )

      refute Ecto.Changeset.get_field(result, :active_period_start) == existing_dt
    end

    test "updates active_period_start when target is nil (initial load)" do
      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{active_period_start_specifier: :now},
          [:active_period_start_specifier]
        )

      result =
        TimeRangeSlice.ensure_start_values(
          changeset,
          nil,
          nil,
          DateTime.to_naive(@todays_datetime),
          "one-time"
        )

      assert %NaiveDateTime{} = Ecto.Changeset.get_field(result, :active_period_start)
    end
  end

  describe "ensure_end_values/5 with :later_today specifier" do
    test "does not recompute active_period_end when target is unrelated" do
      existing_end = ~N[2024-06-03 02:30:00]

      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{
            active_period_end_specifier: :custom,
            active_period_end: existing_end,
            active_period_end_date: ~D[2024-06-03]
          },
          [:active_period_end_specifier, :active_period_end, :active_period_end_date]
        )

      result =
        TimeRangeSlice.ensure_end_values(
          changeset,
          :custom,
          :custom,
          DateTime.to_naive(@todays_datetime),
          :"one-time"
        )

      assert Ecto.Changeset.get_field(result, :active_period_end) == existing_end
    end
  end

  describe "extract/3 when duplicating a past alert" do
    defp past_duplicating_slice do
      %TimeRangeSlice{form_type: :duplicating, active_period_end: ~N[2020-01-01 00:00:00]}
    end

    test "defaults the end specifier to when_work_order_is_closed for an elevator closure" do
      alert = %AlertData{effect_name: "elevator_closure"}

      result = Slice.extract(past_duplicating_slice(), alert, %{})

      assert result.active_period_end_specifier == :when_work_order_is_closed
    end

    test "defaults the end specifier to when_work_order_is_closed for an escalator closure" do
      alert = %AlertData{effect_name: "escalator_closure"}

      result = Slice.extract(past_duplicating_slice(), alert, %{})

      assert result.active_period_end_specifier == :when_work_order_is_closed
    end

    test "keeps later_today for a non-elevator/escalator past alert" do
      alert = %AlertData{effect_name: "delay"}

      result = Slice.extract(past_duplicating_slice(), alert, %{})

      assert result.active_period_end_specifier == :later_today
    end
  end

  describe "extract/3 when editing an auto-closable alert" do
    test "derives can_close_automatically true from a when_work_order_is_closed end specifier" do
      slice = %TimeRangeSlice{
        form_type: :editing,
        active_period_end_specifier: :when_work_order_is_closed,
        can_close_automatically: nil
      }

      result = Slice.extract(slice, %AlertData{}, %{})

      assert result.can_close_automatically == true
    end

    test "derives can_close_automatically false from a non-auto-closing end specifier" do
      slice = %TimeRangeSlice{
        form_type: :editing,
        active_period_end_specifier: :until_further_notice,
        can_close_automatically: nil
      }

      result = Slice.extract(slice, %AlertData{}, %{})

      assert result.can_close_automatically == false
    end
  end

  describe "ensure_end_values/5 and can_close_automatically" do
    test "sets can_close_automatically true for :when_work_order_is_closed" do
      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{active_period_end_specifier: :when_work_order_is_closed},
          [:active_period_end_specifier]
        )

      result =
        TimeRangeSlice.ensure_end_values(
          changeset,
          nil,
          nil,
          DateTime.to_naive(@todays_datetime),
          :"one-time"
        )

      assert Ecto.Changeset.get_field(result, :can_close_automatically) == true
    end

    test "sets can_close_automatically false for other end specifiers" do
      changeset =
        Ecto.Changeset.cast(
          %AlertData{},
          %{active_period_end_specifier: :custom, active_period_end: ~N[2099-01-01 00:00:00]},
          [:active_period_end_specifier, :active_period_end]
        )

      result =
        TimeRangeSlice.ensure_end_values(
          changeset,
          :custom,
          :custom,
          DateTime.to_naive(@todays_datetime),
          :"one-time"
        )

      assert Ecto.Changeset.get_field(result, :can_close_automatically) == false
    end
  end

  describe "transform/4 recurrence_days rendering" do
    test "recurrence days don't get unselected on errors due to them being strings" do
      alert_data = %AlertData{alert_timing: :recurring, recurrence_days: [:monday]}
      base_changeset = Ecto.Changeset.change(alert_data)

      cast_changeset =
        Ecto.Changeset.cast(base_changeset, %{"recurrence_days" => ["monday"]}, [:recurrence_days])
        |> Ecto.Changeset.change(%{active_period_end_specifier: :custom})

      refute Map.has_key?(cast_changeset.changes, :recurrence_days),
             "pre-condition: Ecto equal-value optimization must skip recurrence_days from changes"

      socket = socket_for_transform([])
      params = %{"alert_data" => %{"recurrence_days" => ["monday"]}}

      result = Slice.transform(%TimeRangeSlice{}, cast_changeset, params, socket)

      assert Map.has_key?(result.changes, :recurrence_days),
             "transform must force recurrence_days into changes to prevent atom/string mismatch"

      assert result.changes[:recurrence_days] == [:monday],
             "recurrence_days must be atoms in changes so :monday in [:monday] = true in rendering"
    end

    test "restores the last recurrence day when a recurring alert is fully deselected" do
      changeset =
        %AlertData{alert_timing: :recurring, recurrence_days: []}
        |> Ecto.Changeset.change()

      result = TimeRangeSlice.prevent_recurrence_day_deselection(changeset, [:monday])

      assert result.changes[:recurrence_days] == [:monday],
             "must restore the previous recurrence day when the user deselects them all"
    end

    test "does not resurrect recurrence days for a one-time alert" do
      changeset =
        %AlertData{alert_timing: :"one-time", recurrence_days: []}
        |> Ecto.Changeset.change()

      result = TimeRangeSlice.prevent_recurrence_day_deselection(changeset, [:monday])

      assert (result.changes[:recurrence_days] || []) == [],
             "one-time alerts must not have recurrence days restored"
    end

    @tag :logged_in_user
    test "end-to-end: cannot uncheck the last recurrence day", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"alert_timing" => "recurring"}})

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"recurrence_days" => ["wednesday", "friday"]}})

      assert has_element?(view, "input#wednesday[checked]")
      assert has_element?(view, "input#friday[checked]")

      # With two days selected, neither is locked.
      refute has_element?(view, "label[for='wednesday'].pointer-events-none")
      refute has_element?(view, "label[for='friday'].pointer-events-none")

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"recurrence_days" => ["wednesday"]}})

      refute has_element?(view, "input#friday[checked]")

      # The lone remaining day is rendered non-interactive so clicking it can't
      # empty the group (the server-side restore below is the backstop).
      assert has_element?(view, "label[for='wednesday'].pointer-events-none")

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"recurrence_days" => []}})

      assert has_element?(view, "input#wednesday[checked]")
    end
  end

  describe "form survives deleting time value" do
    @tag :logged_in_user
    test "recurring alert, clear custom start time → form must not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      # Navigate to the Alert Details step: Subway / Delay
      view = get_to_submission_page(conn, view, "Subway", "Delay")

      # Switch to recurring timing
      view
      |> element("form")
      |> render_change(%{
        "_target" => ["alert_data", "alert_timing"],
        "alert_data" => %{"alert_timing" => "recurring"}
      })

      # Set start time specifier to custom (reveals the time input)
      view
      |> element("form")
      |> render_change(%{
        "_target" => ["alert_data", "active_period_start_time_specifier"],
        "alert_data" => %{
          "alert_timing" => "recurring",
          "active_period_start_time_specifier" => "custom"
        }
      })

      # Now clear the time value (simulates the user deleting the minutes component).
      # Before the fix, this caused a FunctionClauseError crash in the LiveView.
      html =
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "active_period_start_time"],
          "alert_data" => %{
            "alert_timing" => "recurring",
            "active_period_start_time_specifier" => "custom",
            "active_period_start_time" => ""
          }
        })

      # If render_change raised, the test would already have failed.
      # The form must still contain alert_data fields (not crashed/replaced with an error page).
      # render_change returns the partial form HTML; layout flash elements are not included.
      assert html =~ "alert_data",
             "form should still be rendered after clearing start time; got: #{String.slice(html, 0, 200)}"

      refute html =~ "Internal Server Error",
             "form must not show a server error response after clearing start time"

      # Also verify the time range section is still present (form hasn't collapsed)
      assert html =~ "time_range" or html =~ "active_period",
             "time range section should still be rendered in the form"
    end

    @tag :logged_in_user
    test "one-time alert, clear custom start, switch to recurring → form must not crash",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      view = get_to_submission_page(conn, view, "Subway", "Delay")

      # Set one-time start specifier to custom (reveals the datetime-local input)
      view
      |> element("form")
      |> render_change(%{
        "_target" => ["alert_data", "active_period_start_specifier"],
        "alert_data" => %{
          "alert_timing" => "one-time",
          "active_period_start_specifier" => "custom"
        }
      })

      # Clear the one-time start datetime (simulates deleting the time portion)
      view
      |> element("form")
      |> render_change(%{
        "_target" => ["alert_data", "active_period_start"],
        "alert_data" => %{
          "alert_timing" => "one-time",
          "active_period_start_specifier" => "custom",
          "active_period_start" => ""
        }
      })

      # Switch to recurring — before the fix, this caused the crash
      html =
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "alert_timing"],
          "alert_data" => %{
            "alert_timing" => "recurring",
            "active_period_start_specifier" => "custom",
            "active_period_start" => ""
          }
        })

      assert html =~ "alert_data",
             "form should still be rendered after clearing one-time start then switching to recurring"

      refute html =~ "Internal Server Error",
             "form must not show a server error response after the timing switch"

      assert html =~ "time_range" or html =~ "active_period",
             "time range section should still be rendered in the form"
    end
  end
end
