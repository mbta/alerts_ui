defmodule AlertsUIWeb.FormComponents.SuccessfulSubmission do
  @moduledoc """
    Live Component for successful alert creation
  """
  use AlertsUIWeb, :live_component

  @impl true
  def handle_event("ok", _params, socket) do
    {:noreply, redirect(socket, to: "/alerts/new")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={unless @hidden == false, do: "hidden"}>
      Alert created successfully
      <.button phx-click="ok" phx-target={@myself} class="btn btn-outline basis-8 self-center px-8">
        ok!
      </.button>
    </div>
    """
  end
end
