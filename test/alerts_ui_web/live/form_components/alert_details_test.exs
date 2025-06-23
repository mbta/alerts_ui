defmodule AlertsUIWeb.FormComponents.AlertDetailsTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.FormComponents.AlertDetails
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

  @schedule %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: nil,
    departure_time: DateTime.new!(@todays_date, ~T[16:30:54Z])
  }

  @schedule_2 %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: DateTime.new!(@todays_date, ~T[15:30:54Z]),
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
  end

  describe "image url" do
    test "only shows preview if image has been entered" do
      {:ok, view, _html} = live_isolated_component(AlertDetails, @assigns)

      refute view
             |> element("div#image-preview-div")
             |> render() =~ ~s(div id=\"image-information\")

      view
      |> element("form")
      |> render_change(%{
        "alert_details" => %{
          "image_url" => "https://example.com/image.jpg"
        }
      })

      assert view
             |> element("div#image-preview-div")
             |> render() =~ ~s(div id=\"image-information\")
    end
  end

  describe "end-to-end auto text" do
    @tag :logged_in_user
    test "affected service autotext works", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> [@route] end]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end,
           end_of_rating: fn -> DateTime.utc_now() |> DateTime.to_date() |> Date.add(10) end
         ]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Commuter Rail", "Delay")

        render_async(view)

        view
        |> element("#service_form")
        |> render_change(%{"affected_service" => %{"route_ids" => ["CR-Worcester"]}})

        # Mock affected service selections
        view
        |> element("#service_form")
        |> render_change(%{
          "affected_service" => %{
            "modal_date" => nil
          }
        })

        view
        |> with_target("#service_view")
        |> render_hook(:accepted_dates_modal, %{})

        view
        |> element("#service_form")
        |> render_change(%{
          "affected_service" => %{"trip_ids" => [@schedule.trip.id], "stop_ids" => [@stop.id]}
        })

        # mock timerange selections
        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_end_specifier" => "custom"
          }
        })

        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_end" =>
              @todays_date
              |> Date.add(2)
              |> NaiveDateTime.new!(~T[00:00:00])
              |> NaiveDateTime.to_iso8601()
          }
        })

        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_start_specifier" => "custom"
          }
        })

        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_start" =>
              @todays_date
              |> NaiveDateTime.new!(~T[13:00:00])
              |> NaiveDateTime.to_iso8601()
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
                 "Framingham/Worcester Line train 595 (12:30 PM from South Station) trip is operating about 15 minutes behind schedule from 4:30 PM to 4:30 PM due to ice in harbor"
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
           by_route_type: fn _route_type, _ -> [@stop] end,
           by_route: fn _, _ -> [@stop] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Ferry", "Dock closure")

        render_async(view)

        # Mock affected service selections
        view
        |> element("#service_form")
        |> render_change(%{
          stop_route_affected_service: %{route_ids: [@route.id], stop_ids: [@stop.id]}
        })

        # Mock timerange selections
        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_end_specifier" => "custom"
          }
        })

        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_end" =>
              @todays_date
              |> Date.add(2)
              |> NaiveDateTime.new!(~T[00:00:00])
              |> NaiveDateTime.to_iso8601()
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
                 "South Station closed until #{Calendar.strftime(@todays_date, "%a, %b %_d")} due to ice in harbor"

        assert true
      end
    end

    @tag :logged_in_user
    test "access affected service autotext works", %{
      conn: conn
    } do
      with_mock(FacilitiesRepo, get_by_type: fn _facility_types, _opts -> [@facility] end) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Access", "Elevator closure")

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
            "active_period_end_specifier" => "custom"
          }
        })

        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_end" =>
              @todays_date
              |> Date.add(2)
              |> NaiveDateTime.new!(~T[00:00:00])
              |> NaiveDateTime.to_iso8601()
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
                 "Alewife Escalator 349 (Platform to Russell Field) unavailable until #{Calendar.strftime(@todays_date, "%a, %b %_d")} due to ice in harbor<"

        assert true
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
          "active_period_end_specifier" => "custom"
        }
      })

      view
      |> element("#time_range_form")
      |> render_change(%{
        "time_range" => %{
          "active_period_end" =>
            @todays_date
            |> Date.add(2)
            |> NaiveDateTime.new!(~T[00:00:00])
            |> NaiveDateTime.to_iso8601()
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
               "Subway and Ferry notice until #{Calendar.strftime(@todays_date, "%a, %b %_d")} due to ice in harbor"

      assert true
    end
  end
end
