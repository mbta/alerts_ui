alias AlertsUI.Models.InformedEntity

import AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertDataHelpers,
  only: [
    combination_for: 2,
    facility_types: 1,
    get_single_route_effect_names: 0,
    humanize_effect_name: 2
  ]

defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.ModeEffectChange do
  @moduledoc """
  Helpers for converting an alert's mode or effect type.
  """

  # All of the form fields we need in order to figure out what to retain
  @form_fields [
    :route_ids,
    :stop_ids,
    :trip_ids,
    :facility_ids,
    :stop_names_and_ids,
    :combination,
    :route_type,
    :effect_name
  ]

  @full_reset %{
    direction: nil,
    route_ids: [],
    stop_ids: [],
    trip_ids: [],
    facility_ids: [],
    stop_names_and_ids: []
  }

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

  @spec new_form_values(Phoenix.HTML.Form.t(), integer(), String.t()) :: map()
  def new_form_values(form, next_route_type, next_effect_name)

  def new_form_values(form, next_route_type, next_effect_name) do
    previous_combination = form[:combination]

    next_combination = combination_for(next_route_type, next_effect_name)

    previous_route_type = form[:route_type]

    cond do
      # If the mode changes, wipe all values
      next_route_type !== previous_route_type ->
        @full_reset

      previous_combination === next_combination ->
        same_combination(previous_combination, form, next_route_type, next_effect_name)

      true ->
        different_combination(previous_combination, next_combination, form)
    end
  end

  @spec same_combination(atom(), Phoenix.HTML.Form.t(), integer(), String.t()) :: map()
  defp same_combination(combination, form, next_route_type, next_effect_name)

  defp same_combination(:ACCESS, form, _next_route_type, next_effect_name) do
    previous_effect_name = form[:effect_name]
    previous_facility_types = facility_types(previous_effect_name)
    next_facility_types = facility_types(next_effect_name)

    cond do
      # If the next state has all facility types, do not remove anything
      next_facility_types === InformedEntity.all_facility_types() ->
        %{}

      previous_facility_types !== next_facility_types ->
        %{facility_ids: nil}

      true ->
        %{}
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

  # Eventually we can be smarter about what we retain depending on combo changes, i.e.
  # def different_combination(:RDS, :SR, form) do ...
  defp different_combination(_previous_combination, _next_combination, _) do
    @full_reset
  end
end
