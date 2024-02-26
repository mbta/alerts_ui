defmodule AlertsUIWeb.FormComponents.SuccessfulSubmission do
  @moduledoc """
    Live Component for successful alert creation
  """
  use AlertsUIWeb, :live_component
  alias AlertsUI.Alerts

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    alert_id = Map.get(assigns, :alert_id, nil)
    assigns = if alert_id do
      Map.put(assigns, :alert, Alerts.get_by_alert_id(alert_id))
    else Map.put(assigns, :alert, "")
    end
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("ok", _params, socket) do
    {:noreply, redirect(socket, to: "/alerts/new")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class={unless @progress.name == "success", do: "hidden", else: "min-w-full"}
      id="success_view"
    >
      Alert created successfully
      <.button
        phx-click="ok"
        phx-target={@myself}
        class="btn btn-outline basis-8 self-center px-8"
        id="success_button"
      >
        ok!
      </.button>
    <pre :if={@show_created_alert}>
      test
    </pre>
    </div>
    """
  end
end
