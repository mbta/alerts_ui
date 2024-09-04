defmodule AlertsUIWeb.FormComponents.Submit do
  @moduledoc """
    Live Component for delivery section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema

  @impl true
  def handle_event("save_as_draft", _params, socket) do
    send(self(), :save_as_draft)
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    send(self(), :create_alert)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class={unless @progress.name == "details", do: "hidden", else: "min-w-full flex flex-col mt-4"}
      id="submit_view"
    >
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

      <.button_secondary
        class="basis-8 self-center min-w-[10%]"
        phx-target={@myself}
        phx-click="save_as_draft"
        type="button"
        name="draft"
        id="draft"
      >
        Save as Draft
      </.button_secondary>
    </div>
    """
  end
end
