defmodule AlertsUIWeb.CreateAlertLive.Helpers.GreenLineTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUIWeb.CreateAlertLive.Helpers.GreenLine
  alias MBTAV3API.Stops.Stop

  ###
  #          a1 ---> a2                          q1 ---> q2
  #                        \                    ˄
  #                         ˅                  /
  #  b1 ---> b2 ---> b3 ---> m1 ---> m2 ---> m3
  #                                 ˄          \
  #                                /            ˅
  #                  c1 ---> c2                  p1
  ###

  @stops_by_route %{
    "a" => [%{id: "a1"}, %{id: "a2"}, %{id: "m1"}],
    "b" => [%{id: "b1"}, %{id: "b2"}, %{id: "b3"}, %{id: "m1"}],
    "c" => [%{id: "c1"}, %{id: "c2"}, %{id: "m2"}],
    "m" => [%{id: "m1"}, %{id: "m2"}, %{id: "m3"}],
    "p" => [%{id: "m3"}, %{id: "p1"}],
    "q" => [%{id: "m3"}, %{id: "q1"}, %{id: "q2"}]
  }

  @stop_tree %{
    by_id: %{
      "a1" => %{id: "a1", value: %Stop{id: "a1"}},
      "a2" => %{id: "a2", value: %Stop{id: "a2"}},
      "b1" => %{id: "b1", value: %Stop{id: "b1"}},
      "b2" => %{id: "b2", value: %Stop{id: "b2"}},
      "b3" => %{id: "b3", value: %Stop{id: "b3"}},
      "c1" => %{id: "c1", value: %Stop{id: "c1"}},
      "c2" => %{id: "c2", value: %Stop{id: "c2"}},
      "m1" => %{id: "m1", value: %Stop{id: "m1"}},
      "m2" => %{id: "m2", value: %Stop{id: "m2"}},
      "m3" => %{id: "m3", value: %Stop{id: "m3"}},
      "p1" => %{id: "p1", value: %Stop{id: "p1"}},
      "q1" => %{id: "q1", value: %Stop{id: "q1"}},
      "q2" => %{id: "q2", value: %Stop{id: "q2"}}
    },
    edges: %{
      "a1" => %{next: ["a2"], previous: []},
      "a2" => %{next: ["m1"], previous: ["a1"]},
      "b1" => %{next: ["b2"], previous: []},
      "b2" => %{next: ["b3"], previous: ["b1"]},
      "b3" => %{next: ["m1"], previous: ["b2"]},
      "c1" => %{next: ["c2"], previous: []},
      "c2" => %{next: ["m2"], previous: ["c1"]},
      "m1" => %{next: ["m2"], previous: ["a2", "b3"]},
      "m2" => %{next: ["m3"], previous: ["c2", "m1"]},
      "m3" => %{next: ["q1", "p1"], previous: ["m2"]},
      "p1" => %{next: [], previous: ["m3"]},
      "q1" => %{next: ["q2"], previous: ["m3"]},
      "q2" => %{next: [], previous: ["q1"]}
    },
    starting_nodes: ["a1", "b1", "c1"]
  }

  @correct_stop_order [
    "b1",
    "b2",
    "b3",
    "a1",
    "m1",
    "a2",
    "m1",
    "c1",
    "m2",
    "c2",
    "m2",
    "m3",
    "p1",
    "q1",
    "q2"
  ]

  describe "paths/1" do
    test "returns every possible path through the tree" do
      expected = [
        ["a1", "a2", "m1", "m2", "m3", "q1", "q2"],
        ["a1", "a2", "m1", "m2", "m3", "p1"],
        ["b1", "b2", "b3", "m1", "m2", "m3", "q1", "q2"],
        ["b1", "b2", "b3", "m1", "m2", "m3", "p1"],
        ["c1", "c2", "m2", "m3", "q1", "q2"],
        ["c1", "c2", "m2", "m3", "p1"]
      ]

      actual = GreenLine.paths(@stop_tree)
      assert expected === actual
    end
  end

  describe "longest_path_length/1" do
    test "returns the length of the longest path through the tree" do
      assert GreenLine.longest_path_length(@stop_tree) === 8
    end
  end

  describe "slices/1" do
    test "returns an array of slices through the tree" do
      expected = [
        MapSet.new(["b1"]),
        MapSet.new(["b2", "a1"]),
        MapSet.new(["b3", "a2", "c1"]),
        MapSet.new(["m1", "c2"]),
        MapSet.new(["m2"]),
        MapSet.new(["m3"]),
        MapSet.new(["q1", "p1"]),
        MapSet.new(["q2"])
      ]

      actual = GreenLine.slices(@stop_tree)
      assert expected === actual
    end
  end

  describe "slice_for_id/2" do
    test "returns the slice of the tree for a given ID" do
      assert GreenLine.slice_for_id(@stop_tree, "c2") === MapSet.new(["m1", "c2"])
    end
  end

  describe "new_branches_starting_in_slice/2" do
    test "returns stop_id for branches starting in same slice as given stop_id" do
      assert GreenLine.new_branches_starting_in_slice(@stop_tree, "b1") === []
      assert GreenLine.new_branches_starting_in_slice(@stop_tree, "b2") === ["a1"]
      assert GreenLine.new_branches_starting_in_slice(@stop_tree, "b3") === ["c1"]
    end
  end

  describe "next_primary_and_branches/2" do
    test "given next ids, separates primary path ids from branch ones" do
      next_ids = GreenLine.next_stop_ids(@stop_tree, "m3")
      expected = ["q1", ["p1"]]
      actual = GreenLine.next_primary_and_branches(@stop_tree, next_ids)
      assert expected === actual
    end
  end

  describe "stops_to_terminus/3" do
    test "given an id, returns all stops on branch to end" do
      expected = ["q2", "q1", "m3", "m2", "m1", "b3", "b2", "b1", "p1"]
      actual = GreenLine.stops_to_terminus(@stop_tree, "b1")
      assert expected === actual
    end
  end

  describe "next_stop_or_branch/4" do
    test "given a polytree and a starting node returns list of stops in order" do
      expected = @correct_stop_order
      actual = GreenLine.next_stop_or_branch(@stop_tree, "b1", [], []) |> List.flatten()
      assert expected === actual
    end
  end

  describe "put_stops_in_order/1" do
    test "given a keyword list of stops by route, return stops in order" do
      expected = @correct_stop_order
      actual = GreenLine.put_stops_in_order(@stops_by_route)
      assert expected === actual |> Enum.map(& &1.id)
    end
  end
end
