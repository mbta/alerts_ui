defmodule AlertsUIWeb.FormComponents.StopRouteAffectedServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.FormComponents.StopRouteAffectedService
  alias AlertsUIWeb.Step
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop
  alias Phoenix.LiveView.AsyncResult

  @assigns %{
    id: "affected_service",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    route_type: 1,
    alert_data: %{},
    editing: false,
    effect_name: "Delay"
  }

  @route_one %Route{sort_order: 1, id: "Blue", name: "route_number_1"}
  @route_two %Route{sort_order: 1, id: "Bluer", name: "route_number_2"}
  @routes [@route_one, @route_two]
  @stop %Stop{id: "place-aqucl", name: "Aquarium"}
  @stop_two %Stop{id: "place-pktrm", name: "Park Street"}

  describe "component" do
    test "renders" do
      assert render_component(StopRouteAffectedService, @assigns) =~ ~s(id="service_form")
    end

    test "route options are disabled until a stop is chosen" do
      {:ok, view, _html} =
        live_isolated_component(StopRouteAffectedService, %{
          @assigns
          | alert_data: %{route_type: 1}
        })

      view
      |> live_assign(%{
        available_stops: %AsyncResult{
          ok?: true,
          loading: false,
          failed: false,
          result: [@stop]
        }
      })

      assert view
             |> render() =~ ~s(multiple=\"multiple\" disabled=\"disabled\")

      view
      |> live_assign(%{
        available_stops: %AsyncResult{
          ok?: true,
          loading: false,
          failed: false,
          result: @routes
        }
      })

      view
      |> element("form")
      |> render_change(%{"stop_route_affected_service" => %{"stop_ids" => ["Blue"]}})

      refute view
             |> render() =~ ~s(multiple=\"multiple\" disabled=\"disabled\")

      view
      |> live_assign(%{
        available_routes: %AsyncResult{
          ok?: true,
          loading: false,
          failed: false,
          result: @routes
        }
      })

      assert view
             |> render() =~ ~s(route_number_1)
    end

    test "route options are all selected by default and allows user entry" do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _stop_id -> @routes end, by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route_type: fn _route_type -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            @assigns
          )

        assert view |> render_async() =~ ~s(<option value="place-aqucl">)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["stop_route_affected_service", "stop_ids"],
          "stop_route_affected_service" => %{"stop_ids" => ["place-aqucl"]}
        })

        assert view |> render_async() =~ ~s(<option selected="selected" value="place-aqucl">)
        assert view |> render_async() =~ ~s(<option selected="selected" value="Blue">)
        assert view |> render_async() =~ ~s(<option selected="selected" value="Bluer">)

        view
        |> element("form")
        |> render_change(%{
          "stop_route_affected_service" => %{"route_ids" => ["Bluer"]}
        })

        refute view |> render_async() =~ ~s(<option value="place-aqucl">)
        refute view |> render_async() =~ ~s(<option selected="selected" value="Blue">)
        assert view |> render_async() =~ ~s(<option selected="selected" value="Bluer">)
      end
    end

    # Revisit. Not sure this is testing what is expected
    test "search works" do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _stop_id -> @routes end, by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route_type: fn _route_type -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            @assigns
          )

        assert view |> render_async() =~ ~s(<option value="place-aqucl">)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["stop_route_affected_service", "stop_ids"],
          "stop_route_affected_service" => %{"stop_ids" => ["place-aqucl"]}
        })

        assert view |> element("#stop_route_affected_service_route_ids") |> render_async() =~
                 ~s(<option selected="selected" value="Blue">)

        view
        |> element("form")
        |> render_change(%{
          "stop_route_affected_service" => %{
            "route_ids" => [],
            "stop_search_term" => "x",
            "routes_search_term" => "x"
          }
        })

        # Search doesn't affect the things selected
        assert view |> render_async() =~ ~s(<option selected="selected" value="place-aqucl">)

        refute view |> element("#stop_route_affected_service_route_ids") |> render_async() =~
                 ~s(<option selected="selected" value="Blue">)
      end
    end

    test "modal search works" do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _route_id -> @routes end, by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route_type: fn _route_type -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            @assigns
          )

        assert view
               |> element("select#stop_route_affected_service_modal_route_id")
               |> render_async() =~
                 ~s(<option value="Blue">route_number_1</option>)

        view
        |> element("form")
        |> render_change(%{"stop_route_affected_service" => %{"modal_route_search_term" => "q"}})

        refute view
               |> element("select#stop_route_affected_service_modal_route_id")
               |> render_async() =~
                 ~s(<option value="Blue">route_number_1</option>)
      end
    end

    test "add route filter on stops works" do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _route_id -> @routes end, by_type: fn _types -> @routes end]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type -> [@stop, @stop_two] end,
           by_route: fn
             "Bluer", _ -> [@stop]
             _, _ -> [@stop, @stop_two]
           end
         ]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            @assigns
          )

        # Set baseline unfiltered
        assert view |> render_async() =~ ~s(<option value="place-aqucl">)
        assert view |> render_async() =~ ~s(<option value="place-pktrm">)

        # Add route filter
        view
        |> element("form")
        |> render_change(%{
          "stop_route_affected_service" => %{"modal_route_id" => "Bluer"}
        })

        # Submit filter
        view
        |> with_target("#stop_route_service_view")
        |> render_click(:accepted_routes_modal)

        # Verify filtered and filter text updated
        assert view |> render_async() =~ ~s(<option value="place-aqucl">)
        refute view |> render_async() =~ ~s(<option value="place-pktrm">)
        assert view |> render_async() =~ ~s(Filter: route_number_2)
      end
    end

    test "clear route filter for stops works" do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _route_id -> @routes end, by_type: fn _types -> @routes end]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type -> [@stop, @stop_two] end,
           by_route: fn
             "Bluer", _ -> [@stop]
             _, _ -> [@stop, @stop_two]
           end
         ]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            @assigns
          )

        # Add route filter
        view
        |> element("form")
        |> render_change(%{
          "stop_route_affected_service" => %{"modal_route_id" => "Bluer"}
        })

        # Submit filter
        view
        |> with_target("#stop_route_service_view")
        |> render_click(:accepted_routes_modal)

        # Clear filter
        view
        |> with_target("#stop_route_service_view")
        |> render_click(:clear_filter, %{"filter-id" => "routes-filter-modal"})

        # Verify unfiltered and text changed
        assert view |> render_async() =~ ~s(<option value="place-aqucl">)
        assert view |> render_async() =~ ~s(<option value="place-pktrm">)
        assert view |> render_async() =~ ~s(Filter: All routes)
      end
    end

    test "works correctly if editing" do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _stop_id -> @routes end, by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route_type: fn _route_type -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            @assigns
            |> Map.merge(%{
              editing: true,
              effect_name: "DELAY",
              alert_data: %{
                stop_ids: ["place-aqucl"],
                route_ids: ["Blue"],
                route_type: 1
              }
            })
          )

        assert view |> render_async() =~ ~s(<option selected="selected" value="place-aqucl">)
        assert view |> render_async() =~ ~s(<option selected="selected" value="Blue">)
      end
    end

    test "it sends section_completed if no error in changeset" do
      {:ok, view, _html} =
        live_isolated_component(StopRouteAffectedService, %{
          @assigns
          | alert_data: %{route_type: 3}
        })

      view
      |> element("form")
      |> render_change(%{
        "stop_route_affected_service" => %{"stop_ids" => ["1"], "route_ids" => ["1"]}
      })

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:section_completed,
                       %StopRouteAffectedService{
                         stop_ids: ["1"],
                         route_ids: ["1"]
                       }}}
    end
  end

  describe "end-to-end" do
    @tag :logged_in_user
    test "route options are all selected by default and correctly create informed entities", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _stop_id, _ -> @routes end,
           by_type: fn _types -> @routes end,
           get: fn
             "Blue", _ -> @route_one
             "Bluer", _ -> @route_two
           end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type -> [@stop] end,
           by_route: fn _, _ -> [@stop] end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [] end,
           included_stops_by_route_id: fn _route_id, _direction -> [] end
         ]}
      ]) do
        conn = put_resp_cookie(conn, "show_created_alert", "true")

        {:ok, view, _html} = live(conn, "/alerts/new")

        view
        |> element("#route_types_form button", "Bus")
        |> render_click()

        view
        |> element("#route_types_form button", "Multi-route detour")
        |> render_click()

        view
        |> element("#route_types_form")
        |> render_submit()

        render_async(view)

        view
        |> element("#service_form")
        # Don't like having to hardcode this. If there's a better way to mock, that'd be great!
        |> render_change(%{
          _target: ["stop_route_affected_service", "stop_ids"],
          stop_route_affected_service: %{stop_ids: ["place-aqucl"]}
        })

        assert view |> render_async() =~ ~s(<option selected="selected" value="Blue">)
        assert view |> render_async() =~ ~s(<option selected="selected" value="Bluer">)

        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{header_text: "hello"}
        })

        view
        |> element("button#save", "Publish")
        |> render_click()

        assert [%{route_id: "Blue"}, %{route_id: "Bluer"}] =
                 view
                 |> element("#success_view h3")
                 |> render()
                 |> String.replace("<h3 class=\"font-bold mb-2 text-2xl  mr-4\">\n  Alert #", "")
                 |> String.replace(" created successfully\n</h3>", "")
                 |> AlertsUI.Alerts.get_by_alert_id()
                 |> Map.get(:informed_entity)
      end
    end

    @tag :logged_in_user
    test "selecting a subset of the default routes correctly creates informed entities", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _stop_id, _ -> @routes end,
           by_type: fn _types -> @routes end,
           get: fn
             "Blue", _ -> @route_one
             "Bluer", _ -> @route_two
           end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type -> [@stop] end,
           by_route: fn _, _ -> [@stop] end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [] end,
           included_stops_by_route_id: fn _route_id, _direction -> [] end
         ]}
      ]) do
        conn = put_resp_cookie(conn, "show_created_alert", "true")

        {:ok, view, _html} = live(conn, "/alerts/new")

        view
        |> element("#route_types_form button", "Bus")
        |> render_click()

        view
        |> element("#route_types_form button", "Multi-route detour")
        |> render_click()

        view
        |> element("#route_types_form")
        |> render_submit()

        render_async(view)

        view
        |> element("#service_form")
        |> render_change(%{
          _target: ["stop_route_affected_service", "stop_ids"],
          stop_route_affected_service: %{stop_ids: ["place-aqucl"]}
        })

        view
        |> element("#service_form")
        |> render_change(%{
          _target: ["stop_route_affected_service", "route_ids"],
          stop_route_affected_service: %{route_ids: ["Bluer"]}
        })

        assert view |> render_async() =~ ~s(<option value="Blue">)
        assert view |> render_async() =~ ~s(<option selected="selected" value="Bluer">)

        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{header_text: "hello"}
        })

        view
        |> element("button#save", "Publish")
        |> render_click()

        assert [%{route_id: "Bluer"}] =
                 view
                 |> element("#success_view h3")
                 |> render()
                 |> String.replace("<h3 class=\"font-bold mb-2 text-2xl  mr-4\">\n  Alert #", "")
                 |> String.replace(" created successfully\n</h3>", "")
                 |> AlertsUI.Alerts.get_by_alert_id()
                 |> Map.get(:informed_entity)
      end
    end

    @tag :logged_in_user
    test "publishing a bus multi-route detour AFTER selecting and deselecting will put up a flash error for the missing route",
         %{
           conn: conn
         } do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route_type: fn _route_type -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view
        |> element("#route_types_form button", "Bus")
        |> render_click()

        view
        |> element("#route_types_form button", "Multi-route detour")
        |> render_click()

        view
        |> element("#route_types_form")
        |> render_submit()

        view
        |> element("#service_form")
        |> render_change(%{
          affected_service: %{
            stop_ids: [],
            route_ids: []
          }
        })

        view
        |> element("button#save", "Publish")
        |> render_click()

        # Inline
        assert has_element?(view, "p.text-text-error", "Select stop(s)")
        assert has_element?(view, "p.text-text-error", "Select route(s)")

        # Flash
        flash_text =
          view
          |> element("#error-flash")
          |> render()

        assert flash_text =~ "Select stop(s)" && flash_text =~ "Select route(s)"
      end
    end
  end
end
