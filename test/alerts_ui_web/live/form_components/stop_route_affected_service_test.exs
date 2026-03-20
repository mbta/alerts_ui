defmodule AlertsUIWeb.FormComponents.StopRouteAffectedServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUIWeb.FormComponents.StopRouteAffectedService
  alias AlertsUIWeb.Step
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop
  alias Phoenix.LiveView.AsyncResult

  @assigns %{
    id: "stop_route_affected_service",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    route_type: 1,
    alert_data: %{},
    form_type: :creating,
    effect_name: "Station Closure",
    show_stop_ids: false
  }

  @route_one %Route{sort_order: 1, id: "Blue", name: "route_number_1", type: 3}
  @route_two %Route{sort_order: 2, id: "Bluer", name: "route_number_2", type: 3}
  @shuttle_route %Route{
    sort_order: 3,
    id: "shuttle",
    name: "Shuttle Route",
    description: :rail_replacement_bus,
    type: 3
  }
  @routes [@route_one, @route_two]
  @stop %Stop{id: "place-aqucl", name: "Aquarium"}
  @stop_two %Stop{id: "place-pktrm", name: "Park Street"}
  @stop_two_but_different %Stop{id: "place-pktrm-inbound", name: "Park Street"}

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
             |> render() =~ ~s(id="stop_route_affected_service_route_ids" disabled="disabled")

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
             |> render() =~ ~s(id="stop_route_affected_service_route_ids" disabled="disabled")

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

    test "shuttle routes are filtered out of routes filter list" do
      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _stop_id, ["filter[type]": 3] -> @routes ++ [@shuttle_route] end,
           by_type: fn 3 -> @routes ++ [@shuttle_route] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _routes, _direction, _opts -> [@stop] end
         ]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            %{@assigns | route_type: 3}
          )

        refute view |> render_async() =~ ~s(shuttle)
      end
    end

    test "shuttle routes are filtered when stop selected" do
      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _stop_id, ["filter[type]": 3] -> @routes ++ [@shuttle_route] end,
           by_type: fn 3 -> @routes ++ [@shuttle_route] end
         ]},
        {StopsRepo, [], [by_route: fn _routes, _direction, _opts -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            %{@assigns | route_type: 3}
          )

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["stop_route_affected_service", "stop_ids"],
          "stop_route_affected_service" => %{"stop_ids" => ["place-aqucl"]}
        })

        refute view |> render_async() =~ ~s(shuttle)
      end
    end

    test "route options are all selected by default and allows user entry" do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _stop_id -> @routes end, by_type: fn _types -> @routes end]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type, _ -> [@stop] end,
           by_route: fn _routes, _direction, _opts -> [@stop] end
         ]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            @assigns
          )

        assert view |> render_async() =~ ~s(value="place-aqucl">)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["stop_route_affected_service", "stop_ids"],
          "stop_route_affected_service" => %{"stop_ids" => ["place-aqucl"]}
        })

        assert view |> render_async() =~ ~s(selected="selected" value="place-aqucl">)
        assert view |> render_async() =~ ~s(selected="selected" value="Blue">)
        assert view |> render_async() =~ ~s(selected="selected" value="Bluer">)

        view
        |> element("form")
        |> render_change(%{
          "stop_route_affected_service" => %{"route_ids" => ["Bluer"]}
        })

        {:ok, document} =
          view
          |> render_async()
          |> Floki.parse_document()

        refute document_has_element?(
                 document,
                 "#stop_route_affected_service_route_ids > option[value=\"place-aqucl\"]"
               )

        refute document_has_element?(
                 document,
                 "#stop_route_affected_service_route_ids > option[value=\"Blue\"][selected=\"selected\"]"
               )

        assert document_has_element?(
                 document,
                 "#stop_route_affected_service_route_ids > option[value=\"Bluer\"][selected=\"selected\"]"
               )
      end
    end

    # Revisit. Not sure this is testing what is expected
    test "search works" do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _stop_id -> @routes end, by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route_type: fn _route_type, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            @assigns
          )

        assert view |> render_async() =~ ~s(value="place-aqucl">)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["stop_route_affected_service", "stop_ids"],
          "stop_route_affected_service" => %{"stop_ids" => ["place-aqucl"]}
        })

        {:ok, document} =
          view
          |> render_async()
          |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "#stop_route_affected_service_route_ids > option[value=\"Blue\"][selected=\"selected\"]"
               )

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
        {:ok, document} =
          view
          |> render_async()
          |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "option[value=\"place-aqucl\"][selected=\"selected\"]"
               )

        refute document_has_element?(
                 document,
                 "#stop_route_affected_service_route_ids > option[selected=\"selected\"][value=\"Blue\"]"
               )
      end
    end

    test "stop order is by name when not filtering and by direction when filtering" do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _route_id -> @routes end, by_type: fn _types -> [@route_one] end]},
        {StopsRepo, [],
         [
           by_route: fn
             "Blue", 0, _opts -> [@stop, @stop_two]
             "Blue", 1, _opts -> [@stop, @stop_two_but_different]
           end
         ]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            %{@assigns | route_type: 3}
          )

        assert view
               |> element("select##stop_route_affected_service_stop_ids")
               |> render_async() =~
                 ~r/value="place-aqucl".*value="place-pktrm-inbound".*value="place-pktrm"/

        # Add route filter
        view
        |> element("form")
        |> render_change(%{
          "stop_route_affected_service" => %{"modal_route_id" => "Blue"}
        })

        # Submit filter
        view
        |> with_target("#stop_route_service_view")
        |> render_click(:accepted_routes_modal)

        {:ok, document} =
          view
          |> render_async()
          |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "select#stop_route_affected_service_stop_ids > option[value=\"place-pktrm-inbound\"]"
               )

        assert document_has_element?(
                 document,
                 "select#stop_route_affected_service_stop_ids > option[value=\"place-aqucl\"]"
               )

        assert document_has_element?(
                 document,
                 "select#stop_route_affected_service_stop_ids > option[value=\"place-pktrm\"]"
               )
      end
    end

    test "modal search works" do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _route_id -> @routes end, by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route_type: fn _route_type, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            @assigns
          )

        {:ok, document} =
          view
          |> render_async()
          |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "select#stop_route_affected_service_modal_route_id > option[value=\"Blue\"]"
               )

        view
        |> element("form")
        |> render_change(%{"stop_route_affected_service" => %{"modal_route_search_term" => "q"}})

        {:ok, document} =
          view
          |> render_async()
          |> Floki.parse_document()

        refute document_has_element?(
                 document,
                 "select#stop_route_affected_service_modal_route_id > option[value=\"Blue\"]"
               )
      end
    end

    test "add route filter on stops works" do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _route_id -> @routes end, by_type: fn _types -> @routes end]},
        {StopsRepo, [],
         [
           by_route_type: fn
             _route_type, ["filter[route]": "Blue,Bluer", direction_id: 0] -> [@stop]
             _route_type, ["filter[route]": "Blue,Bluer", direction_id: 1] -> [@stop_two]
           end,
           by_route: fn
             "Bluer", _, _opts -> [@stop]
             _, 0, _opts -> [@stop]
             _, 1, _opts -> [@stop, @stop_two]
           end
         ]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            %{@assigns | route_type: 3}
          )

        # Set baseline unfiltered
        assert view |> render_async() =~ ~s(value="place-aqucl">Aquarium)
        refute view |> render_async() =~ ~s(value="place-aqucl">Aquarium \(outbound\))
        assert view |> render_async() =~ ~s(value="place-pktrm">Park Street \(inbound\))

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
        assert view |> render_async() =~ ~s(value="place-aqucl">Aquarium)
        refute view |> render_async() =~ ~s(value="place-pktrm">)
        assert view |> render_async() =~ ~s(Filter: route_number_2)
      end
    end

    test "selections are preserved after route filter applied" do
      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _route_id -> @routes end,
           by_stop: fn _, _ -> @routes end,
           by_type: fn _types -> @routes end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn
             _route_type, ["filter[route]": "Blue,Bluer", direction_id: 0] -> [@stop]
             _route_type, ["filter[route]": "Blue,Bluer", direction_id: 1] -> [@stop_two]
           end,
           by_route: fn
             "Bluer", _, _opts -> [@stop]
             _, 0, _opts -> [@stop]
             _, 1, _opts -> [@stop, @stop_two]
           end
         ]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            %{@assigns | route_type: 3}
          )

        # Select Park Street
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["stop_route_affected_service", "stop_ids"],
          "stop_route_affected_service" => %{"stop_ids" => ["place-pktrm"]}
        })

        # Add route filter that would ordinarily filter out Park St
        view
        |> element("form")
        |> render_change(%{
          "stop_route_affected_service" => %{"modal_route_id" => "Bluer"}
        })

        # Submit filter
        view
        |> with_target("#stop_route_service_view")
        |> render_click(:accepted_routes_modal)

        # Verify Park St still present, and top of list
        {:ok, document} =
          view
          |> render_async()
          |> Floki.parse_document()

        {_, _, children_nodes} = Floki.get_by_id(document, "stop_route_affected_service_stop_ids")

        assert [
                 {"option",
                  [
                    {"id", "stop-selector-place-pktrm"},
                    {"phx-hook", "Tippy"},
                    {"data-tippy-content", "Stop ID place-pktrm"},
                    {"data-tippy-delay", "[1000, 200]"},
                    {"selected", "selected"},
                    {"value", "place-pktrm"}
                  ], ["Park Street (inbound)"]},
                 {"option",
                  [
                    {"id", "stop-selector-place-aqucl"},
                    {"phx-hook", "Tippy"},
                    {"data-tippy-content", "Stop ID place-aqucl"},
                    {"data-tippy-delay", "[1000, 200]"},
                    {"value", "place-aqucl"}
                  ], ["Aquarium"]}
               ] = children_nodes
      end
    end

    test "clear route filter for stops works" do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _route_id -> @routes end, by_type: fn _types -> @routes end]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type, _ -> [@stop, @stop_two] end,
           by_route: fn
             "Bluer", _, _opts -> [@stop]
             _, _, _opts -> [@stop, @stop_two]
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

        # Verify unfiltered
        assert render(view) =~ ~s(value="place-aqucl">)
        assert render(view) =~ ~s(value="place-pktrm">)
        # Verify text changed
        assert render(view) =~ ~s(Filter: All routes)
        # Verify modal is cleared
        assert view
               |> element("select#stop_route_affected_service_modal_route_id")
               |> render() =~ ~s(<option value="default" selected="selected">)
      end
    end

    test "works correctly if editing" do
      with_mocks([
        {RoutesRepo, [],
         [by_stop: fn _stop_id -> @routes end, by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route_type: fn _route_type, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} =
          live_isolated_component(
            StopRouteAffectedService,
            @assigns
            |> Map.merge(%{
              form_type: :editing,
              effect_name: "DELAY",
              alert_data: %{
                stop_ids: ["place-aqucl"],
                route_ids: ["Blue"],
                route_type: 1
              }
            })
          )

        assert view |> render_async() =~ ~s(selected="selected" value="place-aqucl">)
        assert view |> render_async() =~ ~s(selected="selected" value="Blue">)
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
           end,
           get: fn
             "Blue" -> @route_one
             "Bluer" -> @route_two
           end,
           all: fn _ -> [] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type -> [@stop, @stop_two] end,
           by_route: fn _, _ -> [@stop, @stop_two] end,
           by_route: fn _, _, _opts -> [@stop, @stop_two] end,
           get: fn _id -> @stop end,
           get_parent: fn _id -> nil end
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

        {:ok, document} =
          view
          |> render_async()
          |> Floki.parse_document()

        assert document_has_element?(document, "option[value=\"Blue\"][selected=\"selected\"]")
        assert document_has_element?(document, "option[value=\"Bluer\"][selected=\"selected\"]")

        # Simulate separately selecting a second stop
        view
        |> element("#service_form")
        |> render_change(%{
          _target: ["stop_route_affected_service", "stop_ids"],
          stop_route_affected_service: %{stop_ids: ["place-aqucl", "place-pktrm"]}
        })

        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{header_text: "hello"}
        })

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        assert view |> element("#affected_service_selections") |> render_async() =~
                 ~s(<p>Stops:</p><p>Aquarium, Park Street</p>)

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        # query the db
        flash = assert_redirect(view, "/")

        alert_id =
          flash["info"]
          |> String.replace("New alert #", "")
          |> String.replace(" created", "")

        new_alert = AlertsUI.Alerts.get_by_alert_id(alert_id)

        assert [
                 %{route_id: "Blue", route_type: 3, stop_id: "place-aqucl"},
                 %{route_id: "Bluer", route_type: 3, stop_id: "place-aqucl"},
                 %{route_id: "Blue", route_type: 3, stop_id: "place-pktrm"},
                 %{route_id: "Bluer", route_type: 3, stop_id: "place-pktrm"}
               ] =
                 Map.get(new_alert, :informed_entity)

        {:ok, view, _html} = live(conn, "/alerts/edit?alert_id=#{alert_id}")

        view
        |> element("#time_range_form")
        |> render_change(%{
          "time_range" => %{
            "active_period_start" => "2024-05-01T10:16:00"
          }
        })

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        :timer.sleep(50)
        edited_alert = AlertsUI.Alerts.get_by_alert_id(alert_id)

        assert [
                 %{route_id: "Blue", route_type: 3, stop_id: "place-aqucl"},
                 %{route_id: "Bluer", route_type: 3, stop_id: "place-aqucl"},
                 %{route_id: "Blue", route_type: 3, stop_id: "place-pktrm"},
                 %{route_id: "Bluer", route_type: 3, stop_id: "place-pktrm"}
               ] =
                 Map.get(edited_alert, :informed_entity)
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
           end,
           get: fn "Bluer" -> @route_two end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type -> [@stop] end,
           by_route: fn _, _ -> [@stop] end,
           by_route: fn _, _, _opts -> [@stop] end,
           get: fn _id -> @stop end
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

        {:ok, document} =
          view
          |> render_async()
          |> Floki.parse_document()

        assert document_has_element?(document, "option[value=\"Blue\"]")
        assert document_has_element?(document, "option[value=\"Bluer\"][selected=\"selected\"]")

        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{header_text: "hello"}
        })

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        # query the db
        flash = assert_redirect(view, "/")

        alert_id =
          flash["info"]
          |> String.replace("New alert #", "")
          |> String.replace(" created", "")

        new_alert = AlertsUI.Alerts.get_by_alert_id(alert_id)

        assert [%{route_id: "Bluer"}] = Map.get(new_alert, :informed_entity)
      end
    end

    @tag :logged_in_user
    test "publishing a bus multi-route detour AFTER selecting and deselecting will put up a flash error for the missing route",
         %{
           conn: conn
         } do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route_type, _direction, _opts -> [@stop] end]}
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
        |> element("button#review", "Review and submit")
        |> render_click()

        # Inline
        assert has_element?(view, "p.text-text-error", "Select stop(s)")
        assert has_element?(view, "p.text-text-error", "Select route(s)")

        # Flash
        flash_text =
          view
          |> element("#flash")
          |> render()

        assert flash_text =~ "Select stop(s)" && flash_text =~ "Select route(s)"
      end
    end
  end
end
