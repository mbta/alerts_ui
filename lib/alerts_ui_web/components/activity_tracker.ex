defmodule AlertsUIWeb.ActivityTracker do
  @moduledoc """
  Component tracks user movement in the app to decide when to expire their session based on idleness
  """
  use AlertsUIWeb, :live_component

  alias AlertsUIWeb.UserAuth

  @impl true
  def render(assigns) do
    ~H"""
    <div phx-hook="ActivityTracker" id="activity-tracker"></div>
    """
  end

  @impl true
  def handle_event("activity", _params, socket) do
    now = System.system_time(:second)

    new_socket =
      if UserAuth.auth_expired!(socket.assigns, now) do
        redirect(socket, to: ~p"/auth/keycloak?prompt=login")
      else
        assign(socket, last_active: now)
      end

    {:noreply, new_socket}
  end
end
