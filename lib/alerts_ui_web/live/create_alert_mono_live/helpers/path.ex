defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.Path do
  @moduledoc """
  Utilities for computing paths for `push_patch/2`.
  """

  use AlertsUIWeb, :verified_routes

  def path_with_route_type(form_action, route_type, alert_id \\ nil) do
    case form_action do
      :new ->
        ~p"/alerts/mono/new/#{route_type}"

      :edit ->
        ~p"/alerts/mono/edit/#{alert_id}/#{route_type}"

      :duplicate ->
        ~p"/alerts/mono/duplicate/#{alert_id}/#{route_type}"
    end
  end

  def path_with_route_type_and_effect_name(form_action, route_type, effect_name, alert_id \\ nil) do
    case form_action do
      :new ->
        ~p"/alerts/mono/new/#{route_type}/#{effect_name}"

      :edit ->
        ~p"/alerts/mono/edit/#{alert_id}/#{route_type}/#{effect_name}"

      :duplicate ->
        ~p"/alerts/mono/duplicate/#{alert_id}/#{route_type}/#{effect_name}"
    end
  end
end
