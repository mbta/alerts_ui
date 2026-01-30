defmodule AlertsUIWeb.ActivityTracker do
  use AlertsUIWeb, :live_component

  alias AlertsUIWeb.UserAuth

  @impl true
  def render(assigns) do
    ~H"""
    <div phx-hook="ActivityTracker" id="activity-tracker"></div>
    """
  end

  # should we receive socket here or conn?
  @impl true
  def handle_event("activity", _params, socket) do
    now = System.system_time(:second)

    auth_time_expires = socket.assigns.last_auth_time + UserAuth.max_session_time()
    idle_time_expires = socket.assigns.last_active + UserAuth.idle_time()

    new_socket =
      if min(auth_time_expires, idle_time_expires) < now do
        redirect(socket, to: ~p"/auth/keycloak/logout")
      else
        assign(socket, last_active: now)
      end

    {:noreply, new_socket}
  end
end
