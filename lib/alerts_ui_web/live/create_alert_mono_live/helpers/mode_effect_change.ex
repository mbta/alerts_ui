defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.ModeEffectChange do
  @moduledoc """
  Helpers for converting an alert's mode or effect type.
  """

  @spec new_form_values(atom(), atom(), boolean()) :: map()
  def new_form_values(
        previous_combination,
        next_combination,
        service_type_changed?
      )

  # If service type has changed, retain no selections
  def new_form_values(_, _, true) do
    %{
      route_ids: nil,
      stop_ids: nil,
      trip_ids: nil,
      facility_ids: nil
    }
  end

  # If the combination is still the same, retain all selections
  def new_form_values(previous_combination, next_combination, false)
      when previous_combination === next_combination do
    %{}
  end

  # Eventually we can be smarter about what we retain depending on combo changes
  def new_form_values(_previous_combination, _next_combination, false) do
    %{
      route_ids: nil,
      stop_ids: nil,
      trip_ids: nil,
      facility_ids: nil
    }
  end
end
