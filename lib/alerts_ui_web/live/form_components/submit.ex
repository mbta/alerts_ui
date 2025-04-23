defmodule AlertsUIWeb.FormComponents.Submit do
  @moduledoc """
    Live Component for delivery section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema

  @impl true
  def handle_event("save", _params, socket) do
    send(self(), :create_alert)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-w-full flex flex-col mt-4" id="submit_view">
      <.button_primary
        class="mt-8 basis-8 self-center min-w-[10%]"
        phx-target={@myself}
        name="save"
        phx-click="save"
        type="button"
        id="save"
      >
        Publish
      </.button_primary>
    </div>
    """
  end
end
