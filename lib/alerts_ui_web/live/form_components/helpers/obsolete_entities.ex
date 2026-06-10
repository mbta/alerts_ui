defmodule AlertsUIWeb.FormComponents.Helpers.ObsoleteEntities do
  @moduledoc """
  extracted shared functions for processing obsolete entities inside async handlers
  """

  @spec send_obsolete_ids?(map(), list()) :: boolean()
  def send_obsolete_ids?(obsolete_ids, required_fields) do
    obsolete_ids_found = Enum.any?(obsolete_ids, fn {_k, v} -> !Enum.empty?(v) end)
    all_fields_in = Enum.sort(Map.keys(obsolete_ids)) == Enum.sort(required_fields)

    obsolete_ids_found && all_fields_in
  end

  @spec ids_with_obsolete_entities_removed(map(), map(), list()) :: map()
  def ids_with_obsolete_entities_removed(alert_data, obsolete_ids, required_fields) do
    required_fields
    |> Enum.map(fn field ->
      obsolete_ids = Map.get(obsolete_ids, field, [])
      {field, (alert_data[field] || []) -- obsolete_ids}
    end)
    |> filter_out_empty_values
    |> Enum.into(%{})
  end

  @spec stop_names_and_ids_with_obsolete_entities_removed(map(), map(), list()) :: map()
  def stop_names_and_ids_with_obsolete_entities_removed(
        alert_data,
        obsolete_ids,
        required_fields
      ) do
    if :stop_ids in required_fields do
      original_stop_names_and_ids = Map.get(alert_data, :stop_names_and_ids) || []
      obsolete_stop_ids = Map.get(obsolete_ids, :stop_ids, [])

      new_stop_names_and_ids =
        Enum.reject(original_stop_names_and_ids, fn stop_and_id ->
          [_name, original_id] = String.split(stop_and_id, "|")

          original_id in obsolete_stop_ids
        end)

      %{stop_names_and_ids: new_stop_names_and_ids} |> filter_out_empty_values |> Enum.into(%{})
    else
      %{}
    end
  end

  @spec original_selections_with_obsolete_entities_removed(map(), map(), list()) :: map()
  def original_selections_with_obsolete_entities_removed(
        alert_data,
        obsolete_ids,
        required_fields
      ) do
    field_map = %{
      route_ids: :original_route_selections,
      stop_ids: :original_stop_selections,
      trip_ids: :original_trip_selections,
      facility_ids: :original_facility_selections
    }

    required_fields
    |> Enum.map(fn field ->
      obsolete_ids = Map.get(obsolete_ids, field, [])

      target_field = field_map[field]

      target_field_values =
        Enum.reject(alert_data[target_field] || [], fn original_string ->
          [_name, original_id] = String.split(original_string, "|")
          original_id in obsolete_ids
        end)

      {target_field, target_field_values}
    end)
    |> filter_out_empty_values
    |> Enum.into(%{})
    |> Map.put(:stop_names_and_ids, ["South Station|place-sstat"])
  end

  defp filter_out_empty_values(enum) do
    Enum.map(enum, fn
      {k, []} -> {k, nil}
      {k, v} -> {k, v}
    end)
  end
end
