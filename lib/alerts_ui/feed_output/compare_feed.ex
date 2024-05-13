defmodule AlertsUI.FeedOutput.CompareFeed do
  @moduledoc """
    Functions to check outgoing feed against incoming
  """

  @spec compare_headers(map(), map()) :: :ok | {:header_mismatch, list()}
  def compare_headers(incoming_header, outgoing_header) do
    version_ok =
      incoming_header["gtfs_realtime_version"] == outgoing_header["gtfs_realtime_version"]

    incrementality_ok = incoming_header["incrementality"] == outgoing_header["incrementality"]

    timestamp_ok =
      is_integer(incoming_header["timestamp"]) and is_integer(outgoing_header["timestamp"])

    case version_ok and incrementality_ok and timestamp_ok do
      true -> :ok
      false -> {:header_mismatch, [incoming_header, outgoing_header]}
    end
  end

  @spec compare_entity_lists(any(), any()) :: :ok | {atom(), list()}
  def compare_entity_lists(incoming, outgoing) do
    # this relies on consistent ordering of alert_ids inside the entity lists
    incoming_ids = Enum.map(incoming, & &1["id"])
    outgoing_ids = Enum.map(outgoing, & &1["id"])

    case length(incoming_ids) == length(outgoing_ids) do
      true ->
        compare_alert_lists(incoming, outgoing)

      false ->
        {:alert_list_length_difference,
         [
           "incoming_length: #{length(incoming_ids)}",
           "outgoing_length: #{length(outgoing_ids)}",
           List.myers_difference(incoming_ids, outgoing_ids)
           |> Enum.filter(fn {k, _v} -> k !== :eq end)
         ]}
    end
  end

  @spec compare_alert_lists(list(), list()) :: :ok | {atom(), list()}
  def compare_alert_lists(incoming, outgoing) do
    zipped_list = List.zip([incoming, outgoing])

    alerts_match =
      Enum.map(zipped_list, fn {incoming, outgoing} ->
        case incoming["id"] == outgoing["id"] do
          true -> compare_alerts(incoming, outgoing)
          false -> {:id_mismatch, [incoming["id"], outgoing["id"]]}
        end
      end)

    case Enum.all?(alerts_match, &(&1 == :ok)) do
      true -> :ok
      false -> {:error_in_alert_match, Enum.filter(alerts_match, &(&1 != :ok))}
    end
  end

  def compare_alerts(incoming, outgoing) do
    # removes list fields to be diffed seperately
    {incoming_ie, filtered_incoming} = Map.pop(incoming["alert"], "informed_entity", [])
    {outgoing_ie, filtered_outgoing} = Map.pop(outgoing["alert"], "informed_entity", [])

    # {incoming_ap, filtered_incoming} = Map.pop(filtered_incoming, "active_period", [])
    # {outgoing_ap, filtered_outgoing} = Map.pop(filtered_outgoing, "active_period", [])

    filtered_incoming =
      filtered_incoming |> Map.drop(["alert_lifecycle", "last_modified_timestamp", "active_period"])

    filtered_outgoing =
      filtered_outgoing |> Map.drop(["alert_lifecycle", "last_modified_timestamp", "active_period"])

    with %{value: _, changed: :equal} <- MapDiff.diff(filtered_incoming, filtered_outgoing),
        #  :ok <- compare_active_periods(incoming_ap, outgoing_ap, incoming["id"]),
         :ok <- compare_informed_entities(incoming_ie, outgoing_ie, incoming["id"]) do
      :ok
    else
      changed_map = %{value: _, changed: _} ->
        {:alert_map_mismatch, ["Alert id: #{incoming["id"]}", changed_map]}

      other_result ->
        other_result
    end
  end

  def compare_active_periods(incoming, outgoing, alert_id) do
    with true <- length(incoming) == length(outgoing),
         [] <- incoming -- outgoing do
      :ok
    else
      _ -> {:active_period_mismatch, ["Alert_id: #{alert_id}", incoming, outgoing]}
    end
  end

  def compare_informed_entities(incoming, outgoing, alert_id) do
    # this relies on consistent ordering in the "activities" field
    with true <- length(incoming) == length(outgoing),
         [] <- incoming -- outgoing do
      :ok
    else
      false ->
        {:informed_entity_length_mismatch,
         ["Alert_id: #{alert_id}", length(incoming), length(outgoing)]}

      _ ->
        {:informed_entity_content_mismatch,
         ["Alert_id: #{alert_id}", "difference:", incoming -- outgoing]}
    end
  end
end
