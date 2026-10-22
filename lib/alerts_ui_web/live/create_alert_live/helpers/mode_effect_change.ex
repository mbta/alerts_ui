import AlertsUIWeb.CreateAlertLive.Helpers.AlertDataHelpers,
  only: [
    combination_for: 2,
    facility_types: 1,
    get_single_route_effect_names: 0,
    humanize_effect_name: 2
  ]

defmodule AlertsUIWeb.CreateAlertLive.Helpers.ModeEffectChange do
  @moduledoc """
  Helpers for converting an alert's mode or effect type.
  """

  @affected_service_fields [
    :route_ids,
    :direction,
    :stop_ids,
    :trip_ids,
    :facility_ids,
    :stop_names_and_ids,
    :service_types
  ]

  # All of the form fields we need in order to figure out what to retain
  @form_fields @affected_service_fields ++ [:combination, :route_type, :effect_name]

  @full_reset Map.new(@affected_service_fields, fn field -> {field, []} end)
              |> Map.put(:direction, nil)

  # expose @full_reset for the test to use too
  @spec full_reset() :: %{
          direction: nil,
          facility_ids: [],
          route_ids: [],
          stop_ids: [],
          stop_names_and_ids: [],
          trip_ids: [],
          service_types: []
        }
  def full_reset, do: @full_reset

  @spec condensed_form(Phoenix.HTML.Form.t()) :: map()
  @doc """
  From a Phoenix Form, return a map of relevant values needed in order to figure out
  what to retain from switching mode/effect types. This is used so we do not need to
  store another large form on the socket, and can instead just send around the values
  we need.
  """
  def condensed_form(form) do
    Map.new(@form_fields, fn field ->
      {field, form[field].value}
    end)
    |> Map.put(:source, form.source)
  end

  @spec new_form_values(Phoenix.HTML.Form.t(), integer(), String.t()) :: %{
          new: map(),
          replaced: map()
        }
  def new_form_values(form, next_route_type, next_effect_name)

  def new_form_values(form, next_route_type, next_effect_name) do
    previous_combination = form[:combination]

    next_combination = combination_for(next_route_type, next_effect_name)

    previous_route_type = form[:route_type]

    new_values =
      cond do
        # If the mode changes, wipe all values
        next_route_type !== previous_route_type ->
          @full_reset

        previous_combination === next_combination ->
          same_combination(previous_combination, form, next_route_type, next_effect_name)

        true ->
          different_combination(previous_combination, next_combination, form)
      end

    %{new: new_values, replaced: derive_cleared_values(form, new_values)}
  end

  @spec derive_cleared_values(Phoenix.HTML.Form.t(), map()) :: map()
  defp derive_cleared_values(form, new_values) do
    Map.new(new_values, fn {key, _value} -> {key, form[key]} end)
    # Remove the values that were already "empty"
    |> Map.reject(fn {key, value} ->
      value === [] or is_nil(value) or (key === :direction and value === "default")
    end)
  end

  @spec same_combination(atom(), Phoenix.HTML.Form.t(), integer(), String.t()) :: map()
  defp same_combination(combination, form, next_route_type, next_effect_name)

  defp same_combination(:ACCESS, form, _next_route_type, next_effect_name) do
    previous_effect_name = form[:effect_name]
    previous_facility_types = facility_types(previous_effect_name)
    next_facility_types = facility_types(next_effect_name)
    changing_to_superset? = previous_facility_types -- next_facility_types === []

    if changing_to_superset? do
      %{}
    else
      %{facility_ids: nil}
    end
  end

  defp same_combination(_combination, form, next_route_type, next_effect_name) do
    # If it is the same combination and service type, we want to retain the same selections, but
    # we need to do some massaging of the data between single and multi-selectors
    next_single_route? =
      humanize_effect_name(next_route_type, next_effect_name) in get_single_route_effect_names()

    currently_one_route? = length(form[:route_ids]) === 1

    cond do
      # ex: going from Bus Delay with one route selected to a Bus Detour can persist the one route
      next_single_route? and currently_one_route? ->
        %{single_route_id: hd(form[:route_ids])}

      # ex: going from Bus Delay with multiple routes selected to a Bus Detour wipes all routes
      next_single_route? and not currently_one_route? ->
        %{route_ids: []}

      true ->
        %{}
    end
  end

  @spec different_combination(:atom, :atom, Phoenix.HTML.Form.t()) :: map()
  defp different_combination(previous_combination, next_combination, form)

  defp different_combination(:RDS, :SR, _) do
    retain([:stop_ids, :stop_names_and_ids])
  end

  defp different_combination(:RDTS, :SR, _) do
    retain([:stop_ids, :stop_names_and_ids])
  end

  defp different_combination(:RDTS, :RDT, _) do
    retain([:route_ids, :trip_ids, :direction])
  end

  defp different_combination(:RDT, :RDTS, _) do
    %{}
  end

  defp different_combination(:R, :SR, _) do
    @full_reset
  end

  defp different_combination(:R, _, _) do
    %{}
  end

  defp different_combination(:SR, _, _) do
    @full_reset
  end

  defp different_combination(_, :R, _) do
    retain([:route_ids])
  end

  defp different_combination(_previous_combination, _next_combination, _) do
    @full_reset
  end

  @spec retain([atom()]) :: map()
  defp retain(fields) do
    @affected_service_fields
    |> Enum.filter(fn field -> field not in fields end)
    |> Map.new(fn field ->
      value = if field === :direction, do: nil, else: []
      {field, value}
    end)
  end
end
