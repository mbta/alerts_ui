defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.Path do
  @moduledoc """
  Utilities for computing paths for `push_patch/2`.
  """

  alias Phoenix.HTML.Form
  alias Phoenix.LiveView.Socket
  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.FormComponents.Helpers.EffectsForRouteTypes

  use AlertsUIWeb, :verified_routes

  def path(
        %{
          live_action: live_action,
          alert_id: alert_id
        } = _assigns
      ) do
    case live_action do
      :new ->
        ~p"/alerts/mono/new/"

      :edit ->
        ~p"/alerts/mono/edit/#{alert_id}"

      :duplicate ->
        ~p"/alerts/mono/duplicate/#{alert_id}"
    end
  end

  def path_with_route_type(
        %{
          live_action: live_action,
          alert_id: alert_id
        } = _assigns,
        path_route_type
      ) do
    case live_action do
      :new ->
        ~p"/alerts/mono/new/#{path_route_type}"

      :edit ->
        ~p"/alerts/mono/edit/#{alert_id}/#{path_route_type}"

      :duplicate ->
        ~p"/alerts/mono/duplicate/#{alert_id}/#{path_route_type}"
    end
  end

  # TODO not really sure we should keep this in but the tests weren't filling this in correctly. Re-evaluate.
  def path_with_route_type_and_effect_name(%{path_route_type: nil}, _), do: ~p"/alerts/mono/new"

  def path_with_route_type_and_effect_name(
        %{
          live_action: live_action,
          path_route_type: path_route_type,
          alert_id: alert_id
        } = _assigns,
        new_path_effect_name
      ) do
    case live_action do
      :new ->
        ~p"/alerts/mono/new/#{path_route_type}/#{new_path_effect_name}"

      :edit ->
        ~p"/alerts/mono/edit/#{alert_id}/#{path_route_type}/#{new_path_effect_name}"

      :duplicate ->
        ~p"/alerts/mono/duplicate/#{alert_id}/#{path_route_type}/#{new_path_effect_name}"
    end
  end

  def path_route_type_from_socket(%Socket{} = socket) do
    path_route_type_from_form(socket.assigns.form)
  end

  def path_route_type_from_form(%Form{} = form) do
    path_route_type(
      form[:route_type].value,
      form[:effect_name].value
    )
  end

  def path_route_type(nil, effect_name) do
    if effect_name in EffectsForRouteTypes.list_path_names(:facility) do
      :facility
    else
      :systemwide
    end
  end

  def path_route_type(route_type, _effect_name) do
    InformedEntity.route_code_mapping(route_type)
  end

  def path_effect_name_from_socket(%Socket{} = socket) do
    socket.assigns.form[:effect_name].value
  end
end
