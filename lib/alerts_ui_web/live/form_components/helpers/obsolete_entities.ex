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
    |> Enum.map(fn
      {k, []} -> {k, nil}
      {k, v} -> {k, v}
    end)
    |> Enum.into(%{})
  end
end
