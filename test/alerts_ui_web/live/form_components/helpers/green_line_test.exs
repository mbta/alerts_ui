defmodule AlertsUIWeb.FormComponents.Helpers.GreenLineTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUIWeb.FormComponents.Helpers.GreenLine
  alias MBTAV3API.Stops.Stop

  ###
  #          a1 ---> a2                          x1 ---> x2
  #                        \                    ˄
  #                         ˅                  /
  #  b1 ---> b2 ---> b3 ---> m1 ---> m2 ---> m3
  #                                 ˄          \
  #                                /            ˅
  #                  c1 ---> c2                  y1
  ###

  @branching_stop_tree %{
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
      "x1" => %{id: "x1", value: %Stop{id: "x1"}},
      "x2" => %{id: "x2", value: %Stop{id: "x2"}},
      "y1" => %{id: "y1", value: %Stop{id: "y1"}}
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
      "m3" => %{next: ["x1", "y1"], previous: ["m2"]},
      "x1" => %{next: ["x2"], previous: ["m3"]},
      "x2" => %{next: [], previous: ["x1"]},
      "y1" => %{next: [], previous: ["m3"]}
    },
    starting_nodes: ["a1", "b1", "c1"]
  }

  describe "paths/1" do
    test "returns every possible path through the tree" do
      expected = [
        ["a1", "a2", "m1", "m2", "m3", "x1", "x2"],
        ["a1", "a2", "m1", "m2", "m3", "y1"],
        ["b1", "b2", "b3", "m1", "m2", "m3", "x1", "x2"],
        ["b1", "b2", "b3", "m1", "m2", "m3", "y1"],
        ["c1", "c2", "m2", "m3", "x1", "x2"],
        ["c1", "c2", "m2", "m3", "y1"]
      ]

      actual = GreenLine.paths(@branching_stop_tree)
      assert expected === actual
    end
  end

  describe "longest_path_length/1" do
    test "returns the length of the longest path through the tree" do
      assert GreenLine.longest_path_length(@branching_stop_tree) === 8
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
        MapSet.new(["x1", "y1"]),
        MapSet.new(["x2"])
      ]

      actual = GreenLine.slices(@branching_stop_tree)
      assert expected === actual
    end
  end

  describe "slice_for_id/2" do
    test "returns the slice of the tree for a given ID" do
      assert GreenLine.slice_for_id(@branching_stop_tree, "c2") === MapSet.new(["m1", "c2"])
    end
  end

  describe "new_branches_starting_in_slice/2" do
    test "returns stop_id for branches starting in same slice as given stop_id" do
      assert GreenLine.new_branches_starting_in_slice(@branching_stop_tree, "b1") === []
      assert GreenLine.new_branches_starting_in_slice(@branching_stop_tree, "b2") === ["a1"]
      assert GreenLine.new_branches_starting_in_slice(@branching_stop_tree, "b3") === ["c1"]
    end
  end

  describe "next_primary_and_branches/2" do
    test "given next ids, separates primary path ids from branch ones" do
      next_ids = GreenLine.next_stop_ids(@branching_stop_tree, "m3")
      expected = ["x1", ["y1"]]
      actual = GreenLine.next_primary_and_branches(@branching_stop_tree, next_ids)
      assert expected === actual
    end
  end

  describe "stops_to_terminus/3" do
    test "given an id, returns all stops on branch to end" do
      expected = ["x2", "x1", "m3", "m2", "m1", "b3", "b2", "b1", "y1"]
      actual = GreenLine.stops_to_terminus(@branching_stop_tree, "b1")
      assert expected === actual
    end
  end

  describe "next_stop_or_branch/4" do
    test "given a polytree and a starting node returns list of stops in order" do
      expected = [
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
        "y1",
        "x1",
        "x2"
      ]

      actual = GreenLine.next_stop_or_branch(@branching_stop_tree, "b1", [], []) |> List.flatten()
      assert expected === actual
    end
  end
end
