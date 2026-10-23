defmodule AlertsUIWeb.Tickets.StopSearchFilterConsistencyTest do
  @moduledoc """
  Regression test for Asana ticket 1213373025641047
  "🐛 Strange results in stop search"
  https://app.asana.com/0/1167196461144361/1213373025641047

  Bug: On a Bus Stop Closure alert, searching for a stop term such as
  "south station" could return unrelated stops because SelectFormatter was
  being called a second time with a nil search_term (re-render triggered by
  Tippy/other hooks). The nil term caused `apply_search/3` to skip filtering,
  returning the full (but previously-ordered) list.

  Acceptance criteria verified:
    AC1 – Stop search only shows results that match the search term.
    AC2 – Results are the same regardless of capitalization.
    AC3 – Results are the same for a given term even after searching
          for a different term first (search state is not leaked between
          successive phx-change events).

  Verified against dev-green on 2026-06-08.
  """
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock
  import Test.Support.Helpers

  alias AlertsUIWeb.CreateAlertLive.Helpers.SelectFormatter
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  # A set of stops where only some contain "station" in the name.
  # This lets us assert that non-matching ones are excluded.
  @south_station %Stop{id: "place-sstat", name: "South Station"}
  @summer_st %Stop{id: "place-sumrs", name: "Summer St @ South Station - Red Line entrance"}
  @aquarium %Stop{id: "place-aqucl", name: "Aquarium"}
  @park_street %Stop{id: "place-pktrm", name: "Park Street"}
  @north_station %Stop{id: "place-north", name: "North Station"}

  @all_stops [@south_station, @summer_st, @aquarium, @park_street, @north_station]

  @bus_route %Route{id: "39", name: "39", sort_order: 1, type: 3}

  defp bus_stop_closure_mocks(stops \\ @all_stops) do
    [
      {RoutesRepo, [],
       [
         by_type: fn _ -> [@bus_route] end,
         by_stop: fn _ -> [@bus_route] end,
         by_stop: fn _, _ -> [@bus_route] end
       ]},
      {StopsRepo, [],
       [
         by_route_type: fn _, _ -> stops end,
         by_route: fn _, _, _ -> stops end
       ]}
    ]
  end

  defp send_stop_search(view, term) do
    view
    |> element("form")
    |> render_change(%{
      "_target" => ["alert_data", "stop_search_term"],
      "alert_data" => %{"stop_search_term" => term}
    })

    render_async(view)
  end

  defp visible_stop_values(view) do
    {:ok, document} = view |> render() |> Floki.parse_document()

    Floki.find(document, "select#alert_data_stop_names_and_ids option")
    |> Enum.map(&Floki.attribute(&1, "value"))
    |> List.flatten()
    |> Enum.reject(&(&1 == "" or is_nil(&1)))
  end

  # ---- Unit-level tests for SelectFormatter.apply_search/3 ----

  describe "SelectFormatter.apply_search/3 (AC1/AC2)" do
    test "nil search_term returns all options unfiltered" do
      opts = [
        [key: "South Station", value: "place-sstat"],
        [key: "Aquarium", value: "place-aqucl"]
      ]

      assert SelectFormatter.apply_search(opts, nil, []) == opts
    end

    test "empty string search_term returns all options unfiltered" do
      opts = [
        [key: "South Station", value: "place-sstat"],
        [key: "Aquarium", value: "place-aqucl"]
      ]

      assert SelectFormatter.apply_search(opts, "", []) == opts
    end

    test "non-empty search_term filters to matching options only (AC1)" do
      opts = [
        [key: "South Station", value: "place-sstat"],
        [key: "Aquarium", value: "place-aqucl"],
        [key: "North Station", value: "place-north"]
      ]

      result = SelectFormatter.apply_search(opts, "station", [])
      values = Enum.map(result, &Keyword.get(&1, :value))

      assert "place-sstat" in values
      assert "place-north" in values
      refute "place-aqucl" in values
    end

    test "search is case-insensitive (AC2)" do
      opts = [
        [key: "South Station", value: "place-sstat"],
        [key: "Aquarium", value: "place-aqucl"]
      ]

      result_lower = SelectFormatter.apply_search(opts, "south station", [])
      result_upper = SelectFormatter.apply_search(opts, "SOUTH STATION", [])
      result_mixed = SelectFormatter.apply_search(opts, "South Station", [])

      assert result_lower == result_upper
      assert result_lower == result_mixed
      assert length(result_lower) == 1
      assert Keyword.get(hd(result_lower), :value) == "place-sstat"
    end

    test "values_to_keep are always included even when not matching the search" do
      opts = [
        [key: "South Station", value: "place-sstat"],
        [key: "Aquarium", value: "place-aqucl"]
      ]

      result = SelectFormatter.apply_search(opts, "station", ["place-aqucl"])
      values = Enum.map(result, &Keyword.get(&1, :value))

      assert "place-sstat" in values
      assert "place-aqucl" in values
    end
  end

  # ---- Integration: LiveView stop_search_term change events (AC1, AC2, AC3) ----

  describe "stop search in Bus • Stop closure LiveView (AC1)" do
    @tag :logged_in_user
    test "search term filters stop list to only matching stops", %{conn: conn} do
      with_mocks(bus_stop_closure_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Stop closure")
        render_async(view)

        # All stops should be visible before searching
        initial_values = visible_stop_values(view)
        assert "South Station|place-sstat" in initial_values
        assert "Aquarium|place-aqucl" in initial_values

        # Search for "station" — should show only stops with "station" in the name
        send_stop_search(view, "station")

        filtered = visible_stop_values(view)

        assert "South Station|place-sstat" in filtered,
               "South Station should appear in 'station' search results"

        assert "North Station|place-north" in filtered,
               "North Station should appear in 'station' search results"

        refute "Aquarium|place-aqucl" in filtered,
               "Aquarium must NOT appear in 'station' search results (AC1: only matching results)"

        refute "Park Street|place-pktrm" in filtered,
               "Park Street must NOT appear in 'station' search results (AC1: only matching results)"
      end
    end
  end

  describe "stop search in Bus • Stop closure LiveView (AC2 — capitalization)" do
    @tag :logged_in_user
    test "lowercase and uppercase search terms return identical stop sets", %{conn: conn} do
      with_mocks(bus_stop_closure_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Stop closure")
        render_async(view)

        send_stop_search(view, "south station")
        lowercase_results = visible_stop_values(view)

        send_stop_search(view, "SOUTH STATION")
        uppercase_results = visible_stop_values(view)

        send_stop_search(view, "South Station")
        titlecase_results = visible_stop_values(view)

        assert Enum.sort(lowercase_results) == Enum.sort(uppercase_results),
               "lowercase vs UPPERCASE should return the same stop options (AC2)"

        assert Enum.sort(lowercase_results) == Enum.sort(titlecase_results),
               "lowercase vs TitleCase should return the same stop options (AC2)"

        # None of them should contain non-matching stops
        for results <- [lowercase_results, uppercase_results, titlecase_results] do
          refute "place-aqucl" in results
          refute "place-pktrm" in results
        end
      end
    end
  end

  describe "stop search in Bus • Stop closure LiveView (AC3 — consistency after prior search)" do
    @tag :logged_in_user
    test "searching the same term after a different term gives consistent results", %{conn: conn} do
      with_mocks(bus_stop_closure_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Stop closure")
        render_async(view)

        # First search for "south station" — baseline
        send_stop_search(view, "south station")
        first_results = visible_stop_values(view)

        # Now search for something unrelated
        send_stop_search(view, "aquarium")
        aquarium_results = visible_stop_values(view)
        assert "Aquarium|place-aqucl" in aquarium_results
        refute "South Station|place-sstat" in aquarium_results

        # Search for "south station" again — must match the original results
        send_stop_search(view, "south station")
        second_results = visible_stop_values(view)

        assert Enum.sort(first_results) == Enum.sort(second_results),
               "Repeating a stop search after switching away must return the same results (AC3). " <>
                 "first=#{inspect(first_results)}, second=#{inspect(second_results)}"

        # Critically: non-matching stops must NOT appear in the second search
        refute "place-aqucl" in second_results,
               "Aquarium must not appear in second 'south station' search (AC3: no contamination from prior search)"

        refute "place-pktrm" in second_results,
               "Park Street must not appear in second 'south station' search (AC3)"
      end
    end

    @tag :logged_in_user
    test "searching the same term three times always returns the same set", %{conn: conn} do
      with_mocks(bus_stop_closure_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Stop closure")
        render_async(view)

        searches =
          for _ <- 1..3 do
            # Interleave with an unrelated search
            send_stop_search(view, "park street")
            send_stop_search(view, "south station")
            visible_stop_values(view)
          end

        [first | rest] = searches

        for result <- rest do
          assert Enum.sort(first) == Enum.sort(result),
                 "Every 'south station' search must return the same stops (AC3)"

          refute "place-aqucl" in result
          refute "place-pktrm" in result

          refute "place-north" in result,
                 "North Station does not contain 'south station' and must not appear (AC1)"
        end
      end
    end
  end
end
