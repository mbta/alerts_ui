defmodule AlertsUIWeb.CreateAlertLive.Helpers.GreenLine do
  @moduledoc """
    Given a list of stops chunked by route id, models their branching structure as a polytree and
    returns a list of stops "in order" according to the following rubric:
      Using the head of the longest (aka 'primary') route through the tree,
      - if there aren't any branches at that node, return the next node.
      - if there's a branch merging INTO it, start at the head of that branch, get all its stops, and place them before the node.
      - if there are branches coming from it, gather the stops to the end of that branch, and place them after the node.
      - continue to the end of the primary branch.
      - this is recursive, so branches off branches follow the same logic.
      This code is heavily based on DotCom's logic for the same task.
  """
  def put_stops_in_order(stops_by_route_id) do
    polytree =
      stops_by_route_id
      |> Enum.map(fn {_route_id, stops} ->
        stops |> Enum.map(fn stop -> {stop.id, stop} end)
      end)
      |> UnrootedPolytree.from_lists()

    next_stop_or_branch(polytree, hd(longest_path(polytree)), [], [])
    |> Enum.map(&node_for_id(polytree, &1).value)
  end

  def next_stop_or_branch(stop_tree, stop_id, merging_in_branches, splitting_off_branches)
      when is_list(splitting_off_branches) and splitting_off_branches != [] do
    {splitting_off_branch, remaining_splitting_off_branches} =
      List.pop_at(splitting_off_branches, -1)

    branch_stop_ids = stops_to_terminus(stop_tree, splitting_off_branch)
    {terminal_stop_id, non_terminal_stops} = List.pop_at(branch_stop_ids, -1)

    [
      terminal_stop_id,
      non_terminal_stops |> Enum.reverse(),
      next_stop_or_branch(
        stop_tree,
        stop_id,
        merging_in_branches,
        remaining_splitting_off_branches
      )
    ]
  end

  def next_stop_or_branch(stop_tree, stop_id, merging_in_branches, splitting_off_branches) do
    next_ids = next_stop_ids(stop_tree, stop_id)
    new_merging_in_branches = new_merging_in_branches(merging_in_branches, stop_tree, stop_id)
    merging_branch = merging_branch(stop_id, new_merging_in_branches)

    cond do
      is_list(merging_branch) && merging_branch != [] ->
        remaining_merging_in_branches = Enum.filter(merging_in_branches, &(&1 !== merging_branch))
        [starting_id | non_starting_stops] = merging_branch

        [
          starting_id,
          non_starting_stops |> Enum.reverse(),
          next_stop_or_branch(
            stop_tree,
            stop_id,
            remaining_merging_in_branches,
            splitting_off_branches
          )
        ]

      is_list(next_ids) && next_ids != [] ->
        [next_id, new_splitting_off_branches] = next_primary_and_branches(stop_tree, next_ids)

        if is_list(new_splitting_off_branches) && new_splitting_off_branches != [] do
          [
            stop_id,
            [],
            next_stop_or_branch(
              stop_tree,
              next_id,
              merging_in_branches,
              new_splitting_off_branches
            )
          ]
        else
          merging_in_branches_with_next =
            merging_in_branches_with_next(stop_tree, new_merging_in_branches)

          [
            stop_id,
            next_stop_or_branch(stop_tree, next_id, merging_in_branches_with_next, [])
          ]
        end

      true ->
        [stop_id, next_ids]
    end
    |> List.flatten()
  end

  def merging_in_branches_with_next(stop_tree, new_merging_in_branches) do
    new_merging_in_branches
    |> Enum.map(fn branch ->
      last_stop_id = List.last(branch)
      Enum.concat(branch, next_stop_ids(stop_tree, last_stop_id))
    end)
  end

  def new_merging_in_branches(merging_in_branches, stop_tree, stop_id) do
    merging_in_branches
    |> Enum.concat(new_branches_starting_in_slice(stop_tree, stop_id))
    |> Enum.map(&if is_list(&1), do: &1, else: [&1])
  end

  def merging_branch(stop_id, new_merging_in_branches) do
    Enum.find(new_merging_in_branches, [], fn branch -> List.last(branch) === stop_id end)
  end

  def stops_to_terminus(stop_tree, stop_id, stops \\ []) do
    stops = [stop_id | stops]
    next_stop_ids = next_stop_ids(stop_tree, stop_id)

    if is_list(next_stop_ids) && next_stop_ids != [] do
      next_stop_ids |> Enum.flat_map(fn s_id -> stops_to_terminus(stop_tree, s_id, stops) end)
    else
      stops
    end
    |> Enum.uniq()
  end

  def next_primary_and_branches(stop_tree, stop_ids) do
    primary_path = longest_path(stop_tree)

    case Enum.chunk_by(stop_ids, fn id -> id in primary_path end) do
      [primary, branches] -> [hd(primary), branches]
      [primary] -> [hd(primary), []]
    end
  end

  def new_branches_starting_in_slice(stop_tree, stop_id) do
    stop_tree
    |> slice_for_id(stop_id)
    |> Enum.filter(fn new_id ->
      new_id !== stop_id && new_id in stop_tree.starting_nodes
    end)
  end

  def slices(stop_tree) do
    length = longest_path_length(stop_tree)

    if length < 1 do
      [[]]
    else
      slice_sets = for _x <- 1..length, do: MapSet.new()

      stop_tree
      |> longest_path
      |> Enum.with_index()
      |> Enum.reduce(slice_sets, fn {stop_id, index}, slice_sets ->
        record_id_positions(stop_id, stop_tree, slice_sets, index)
      end)
    end
  end

  def record_id_positions_moving_forward(stop_tree, slice_sets, stop_id, index) do
    new_set = MapSet.put(Enum.at(slice_sets, index), stop_id)
    slice_sets = List.replace_at(slice_sets, index, new_set)

    stop_tree
    |> next_stop_ids(stop_id)
    |> Enum.reduce(slice_sets, fn next_id, slice_sets ->
      record_id_positions_moving_forward(stop_tree, slice_sets, next_id, index + 1)
    end)
  end

  def record_id_positions_moving_backward(stop_tree, slice_sets, stop_id, index) do
    new_set = MapSet.put(Enum.at(slice_sets, index), stop_id)
    slice_sets = List.replace_at(slice_sets, index, new_set)

    stop_tree
    |> previous_stop_ids(stop_id)
    |> Enum.reduce(slice_sets, fn previous_id, slice_sets ->
      record_id_positions_moving_backward(stop_tree, slice_sets, previous_id, index - 1)
    end)
  end

  def record_id_positions(stop_id, stop_tree, slice_sets, index) do
    slice_sets = record_id_positions_moving_forward(stop_tree, slice_sets, stop_id, index)
    record_id_positions_moving_backward(stop_tree, slice_sets, stop_id, index)
  end

  def slice_for_id(stop_tree, stop_id) do
    stop_tree |> slices() |> Enum.find([], fn slice -> stop_id in slice end)
  end

  def node_for_id(stop_tree, stop_id) do
    {:ok, result} = UnrootedPolytree.node_for_id(stop_tree, stop_id)
    result
  end

  def longest_path(stop_tree) do
    stop_tree
    |> paths()
    |> Enum.find(fn path -> length(path) === longest_path_length(stop_tree) end)
  end

  def longest_path_length(stop_tree) do
    stop_tree |> paths() |> Enum.map(&length(&1)) |> Enum.max()
  end

  def paths(stop_tree) do
    stop_tree.starting_nodes |> Enum.flat_map(fn node_id -> paths_from(stop_tree, node_id) end)
  end

  def paths_from(stop_tree, stop_id) do
    if end_node?(stop_tree, stop_id) do
      [stop_id]
    else
      get_paths_from(stop_tree, stop_id)
    end
  end

  defp get_paths_from(stop_tree, stop_id) do
    next_stop_ids(stop_tree, stop_id)
    |> Enum.flat_map(fn next_id ->
      paths_from(stop_tree, next_id)
      |> Enum.map(fn stop_ids -> prepend_stop_id(stop_ids, stop_id) end)
    end)
  end

  def prepend_stop_id(stop_tree_ids, stop_id) when is_binary(stop_tree_ids) do
    [stop_id | [stop_tree_ids]] |> List.flatten([])
  end

  def prepend_stop_id(stop_tree_ids, stop_id) do
    [stop_id | stop_tree_ids] |> List.flatten([])
  end

  def end_node?(stop_tree, stop_id) do
    stop_tree |> next_stop_ids(stop_id) |> length === 0
  end

  def next_stop_ids(stop_tree, stop_id) do
    stop_tree.edges[stop_id].next
  end

  def previous_stop_ids(stop_tree, stop_id) do
    stop_tree.edges[stop_id].previous
  end
end
