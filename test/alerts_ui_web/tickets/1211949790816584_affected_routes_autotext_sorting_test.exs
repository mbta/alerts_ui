defmodule AlertsUIWeb.Tickets.AffectedRoutesAutotextSortingTest do
  @moduledoc """
  Regression test for Asana ticket 1211949790816584
  "🐛 Improve sorting for affected routes auto-text"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1211949790816584

  Acceptance criteria — the sort order for routes in Main Message auto-text,
  Supporting Information auto-text, Affected service (review modal), and the
  routes filter should be:
    * First by mode: Subway, Commuter Rail, Bus, Ferry
    * All modes sorted by long_name except bus, sorted by short_name
    * Alpha bus routes first (CT/SL...), then numerical
    * Numerical bus routes sorted numerically — 171 belongs between 100 and 200,
      NOT between 17 and 18

  This exercises `BuildAutoText.sort_routes/1`, the function that produces the
  ordered route name list embedded into both the auto-text and the affected
  service surfaces. Verified live on dev-green (Andrew station-issue supporting
  info: "Red Line, CT3, 9, 10, 16, 17, 18, 171").

  Note: `sort_routes/1` groups by mode and re-sorts the *bus* bucket; subway /
  commuter rail / ferry buckets keep the order they arrive in (the picker hands
  them over already ordered by the V3 API `sort_order`, which is what
  `SelectFormatter` sorts the filter & pickers by — observed live as Blue,
  Orange, Red etc.). The by-long_name guarantee for non-bus modes therefore
  lives in `SelectFormatter.sort_order/1`, exercised by the filter/picker
  surfaces, not in `sort_routes/1`.
  """
  use ExUnit.Case, async: true

  alias AlertsUIWeb.CreateAlertLive.Helpers.AutoText.BuildAutoText
  alias MBTAV3API.Routes.Route

  # type: 1 = subway/heavy rail, 0 = light rail, 2 = commuter rail, 3 = bus, 4 = ferry
  defp subway(name, long), do: %Route{id: name, type: 1, name: "", long_name: long}
  defp cr(name, long), do: %Route{id: name, type: 2, name: "", long_name: long}
  defp bus(name), do: %Route{id: name, type: 3, name: name, long_name: "Bus #{name}"}
  defp ferry(name, long), do: %Route{id: name, type: 4, name: "", long_name: long}

  describe "sort_routes/1 (ticket 1211949790816584)" do
    test "the ticket's exact bug: 171 sorts numerically, not between 17 and 18" do
      # Scrambled input — note 171 and 17/18 deliberately adjacent in input.
      routes = [bus("18"), bus("171"), bus("17"), bus("100"), bus("200"), bus("137")]

      sorted = BuildAutoText.sort_routes(routes)

      assert sorted == ["17", "18", "100", "137", "171", "200"]

      # The precise regression assertion from the ticket:
      i = fn name -> Enum.find_index(sorted, &(&1 == name)) end

      assert i.("100") < i.("171") and i.("171") < i.("200"),
             "171 must fall between 100 and 200"

      assert i.("18") < i.("171"), "171 must NOT be sorted between 17 and 18"
    end

    test "alpha bus routes come before numerical bus routes" do
      routes = [
        bus("1"),
        bus("171"),
        %Route{id: "SL1", type: 3, name: "SL1"},
        %Route{id: "CT3", type: 3, name: "CT3"},
        bus("9")
      ]

      sorted = BuildAutoText.sort_routes(routes)

      assert sorted == ["CT3", "SL1", "1", "9", "171"]
    end

    test "routes are grouped by mode in order: subway, commuter rail, bus, ferry" do
      # Subway/CR/ferry arrive pre-sorted by the picker (V3 sort_order); sort_routes/1
      # groups them by mode and preserves their incoming intra-mode order, while
      # re-sorting bus routes (alpha-first, then numeric-numerically). Here the
      # subway routes are supplied in their picker order (Blue before Red).
      routes = [
        ferry("Boat-F1", "Hingham Ferry"),
        bus("171"),
        cr("CR-Fitchburg", "Fitchburg Line"),
        subway("Blue", "Blue Line"),
        %Route{id: "SL1", type: 3, name: "SL1"},
        subway("Red", "Red Line"),
        bus("9")
      ]

      sorted = BuildAutoText.sort_routes(routes)

      assert sorted == [
               "Blue Line",
               "Red Line",
               "Fitchburg Line",
               "SL1",
               "9",
               "171",
               "Hingham Ferry"
             ]

      # The mode grouping itself is the guarantee, regardless of intra-subway input order:
      i = fn name -> Enum.find_index(sorted, &(&1 == name)) end
      assert i.("Red Line") < i.("Fitchburg Line"), "subway before commuter rail"
      assert i.("Fitchburg Line") < i.("SL1"), "commuter rail before bus"
      assert i.("171") < i.("Hingham Ferry"), "bus before ferry"
    end

    test "matches the Andrew station-issue order observed live on dev-green" do
      # Affected routes for Andrew: Red Line + bus connections CT3, 9, 10, 16, 17, 18, 171
      routes = [
        bus("171"),
        bus("17"),
        subway("Red", "Red Line"),
        bus("10"),
        %Route{id: "CT3", type: 3, name: "CT3"},
        bus("18"),
        bus("9"),
        bus("16")
      ]

      sorted = BuildAutoText.sort_routes(routes)

      assert sorted == ["Red Line", "CT3", "9", "10", "16", "17", "18", "171"]
    end
  end
end
