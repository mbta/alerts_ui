defmodule AlertsUIWeb.FormComponents.Helpers.ErrorFormatter do
  @moduledoc """
  Formats errors for form
  """

  import Ecto.Changeset

  alias AlertsUIWeb.FormComponents.Helpers.ServiceEffectCombinations

  @field_name_to_error_message %{
    header_text: "Enter message text",
    route_ids: "Select route(s)",
    stop_ids: "Select stop(s)",
    trip_ids: "Select trip(s)",
    direction: "Select direction",
    facility_id: "Select a facility",
    accept_banner: "Check box to show you understand"
  }

  @spec parse_field_errors(Ecto.Changeset.t() | list() | map()) :: Keyword.t()
  def parse_field_errors(error_list) when is_list(error_list) do
    Enum.map(error_list, fn {key, {msg, opts}} ->
      {key, {Map.get(@field_name_to_error_message, key, msg), opts}}
    end)
  end

  def parse_field_errors(%Ecto.Changeset{} = changeset) do
    traverse_errors(changeset, fn _changeset, field, {msg, _opts} ->
      Map.get(@field_name_to_error_message, field, msg)
    end)
    |> Enum.map(fn {k, v} -> {k, {v |> join_errors(), []}} end)
  end

  def join_errors([first | _] = errors) when is_binary(first) do
    Enum.join(errors, ", ")
  end

  # For array fields
  def join_errors(errors) do
    errors
  end

  def parse_field_errors(error_map, combination) when is_map(error_map) do
    if Map.has_key?(error_map, :informed_entity) do
      missing_fields_map =
        combination
        |> ServiceEffectCombinations.required_fields()
        |> Enum.reduce(%{}, fn field, acc -> Map.put(acc, field, ["is required"]) end)

      error_map |> Map.drop([:informed_entity]) |> Map.merge(missing_fields_map)
    else
      error_map
    end
    |> Enum.map(fn {key, msg} ->
      {key, {Map.get(@field_name_to_error_message, key, Enum.join(msg, ", ")), []}}
    end)
  end
end
