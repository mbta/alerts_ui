defmodule AlertsUIWeb.FormComponents.Helpers.ErrorFormatter do
  @moduledoc """
  Formats errors for form
  """

  import Ecto.Changeset

  alias AlertsUIWeb.CreateAlertLive.Helpers.ServiceEffectCombinations

  @field_name_to_error_message %{
    header_text: "Enter message text",
    single_route_id: "Select a route",
    route_ids: "Select route(s)",
    stop_ids: "Select stop(s)",
    trip_ids: "Select trip(s)",
    direction: "Select direction",
    single_facility_id: "Select a facility",
    facility_ids: "Select facility",
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
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, fn msg -> {field, {msg, []}} end)
    end)
    # Remove empty values
    |> Enum.reject(fn {_key, value} -> value === {%{}, []} end)
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
