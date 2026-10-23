defmodule AlertsUIWeb.CreateAlertLive.Slices.AlertDetailsSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  import Phoenix.LiveViewTest
  import Mock
  import Test.Support.Helpers
  alias AlertsUI.Alerts
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.Helpers.DateTimeFormatters
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @todays_date DateTime.utc_now()
               |> DateTime.shift_zone!("America/New_York")
               |> DateTime.to_date()

  @tomorrows_date Date.add(@todays_date, 1)

  @start_time @tomorrows_date
              |> NaiveDateTime.new!(~T[06:00:00])

  @end_time @todays_date
            |> Date.add(2)
            |> NaiveDateTime.new!(~T[00:00:00])

  @schedule %EnhancedSchedule{
    route_id: "CR-Worcester",
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 1},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: nil,
    departure_time:
      DateTime.utc_now() |> DateTime.shift_zone!("America/New_York") |> DateTime.add(1, :day)
  }

  @schedule_2 %EnhancedSchedule{
    route_id: "CR-Worcester",
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 1},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time:
      DateTime.utc_now()
      |> DateTime.shift_zone!("America/New_York")
      |> DateTime.add(1, :day)
      |> DateTime.add(1, :hour),
    departure_time: nil
  }

  @route %Route{
    direction_names: %{0 => "Westbound", 1 => "Eastbound"},
    sort_order: 3,
    id: "CR-Worcester",
    type: 2,
    name: "Framingham/Worcester Line"
  }

  @detour_bus_route %Route{
    direction_names: %{0 => "Outbound", 1 => "Inbound"},
    sort_order: 1,
    id: "1",
    type: 3,
    name: "1"
  }

  @stop %Stop{id: "place-sstat", name: "South Station"}
  @stop_2 %Stop{id: "place-crtst", name: "Courthouse"}
  @stop_3 %Stop{id: "place-masta", name: "Massachusetts Avenue"}

  @facility %Facility{
    id: "349",
    type: "ESCALATOR",
    short_name: "Platform to Russell Field",
    long_name: "Alewife Escalator 349 (Platform to Russell Field)",
    stop: %Stop{
      id: "place-alfcl",
      name: "Aquarium",
      type: "stop"
    },
    properties: [
      %{name: "direction", value: "up"},
      %{name: "alternate-service-text", value: "the elevator broke i'm sorry"},
      %{name: "excludes-stop", value: "door-alfcl-alewife"}
    ]
  }

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Ferry", "Delay")
      assert render(view) =~ ~s(id="details_view")
    end

    @tag :logged_in_user
    test "gets causes correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Ferry", "Delay")
      assert render(view) =~ ~s(fog)
    end

    @tag :logged_in_user
    test "capitalizes Amtrak in causes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "cause_detail" => "AMTRAK_TRAIN_TRAFFIC"
        }
      })

      refute view
             |> render() =~ ~s(amtrak)

      assert view
             |> render() =~ ~s(Amtrak)
    end

    @tag :logged_in_user
    test "capitalizes Coast Guard in causes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Ferry", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "cause_detail" => "COAST_GUARD_RESTRICTION"
        }
      })

      refute view
             |> render() =~ ~s(coast guard)

      assert view
             |> render() =~ ~s(Coast Guard)
    end

    @tag :logged_in_user
    test "cause is automatically selected upon skate detour selection", %{conn: conn} do
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
          "_target" => ["alert_data", "single_route_id"],
          "alert_data" => %{"route_ids" => ["1"], "single_route_id" => "1"}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "skate_detour_id"],
          "alert_data" => %{"skate_detour_id" => 7}
        })

        assert view |> element("#alert_data_cause_detail") |> render_async =~
                 ~s(<option selected="" value="DRAWBRIDGE_BEING_RAISED">drawbridge being raised</option>)
      end
    end
  end

  describe "severity" do
    @tag :logged_in_user
    test "gets default severity correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Ferry", "Delay")

      assert view
             |> render() =~ ~s(about 10 minutes)
    end

    @tag :logged_in_user
    test "allows severity to be set by user", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Ferry", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "severity" => 7
        }
      })

      assert view
             |> render() =~ ~s(about 30 minutes)
    end
  end

  describe "cause detail" do
    @tag :logged_in_user
    test "gets default cause detail correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Subway", "Single tracking")

      assert view
             |> element("#details_view")
             |> render() =~ ~s(single tracking)
    end

    @tag :logged_in_user
    test "allows cause to be set by user", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Ferry", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "cause_detail" => "FOG"
        }
      })

      assert view
             |> element("#details_view")
             |> render() =~ ~s(fog)
    end
  end

  describe "image url" do
    @tag :logged_in_user
    test "only shows preview if image has been entered", %{conn: conn} do
      with_mock(Req,
        head: fn "https://cdn.mbta.com/image.jpg" ->
          {:ok,
           %Req.Response{
             status: 200,
             headers: %{
               "content-length" => ["304839"],
               "content-type" => ["image/png"]
             },
             body: ""
           }}
        end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Ferry", "Delay")

        refute view
               |> element("div#image-preview-div")
               |> render() =~ ~s(div id=\"image-information\")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "image_url" => "https://cdn.mbta.com/image.jpg"
          }
        })

        refute view
               |> render() =~ ~s(Enter a valid image URL)

        assert view
               |> element("div#image-preview-div")
               |> render() =~ ~s(div id=\"image-information\")
      end
    end

    @tag :logged_in_user
    test "shows error if url has invalid scheme", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Ferry", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "image_url" => "httpa://cdn.mbta.com/image.jpg"
        }
      })

      assert view
             |> render() =~ ~s(Enter a valid image URL)

      assert view
             |> render() =~ ~s(Enter alt text)
    end

    @tag :logged_in_user
    test "shows error if image is not from our CDN", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Ferry", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "image_url" => "https://example.com/image.jpg"
        }
      })

      assert view
             |> render() =~ ~s(Enter a valid image URL)
    end

    @tag :logged_in_user
    test "shows error if image has wrong content type", %{conn: conn} do
      with_mock(Req,
        head: fn "https://cdn.mbta.com/image.pdf" ->
          {:ok,
           %Req.Response{
             status: 200,
             headers: %{
               "content-length" => ["304839"],
               "content-type" => ["application/pdf"]
             },
             body: ""
           }}
        end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Ferry", "Delay")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "image_url" => "https://cdn.mbta.com/image.pdf"
          }
        })

        assert view
               |> render() =~ ~s(Enter a valid image URL)
      end
    end

    @tag :logged_in_user
    test "shows error if image has no size", %{conn: conn} do
      with_mock(Req,
        head: fn "https://cdn.mbta.com/image.jpg" ->
          {:ok,
           %Req.Response{
             status: 200,
             headers: %{
               "content-length" => [""],
               "content-type" => ["image/png"]
             },
             body: ""
           }}
        end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Ferry", "Delay")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "image_url" => "https://cdn.mbta.com/image.jpg"
          }
        })

        assert view
               |> render() =~ ~s(Enter a valid image URL)
      end
    end
  end

  describe "auto text" do
    @tag :logged_in_user
    test "shows error on submit if header text is blank", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Ferry", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "header_text" => "",
          "header_sync_toggle" => false
        }
      })

      render_async(view, 1000)
      view |> element("button#review", "Review and submit") |> render_click()

      assert view
             |> render() =~ ~s(Enter message text)
    end

    @tag :logged_in_user
    test "duration works correctly in case where time is start-to-end in future the same day", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [@route] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           by_route_type: fn _route_type, _ -> [@stop, @stop_2, @stop_3] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Ferry", "Dock closure")

        render(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_start_specifier" => "start_of_service",
            "active_period_end_specifier" => "end_of_service",
            "active_period_start_date" => Date.to_iso8601(@tomorrows_date),
            "active_period_end_date" => Date.to_iso8601(@tomorrows_date),
            "active_period_start" =>
              @tomorrows_date |> NaiveDateTime.new!(~T[03:00:00]) |> NaiveDateTime.to_iso8601(),
            "active_period_end" =>
              @tomorrows_date
              |> Date.add(1)
              |> NaiveDateTime.new!(~T[03:00:00])
              |> NaiveDateTime.to_iso8601()
          }
        })

        assert view
               |> element("#details_view")
               |> render() =~
                 "on #{Calendar.strftime(@tomorrows_date, "%a, %b %-d")}.</textarea>"
      end
    end

    @tag :logged_in_user
    test "duration works correctly in case where time is start-to-end in future on different days",
         %{
           conn: conn
         } do
      with_mocks([
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [] end]},
        {RoutesRepo, [], [by_type: fn _types -> [@route] end]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop, @stop_2] end,
           by_route_type: fn _route_type, _ -> [@stop, @stop_2, @stop_3] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Ferry", "Dock closure")

        render(view)

        # Mock timerange selections
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_start_specifier" => "start_of_service",
            "active_period_end_specifier" => "end_of_service",
            "active_period_start_date" => @tomorrows_date |> Date.to_iso8601(),
            "active_period_end_date" => @tomorrows_date |> Date.add(1),
            "active_period_start" =>
              @tomorrows_date |> NaiveDateTime.new!(~T[03:00:00]) |> NaiveDateTime.to_iso8601(),
            "active_period_end" =>
              @tomorrows_date
              |> Date.add(2)
              |> NaiveDateTime.new!(~T[03:00:00])
              |> NaiveDateTime.to_iso8601()
          }
        })

        # expected outcome is different if the dates are weekends
        expected_string =
          if Date.day_of_week(@tomorrows_date) == 6 do
            "closed the weekend of #{Calendar.strftime(@tomorrows_date, "%a, %b %-d")} and #{Calendar.strftime(Date.add(@tomorrows_date, 1), "%a, %b %-d")}"
          else
            "from #{Calendar.strftime(@tomorrows_date, "%a, %b %-d")} through #{Calendar.strftime(Date.add(@tomorrows_date, 1), "%a, %b %-d")}"
          end

        assert view
               |> element("#details_view")
               |> render() =~ expected_string
      end
    end

    @tag :logged_in_user
    test "header does not update automatically if sync button is off", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [@route] end]},
        {StopsRepo, [], [by_route: fn _route, _direction, _opts -> [@stop] end]},
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Commuter Rail", "Suspension")

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{header_sync_toggle: false, header_text: "my custom text"}
        })

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"route_ids" => ["CR-Worcester"]}
        })

        refute view
               |> element("#details_view")
               |> render() =~
                 "Framingham/Worcester Line"

        assert view
               |> element("#details_view")
               |> render() =~
                 ">my custom text</textarea>"

        refute view
               |> element("#details_view")
               |> render() =~
                 "Framingham/Worcester Line"
      end
    end

    @tag :logged_in_user
    test "header updates if sync buttons is turned off and back on", %{
      conn: conn
    } do
      with_mocks([
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [] end]},
        {RoutesRepo, [], [by_type: fn _types -> [@route] end]},
        {StopsRepo, [], [by_route: fn _route, _direction, _opts -> [@stop, @stop_2] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Commuter Rail", "Suspension")

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{
            header_sync_toggle: false,
            header_text: "my custom text",
            route_ids: ["CR-Worcester"]
          }
        })

        assert view
               |> element("#alert_data_header_text")
               |> render_async() =~ "my custom text"

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{header_sync_toggle: true}
        })

        refute view
               |> element("#alert_data_header_text")
               |> render_async() =~
                 "my custom text"

        assert view
               |> element("#alert_data_header_text")
               |> render_async() =~
                 "Framingham/Worcester"
      end
    end

    @tag :logged_in_user
    test "behaves correctly if text is cleared", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [@route] end]},
        {StopsRepo, [], [by_route: fn _route, _direction, _opts -> [@stop] end]},
        {SchedulesRepo, [],
         [
           end_of_rating: fn _ -> Date.utc_today() end,
           by_route_ids: fn _route_ids, _opts -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Commuter Rail", "Suspension")

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{
            route_ids: ["CR-Worcester"]
          }
        })

        assert view
               |> element("#alert_data_header_text")
               |> render() =~
                 "Framingham/Worcester Line"

        assert view
               |> element("#alert_data_header_sync_toggle")
               |> render() =~ ~s(checked=\"\")

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{
            header_sync_toggle: false,
            header_text: ""
          }
        })

        refute view
               |> element("#alert_data_header_sync_toggle")
               |> render_async(1000) =~ ~s(checked=\"\")

        assert view
               |> element("#alert_data_header_text")
               |> render_async(1000) =~ ""

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{
            header_sync_toggle: true
          }
        })

        assert view
               |> element("#alert_data_header_text")
               |> render() =~
                 "Framingham/Worcester Line"

        assert view
               |> element("#alert_data_header_sync_toggle")
               |> render() =~ ~s(checked=\"\")
      end
    end

    @tag :logged_in_user
    test "header updates if sync buttons is turned off and back with error on facility alert", %{
      conn: conn
    } do
      with_mock(
        FacilitiesRepo,
        get_by_type: fn _facility_types, _opts -> [@facility] end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Facility", "Bike issue")

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{facility_ids: ["349"]}
        })

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{view_banner: true}
        })

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{
            header_sync_toggle: false,
            header_text: "my custom text"
          }
        })

        assert view
               |> element("#alert_data_header_text")
               |> render_async() =~ "my custom text"

        assert view
               |> render_async() =~ "Check box to show you understand"

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{header_sync_toggle: true}
        })

        refute view
               |> element("#alert_data_header_text")
               |> render_async() =~
                 "my custom text"

        assert view
               |> element("#alert_data_header_text")
               |> render_async() =~
                 "Alewife Escalator 349"
      end
    end

    @tag :logged_in_user
    test "header value attribute re-syncs to autotext when sync re-enabled with form errors", %{
      conn: conn
    } do
      with_mocks([
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [] end]},
        {RoutesRepo, [], [by_type: fn _types -> [@route] end]},
        {StopsRepo, [], [by_route: fn _route, _direction, _opts -> [@stop, @stop_2] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Suspension")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{
            header_sync_toggle: false,
            header_text: "my custom text",
            route_ids: ["CR-Worcester"]
          }
        })

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{"url" => "not-a-valid-url"}
        })

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{header_sync_toggle: true}
        })

        rendered = view |> element("#alert_data_header_text") |> render_async()

        refute rendered =~ "my custom text"
        assert rendered =~ "Framingham/Worcester"

        refute rendered =~ ~s(value="true")
        assert rendered =~ ~s(value="Framingham/Worcester)
      end
    end

    @tag :logged_in_user
    test "description does not update automatically if sync button is off", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _route_id -> [@route] end, by_type: fn _types -> [@route] end]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type, _ -> [@stop, @stop_2, @stop_3] end,
           by_route: fn _, _, _opts -> [@stop, @stop_2, @stop_3] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Ferry", "Dock closure")

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{description_sync_toggle: false, description_text: "my custom text"}
        })

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{
            stop_ids: [@stop.id, @stop_2.id, @stop_3.id]
          }
        })

        refute view
               |> element("#alert_data_description_text")
               |> render() =~
                 "Closed docks:\nCourthouse\nMassachusetts Avenue\nSouth Station"

        assert view
               |> element("#alert_data_description_text")
               |> render() =~
                 ">my custom text</textarea>"
      end
    end

    @tag :logged_in_user
    test "main message displays red when character limit reached", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _route_id -> [@route] end, by_type: fn _types -> [@route] end]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type, _ -> [@stop, @stop_2, @stop_3] end,
           by_route: fn _, _, _opts -> [@stop, @stop_2, @stop_3] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Ferry", "Dock closure")

        render_async(view)

        almost_too_long_string = String.pad_leading("", 254, "A")

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{header_sync_toggle: false, header_text: almost_too_long_string}
        })

        assert view
               |> element("#alert_data_header_text")
               |> render() =~
                 ~s(border-danger)

        too_long_string = String.pad_leading("", 255, "A")

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{header_sync_toggle: false, header_text: too_long_string}
        })

        assert view
               |> element("#alert_data_header_text")
               |> render() =~ ~s(border-danger)
      end
    end

    @tag :logged_in_user
    test "description displays red when character limit reached", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _route_id -> [@route] end, by_type: fn _types -> [@route] end]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type, _ -> [@stop, @stop_2, @stop_3] end,
           by_route: fn _, _, _opts -> [@stop, @stop_2, @stop_3] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Ferry", "Dock closure")

        render_async(view)

        almost_too_long_string = String.pad_leading("", 2999, "A")

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{
            description_sync_toggle: false,
            description_text: almost_too_long_string
          }
        })

        assert view
               |> element("#alert_data_description_text")
               |> render() =~ ~s(border-danger)

        too_long_string = String.pad_leading("", 3000, "A")

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{description_sync_toggle: false, description_text: too_long_string}
        })

        assert view
               |> element("#alert_data_description_text")
               |> render() =~ ~s(border-danger)
      end
    end

    @tag :logged_in_user
    test "affected service autotext works", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [@route] end]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end,
           end_of_rating: fn ->
             DateTime.utc_now()
             |> DateTime.shift_zone!("America/New_York")
             |> DateTime.to_date()
             |> Date.add(10)
           end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop, @stop_2] end,
           by_trip: fn _trip_id -> [@stop] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"route_ids" => ["CR-Worcester"], "direction" => "0"}
        })

        assert view
               |> element("#alert_data_description_text")
               |> render_async() =~
                 "Affected direction: westbound"

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"route_ids" => ["CR-Worcester"], "direction" => "1"}
        })

        assert view
               |> element("#alert_data_description_text")
               |> render_async() =~
                 "Affected direction: eastbound"

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "severity" => 4,
            "modal_date" => nil,
            "direction" => "default",
            "trip_ids" => [@schedule.trip.id],
            "cause_detail" => "ICE_IN_HARBOR",
            "stop_names_and_ids" => ["South Station|place-sstat", "Courthouse|place-crtst"]
          }
        })

        assert view
               |> element("#alert_data_header_text")
               |> render_async() =~
                 "Framingham/Worcester Line Train 595 (#{DateTimeFormatters.friendly_time(@schedule.departure_time)} from South Station) is operating about 15 minutes behind schedule between Courthouse and South Station due to ice in harbor."

        assert view
               |> element("#alert_data_description_text")
               |> render_async() =~
                 "Affected stations:\nCourthouse\nSouth Station"
      end
    end

    @tag :logged_in_user
    test "stop route affected service autotext works", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _route_id -> [@route] end, by_type: fn _types -> [@route] end]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type, _ -> [@stop, @stop_2, @stop_3] end,
           by_route: fn _, _, _ -> [@stop, @stop_2, @stop_3] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Ferry", "Dock closure")

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "route_ids" => [@route.id],
            "stop_names_and_ids" => [
              "#{@stop.name}|#{@stop.id}",
              "#{@stop_2.name}|#{@stop_2.id}",
              "#{@stop_3.name}|#{@stop_3.id}"
            ],
            "active_period_start_specifier" => "custom",
            "active_period_end_specifier" => "custom"
          }
        })

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "cause_detail" => "ICE_IN_HARBOR",
            "active_period_start" => NaiveDateTime.to_iso8601(@start_time),
            "active_period_end" => NaiveDateTime.to_iso8601(@end_time)
          }
        })

        assert view
               |> element("#alert_data_header_text")
               |> render() =~
                 "3 stops will be closed from #{Calendar.strftime(@start_time, "%a, %b %-d at %-I:%M %p")} to #{Calendar.strftime(@end_time, "%a, %b %-d at %-I:%M %p")} due to ice in harbor"

        assert view
               |> element("#alert_data_description_text")
               |> render() =~
                 "Closed docks:\nCourthouse\nMassachusetts Avenue\nSouth Station"
      end
    end

    @tag :logged_in_user
    test "access affected service autotext works", %{
      conn: conn
    } do
      with_mock(FacilitiesRepo, get_by_type: fn _facility_types, _opts -> [@facility] end) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Facility", "Elevator closure")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "facility_ids" => [@facility.id],
            "active_period_start_specifier" => "custom",
            "active_period_end_specifier" => "custom"
          }
        })

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "cause_detail" => "ICE_IN_HARBOR",
            "active_period_start_date" => Date.to_iso8601(@tomorrows_date),
            "active_period_end_date" => Date.to_iso8601(@tomorrows_date),
            "active_period_start" => NaiveDateTime.to_iso8601(@start_time),
            "active_period_end" => NaiveDateTime.to_iso8601(@end_time)
          }
        })

        assert view
               |> element("#alert_data_header_text")
               |> render_async() =~
                 "Alewife Escalator 349 (Platform to Russell Field) will be unavailable from #{Calendar.strftime(@start_time, "%a, %b %-d at %-I:%M %p")} to #{Calendar.strftime(@end_time, "%a, %b %-d at %-I:%M %p")} due to ice in harbor"

        assert view
               |> element("#alert_data_description_text")
               |> render_async() =~ ~s(the elevator broke i&#39;m sorry)
      end
    end

    @tag :logged_in_user
    test "systemwide autotext works", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/alerts/new")

      @todays_date =
        DateTime.utc_now()
        |> DateTime.shift_zone!("America/New_York")
        |> DateTime.to_date()

      view = get_to_submission_page(conn, view, "Systemwide", "Delay")

      render_async(view)

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "service_types" => ["1", "4"],
          "active_period_start_specifier" => "custom",
          "active_period_end_specifier" => "custom"
        }
      })

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "cause_detail" => "ICE_IN_HARBOR",
          "active_period_start" => NaiveDateTime.to_iso8601(@start_time),
          "active_period_end" => NaiveDateTime.to_iso8601(@end_time)
        }
      })

      assert view
             |> element("#alert_data_header_text")
             |> render() =~
               "Ferry and Subway service may experience delays from #{Calendar.strftime(@start_time, "%a, %b %-d at %-I:%M %p")} to #{Calendar.strftime(@end_time, "%a, %b %-d at %-I:%M %p")} due to ice in harbor"

      assert view
             |> element("#alert_data_description_text")
             |> render() =~ ~s(></textarea>)
    end

    @tag :logged_in_user
    test "stop route affected service autotext works when editing", %{
      conn: conn
    } do
      bus_route = %Route{
        direction_names: %{0 => "Outbound", 1 => "Inbound"},
        sort_order: 3,
        id: "33",
        type: 3,
        name: "33"
      }

      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _route_id -> [bus_route] end,
           by_stop: fn _route_id, _ -> [bus_route] end,
           by_type: fn _types -> [bus_route] end,
           all: fn _ -> [bus_route] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type, _ -> [@stop, @stop_2, @stop_3] end,
           by_route: fn _, _ -> [@stop, @stop_2, @stop_3] end,
           by_route: fn _, _, _ -> [@stop, @stop_2, @stop_3] end,
           get_parent: fn _ -> %{id: @stop.id} end
         ]}
      ]) do
        ie =
          build(:informed_entity, %{
            route_id: bus_route.id,
            route_type: bus_route.type,
            activities: [:BOARD],
            stop_id: @stop.id,
            direction_id: nil,
            trip: nil
          })

        alert_params =
          build(
            :alert_map,
            %{
              alert_id: "123",
              header_text: "example header text",
              informed_entity: [Map.from_struct(ie)],
              effect: :OTHER_EFFECT,
              effect_detail: "STOP_CLOSURE",
              original_route_selections: ["#{bus_route.name}|#{bus_route.id}"],
              original_stop_selections: ["#{@stop.name}|#{@stop.id}"],
              reminder_times: [],
              severity: 7,
              cause_detail: "unknown",
              user: build(:user),
              primary_service_type: "3"
            }
          )

        {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))
        {:ok, view, _html} = live(conn, "/alerts/edit/123")

        render_async(view)

        assert view
               |> element("#details_view")
               |> render_async() =~ "example header text"

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{header_sync_toggle: true}
        })

        assert view
               |> element("#alert_data_header_text")
               |> render_async() =~
                 "South Station is closed beginning Thu, Oct 19 at 8:01 PM."
      end
    end

    @tag :logged_in_user
    test "service effect text is correctly maintained when editing", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _route_id -> [@route] end,
           by_type: fn _types -> [@route] end,
           get: fn _ -> @route end,
           get: fn _, _ -> @route end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type, _ -> [] end,
           by_route: fn _, _, _ -> [] end,
           get_parent: fn _ -> %{} end,
           all: fn _, _ -> [] end
         ]},
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]}
      ]) do
        ie =
          build(:informed_entity, %{
            route_id: @route.id,
            route_type: @route.type,
            activities: [:BOARD],
            direction_id: nil,
            trip: nil
          })

        expected_service_effect_text = "Extra Framingham/Worcester Line service"

        alert_params =
          build(
            :alert_map,
            %{
              alert_id: "123",
              service_effect_text: expected_service_effect_text,
              informed_entity: [Map.from_struct(ie)],
              effect: :OTHER_EFFECT,
              effect_detail: "EXTRA_SERVICE",
              original_route_selections: ["#{@route.name}|#{@route.id}"]
            }
          )

        {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))
        {:ok, view, _html} = live(conn, "/alerts/edit/123")

        render_async(view, 1000)

        open_review_modal(view)

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        created_alert = AlertsUI.Alerts.get_by_alert_id("123")
        assert created_alert.service_effect_text == expected_service_effect_text
      end
    end

    @tag :logged_in_user
    test "obsolete causes are correctly stripped out when editing", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _route_id -> [@route] end,
           by_type: fn _types -> [@route] end,
           get: fn _ -> @route end,
           get: fn _, _ -> @route end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type, _ -> [] end,
           by_route: fn _, _, _ -> [] end,
           get_parent: fn _ -> %{} end,
           all: fn _, _ -> [] end
         ]},
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [] end]}
      ]) do
        ie =
          build(:informed_entity, %{
            route_id: @route.id,
            route_type: @route.type,
            activities: [:BOARD],
            direction_id: nil,
            trip: nil
          })

        alert_params =
          build(
            :alert_map,
            %{
              alert_id: "123",
              cause: :WEATHER,
              cause_detail: "SHARKNADO",
              informed_entity: [Map.from_struct(ie)],
              effect: :OTHER_EFFECT,
              effect_detail: "EXTRA_SERVICE",
              original_route_selections: ["#{@route.name}|#{@route.id}"]
            }
          )

        {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))
        {:ok, view, _html} = live(conn, "/alerts/edit/123")

        render_async(view, 1000)

        open_review_modal(view)

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        created_alert = AlertsUI.Alerts.get_by_alert_id("123")
        assert created_alert.cause == nil
        assert created_alert.cause_detail == nil
      end
    end
  end
end
