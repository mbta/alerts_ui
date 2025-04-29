defmodule AlertsUIWeb.FormComponents.Submit do
  @moduledoc """
    Live Component for delivery section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/alerts")}
  end

  @impl true
  def handle_event("save", _params, socket) do
    send(self(), :create_alert)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-w-full flex mt-4 mb-12 border-t border-border-primary" id="submit_view">
      <.button_secondary
        class="mt-8 mr-auto self-center border-none py-2 px-3"
        name="back"
        phx-click="move_progress"
        value="route_type_and_effect"
        type="button"
        id="back"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" /> Back
      </.button_secondary>
      <.button_secondary
        class="mt-8 self-center border-none py-2 px-3"
        phx-target={@myself}
        name="cancel"
        phx-click="cancel"
        type="button"
        id="cancel"
      >
        Cancel
      </.button_secondary>
      <.button_primary
        class="mt-8 ml-2 self-center py-2 px-3"
        phx-target={@myself}
        name="save"
        phx-click="save"
        type="button"
        id="save"
      >
        Review and submit
      </.button_primary>
    </div>
    """
  end
end
