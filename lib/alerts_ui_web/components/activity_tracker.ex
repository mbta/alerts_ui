defmodule AlertsUIWeb.ActivityTracker do
  use AlertsUIWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div phx-hook="ActivityTracker" id="activity-tracker"></div>
    """
  end

  # should we receive socket here or conn?
  @impl true
  def handle_event("activity", _params, socket) do
    IO.inspect(socket, limit: :infinity)
    # basically, idle time to be checked here instead?
    # if idle expires at time < now, then we should redirect and handle expiration
    # otherwise, update latest tracked time


    {:noreply, socket}
  end
end
