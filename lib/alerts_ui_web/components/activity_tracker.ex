defmodule AlertsUIWeb.ActivityTracker do
  require Logger

  @moduledoc """
  Component tracks user movement in the app to decide when to expire
  their session based on idleness. We generate two kinds of events in
  client: **activity**, when a user interacts with the application, and
  **inactivity**, an event generated every 30 seconds automatically to
  check of the session is still valid, and log the user out if not.
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
    check_authentication(socket, true)
  end

  @impl true
  def handle_event("inactivity", _params, socket) do
    check_authentication(socket, false)
  end

  defp check_authentication(socket, update_last_active) do
    now = System.system_time(:second)
    email = socket.assigns.current_user.email

    if UserAuth.auth_expired?(socket.assigns, now) do
      {:noreply, redirect(socket, to: ~p"/reauthenticate?email=#{email}")}
    else
      if update_last_active do
        {:noreply, assign(socket, last_active: now)}
      else
        {:noreply, socket}
      end
    end
  end
end
