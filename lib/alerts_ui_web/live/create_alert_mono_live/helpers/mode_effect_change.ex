import AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertDataHelpers,
  only: [
    combination_for: 2,
    get_single_facility_effect_names: 0,
    get_single_route_effect_names: 0,
    humanize_effect_name: 2
  ]

defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.ModeEffectChange do
  @moduledoc """
  Helpers for converting an alert's mode or effect type.
  """

  @full_reset %{
    route_ids: [],
    stop_ids: [],
    trip_ids: [],
    facility_ids: [],
    stop_names_and_ids: []
  }

  @spec new_form_values(Phoenix.HTML.Form.t(), integer(), String.t()) :: map()
  def new_form_values(form, next_route_type, next_effect_name)

  def new_form_values(form, next_route_type, next_effect_name) do
    previous_combination = form[:combination].value

    next_combination = combination_for(next_route_type, next_effect_name)

    previous_route_type = form[:route_type].value

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

  defp same_combination(:ACCESS, form, next_route_type, next_effect_name) do
    next_single_facility? =
      humanize_effect_name(next_route_type, next_effect_name) in get_single_facility_effect_names()

    currently_one_facility? = length(form[:facility_ids].value) === 1

    if next_single_facility? and currently_one_facility? do
      %{single_facility_id: hd(form[:facility_ids].value)}
    else
      %{}
    end
  end

  defp same_combination(_combination, form, next_route_type, next_effect_name) do
    # If it is the same combination and service type, we want to retain the same selections, but
    # we need to do some massaging of the data between single and multi-selectors
    next_single_route? =
      humanize_effect_name(next_route_type, next_effect_name) in get_single_route_effect_names()

    currently_one_route? = length(form[:route_ids].value) === 1

    if next_single_route? and currently_one_route? do
      %{single_route_id: hd(form[:route_ids].value)}
    else
      %{}
    end
  end

  # Eventually we can be smarter about what we retain depending on combo changes, i.e.
  # def different_combination(:RDS, :SR, form) do ...
  defp different_combination(_previous_combination, _next_combination, _) do
    @full_reset
  end
end
