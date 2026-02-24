defmodule AlertsUIWeb.FormComponents.AlertDetailsTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.FormComponents.AlertDetails
  alias AlertsUIWeb.FormComponents.Helpers.DateTimeFormatters
  alias AlertsUIWeb.Step
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
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
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: nil,
    departure_time:
      DateTime.utc_now() |> DateTime.shift_zone!("America/New_York") |> DateTime.add(1, :day)
  }

  @schedule_2 %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
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

  @assigns %{
    id: "details",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    route_type: 4,
    effect_name: "Delay",
    combination: :RDT,
    alert_data: %{},
    selected_facility: nil,
    selected_schedules: [],
    selected_routes: [],
    selected_stops: []
  }

  describe "component" do
    test "renders" do
      assert render_component(AlertDetails, @assigns) =~ ~s(id="details_form")
    end

    test "gets causes correctly" do
      {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

      assert view
             |> render() =~ ~s(fog)
    end

    test "capitalizes Amtrak in causes" do
      {:ok, view, _html} = live_isolated_component(AlertDetails, %{@assigns | route_type: 2})

      view
      |> element("form")
      |> render_change(%{
        "alert_details" => %{
          "cause_detail" => "AMTRAK_TRAIN_TRAFFIC"
        }
      })

      refute view
             |> render() =~ ~s(amtrak)

      assert view
             |> render() =~ ~s(Amtrak)
    end

    test "capitalizes Coast Guard in causes" do
      {:ok, view, _html} = live_isolated_component(AlertDetails, %{@assigns | route_type: 4})

      view
      |> element("form")
      |> render_change(%{
        "alert_details" => %{
          "cause_detail" => "COAST_GUARD_RESTRICTION"
        }
      })

      refute view
             |> render() =~ ~s(coast guard)

      assert view
             |> render() =~ ~s(Coast Guard)
    end
  end

  describe "severity" do
    test "gets default severity correctly" do
      {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

      assert view
             |> render() =~ ~s(about 10 minutes)
    end

    test "allows severity to be set by user" do
      {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "alert_details" => %{
          "severity" => 7
        }
      })

      assert view
             |> render() =~ ~s(about 30 minutes)
    end
  end

  describe "cause detail" do
    test "gets default cause detail correctly" do
      assigns = Map.merge(@assigns, %{route_type: 1, effect_name: "Single Tracking"})
      {:ok, view, _html} = live_isolated_component(AlertDetails, assigns)

      assert view
             |> render() =~ ~s(single tracking)
    end

    test "allows severity to be set by user" do
      {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "alert_details" => %{
          "cause_detail" => "FOG"
        }
      })

      assert view
             |> render() =~ ~s(fog)
    end
  end

  describe "image url" do
    test "only shows preview if image has been entered" do
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
        {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

        refute view
               |> element("div#image-preview-div")
               |> render() =~ ~s(div id=\"image-information\")

        view
        |> element("form")
        |> render_change(%{
          "alert_details" => %{
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

    test "shows error if url has invalid scheme" do
      {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "alert_details" => %{
          "image_url" => "httpa://cdn.mbta.com/image.jpg"
        }
      })

      assert view
             |> render() =~ ~s(Enter a valid image URL)
    end

    test "shows error if image is not from our CDN" do
      {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

      view
      |> element("form")
      |> render_change(%{
        "alert_details" => %{
          "image_url" => "https://example.com/image.jpg"
        }
      })

      assert view
             |> render() =~ ~s(Enter a valid image URL)
    end

    test "shows error if image has wrong content type" do
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
        {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

        view
        |> element("form")
        |> render_change(%{
          "alert_details" => %{
            "image_url" => "https://cdn.mbta.com/image.pdf"
          }
        })

        assert view
               |> render() =~ ~s(Enter a valid image URL)
      end
    end

    test "shows error if image has no size" do
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
        {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

        view
        |> element("form")
        |> render_change(%{
          "alert_details" => %{
            "image_url" => "https://cdn.mbta.com/image.jpg"
          }
        })

        assert view
               |> render() =~ ~s(Enter a valid image URL)
      end
    end
  end

  describe "end-to-end auto text" do
    @tag :logged_in_user
    test "duration works correctly in case where time is start-to-end in future the same day", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/alerts/new")

      get_to_submission_page(view, "Ferry", "Dock closure")

      render(view)

      # Mock timerange selections
      view
      |> element("#time_range_form")
      |> render_change(%{
        "time_range" => %{
          "active_period_start_specifier" => "start_of_service",
          "active_period_end_specifier" => "end_of_service"
        }
      })

      view
      |> element("#time_range_form")
      |> render_change(%{
        "time_range" => %{
          "active_period_start_date" => @tomorrows_date |> Date.to_iso8601(),
          "active_period_end_date" => @tomorrows_date |> Date.to_iso8601()
        }
      })

      assert view
             |> element("#alert_details_header_text")
             |> render() =~
               "on #{Calendar.strftime(@tomorrows_date, "%a, %b %-d")}</textarea>"
    end

    @tag :logged_in_user
    test "duration works correctly in case where time is start-to-end in future on different days",
         %{
           conn: conn
         } do
      {:ok, view, _html} = live(conn, "/alerts/new")

      get_to_submission_page(view, "Ferry", "Dock closure")

      render(view)

      # Mock timerange selections
      view
      |> element("#time_range_form")
      |> render_change(%{
        "time_range" => %{
          "active_period_start_specifier" => "start_of_service",
          "active_period_end_specifier" => "end_of_service"
        }
      })

      view
      |> element("#time_range_form")
      |> render_change(%{
        "time_range" => %{
          "active_period_start_date" => @tomorrows_date |> Date.to_iso8601(),
          "active_period_end_date" => Date.add(@tomorrows_date, 1) |> Date.to_iso8601()
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
             |> element("#alert_details_header_text")
             |> render() =~ expected_string
    end

    @tag :logged_in_user
    test "header does not update automatically if sync button is off", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [@route] end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Commuter Rail", "Suspension")

        render_async(view)

        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{header_sync_toggle: false, header_text: "my custom text"}
        })

        view
        |> element("#service_form")
        |> render_change(%{
          "affected_service" => %{"route_ids" => ["CR-Worcester"]}
        })

        refute view
               |> element("#alert_details_header_text")
               |> render() =~
                 "Framingham/Worcester Line"

        assert view
               |> element("#alert_details_header_text")
               |> render() =~
                 ">my custom text</textarea>"

        refute view
               |> element("#alert_details_header_text")
               |> render() =~
                 "Framingham/Worcester Line"
      end
    end

    @tag :logged_in_user
    test "header updates if sync buttons is turned off and back on", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [@route] end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Commuter Rail", "Suspension")

        render_async(view)

        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{header_sync_toggle: false, header_text: "my custom text"}
        })

        view
        |> element("#service_form")
        |> render_change(%{
          "affected_service" => %{"route_ids" => ["CR-Worcester"]}
        })

        assert view
               |> element("#alert_details_header_text")
               |> render() =~
                 ">my custom text</textarea>"

        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{header_sync_toggle: true}
        })

        refute view
               |> element("#alert_details_header_text")
               |> render() =~
                 ">my custom text</textarea>"

        assert view
               |> element("#alert_details_header_text")
               |> render() =~
                 "Framingham/Worcester Line"
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
           by_route: fn _, _ -> [@stop, @stop_2, @stop_3] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Ferry", "Dock closure")

        render_async(view)

        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{description_sync_toggle: false, description_text: "my custom text"}
        })

        view
        |> element("#service_form")
        |> render_change(%{
          stop_route_affected_service: %{
            stop_ids: [@stop.id, @stop_2.id, @stop_3.id]
          }
        })

        refute view
               |> element("#alert_details_description_text")
               |> render() =~
                 "Closed docks:\nCourthouse\nMassachusetts Avenue\nSouth Station"

        assert view
               |> element("#alert_details_description_text")
               |> render() =~
                 ">my custom text</textarea>"
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
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop, @stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Commuter Rail", "Delay")

        render_async(view)

        view
        |> element("#service_form")
        |> render_change(%{
          "affected_service" => %{"route_ids" => ["CR-Worcester"], "direction" => "0"}
        })

        assert view
               |> element("#alert_details_description_text")
               |> render() =~
                 "Affected direction: westbound"

        view
        |> element("#service_form")
        |> render_change(%{
          "affected_service" => %{"direction" => "1"}
        })

        assert view
               |> element("#alert_details_description_text")
               |> render() =~
                 "Affected direction: eastbound"

        # Mock affected service selections
        view
        |> element("#service_form")
        |> render_change(%{
          "affected_service" => %{
            "modal_date" => nil,
            "direction" => "0"
          }
        })

        view
        |> with_target("#service_view")
        |> render_hook(:accepted_dates_modal, %{})

        view
        |> element("#service_form")
        |> render_change(%{
          "affected_service" => %{
            "trip_ids" => [@schedule.trip.id],
            "stop_names_and_ids" => ["#{@stop.name}|#{@stop.id}"]
          }
        })

        # Mock alert details selections
        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{cause_detail: "ICE_IN_HARBOR", severity: 4}
        })

        assert view
               |> element("#alert_details_header_text")
               |> render() =~
                 "Framingham/Worcester Line Train 595 (#{DateTimeFormatters.friendly_time(@schedule.departure_time)} from South Station) is operating about 15 minutes behind schedule at South Station due to ice in harbor."

        assert view
               |> element("#alert_details_description_text")
               |> render() =~
                 "Affected stations:\nSouth Station"
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
           by_route: fn _, _ -> [@stop, @stop_2, @stop_3] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Ferry", "Dock closure")

        render_async(view)

        # Mock affected service selections
        view
        |> element("#service_form")
        |> render_change(%{
          stop_route_affected_service: %{
            route_ids: [@route.id],
            stop_ids: [@stop.id, @stop_2.id, @stop_3.id]
          }
        })

        # Mock timerange selections
        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_start_specifier" => "custom",
            "active_period_end_specifier" => "custom"
          }
        })

        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_start" => NaiveDateTime.to_iso8601(@start_time),
            "active_period_end" => NaiveDateTime.to_iso8601(@end_time)
          }
        })

        # Mock alert details selections
        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{cause_detail: "ICE_IN_HARBOR"}
        })

        assert view
               |> element("#alert_details_header_text")
               |> render() =~
                 "3 stops closed from #{Calendar.strftime(@start_time, "%a, %b %-d at %-I:%M %p")} to #{Calendar.strftime(@end_time, "%a, %b %-d at %-I:%M %p")} due to ice in harbor"

        assert view
               |> element("#alert_details_description_text")
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

        get_to_submission_page(view, "Facility", "Elevator closure")

        render_async(view)

        # Mock affected service selections
        view
        |> element("#service_form")
        |> render_change(%{
          access_affected_service: %{facility_id: @facility.id}
        })

        # Mock timerange selections
        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_start_specifier" => "custom",
            "active_period_end_specifier" => "custom"
          }
        })

        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_start" => NaiveDateTime.to_iso8601(@start_time),
            "active_period_end" => NaiveDateTime.to_iso8601(@end_time)
          }
        })

        # Mock alert details selections
        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{cause_detail: "ICE_IN_HARBOR"}
        })

        assert view
               |> element("#alert_details_header_text")
               |> render() =~
                 "Alewife Escalator 349 (Platform to Russell Field) unavailable from #{Calendar.strftime(@start_time, "%a, %b %-d at %-I:%M %p")} to #{Calendar.strftime(@end_time, "%a, %b %-d at %-I:%M %p")} due to ice in harbor"

        assert view
               |> element("#alert_details_description_text")
               |> render() =~ ~s(the elevator broke i&amp;#39;m sorry)
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

      get_to_submission_page(view, "Systemwide", "Summary")

      render_async(view)

      # Mock affected service selections
      view
      |> element("#systemwide-affected-service-form")
      |> render_change(%{
        systemwide_affected_service: %{service_types: [1, 4]}
      })

      # Mock timerange selections
      view
      |> element("#time_range_form")
      |> render_change(%{
        "time_range" => %{
          "active_period_start_specifier" => "custom",
          "active_period_end_specifier" => "custom"
        }
      })

      view
      |> element("#time_range_form")
      |> render_change(%{
        "time_range" => %{
          "active_period_start" => NaiveDateTime.to_iso8601(@start_time),
          "active_period_end" => NaiveDateTime.to_iso8601(@end_time)
        }
      })

      # Mock alert details selections
      view
      |> element("#details_form")
      |> render_change(%{
        alert_details: %{cause_detail: "ICE_IN_HARBOR"}
      })

      assert view
             |> element("#alert_details_header_text")
             |> render() =~
               "Subway and Ferry notice from #{Calendar.strftime(@start_time, "%a, %b %-d at %-I:%M %p")} to #{Calendar.strftime(@end_time, "%a, %b %-d at %-I:%M %p")} due to ice in harbor"

      assert view
             |> element("#alert_details_description_text")
             |> render() =~ ~s(></textarea>)
    end
  end
end
