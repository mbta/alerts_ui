alias AlertsUIWeb.FormComponents.Helpers.GetKeyForModeEffect

defmodule AlertsUIWeb.CreateAlertLive.Helpers.NotificationToggle do
  @moduledoc """
  Helpers to work with the notification toggle
  """
  def get_notification_toggle_default(
        %{notification_toggle: nil, route_type: route_type},
        effect_name,
        action
      )
      when action in [:creating, :duplicating] do
    GetKeyForModeEffect.get_value_of_key(
      :send_push_notification_on_create,
      route_type,
      effect_name
    )
  end

  def get_notification_toggle_default(
        %{notification_toggle: nil, route_type: route_type},
        effect_name,
        :editing
      ) do
    GetKeyForModeEffect.get_value_of_key(
      :send_push_notification_on_edit,
      route_type,
      effect_name
    )
  end

  def get_notification_toggle_default(%{notification_toggle: notification_toggle}, _, _) do
    notification_toggle
  end
end
