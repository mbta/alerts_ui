defmodule AlertsUIWeb.FormComponents.SuccessfulSubmission do
  @moduledoc """
    Live Component for successful alert creation
  """
  use AlertsUIWeb, :live_component
  alias AlertsUI.Alerts
  alias AlertsUI.FeedOutput.{CreateGtfsJson, CreateOutputAlert}

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    alert_uuid = Map.get(assigns, :alert_uuid, nil)

    alert = if is_nil(alert_uuid), do: %{}, else: alert_uuid |> Alerts.get_by_id()

    assigns =
      if !is_nil(alert_uuid) and assigns.show_created_alert == true do
        alert_json =
          alert
          |> CreateOutputAlert.build_alert()
          |> List.wrap()
          |> CreateGtfsJson.output_enhanced_json()

        Map.put(assigns, :alert_json, alert_json)
      else
        Map.put(assigns, :alert_json, nil)
      end
      |> Map.put(:alert_id, Map.get(alert, :alert_id))

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
      Alert #<%= @alert_id %> created successfully
      <.button
        phx-click="ok"
        phx-target={@myself}
        class="btn btn-outline basis-8 self-center px-8"
        id="success_button"
      >
        ok!
      </.button>
      <p :if={@show_created_alert}>
        Alert Created: <pre :if={@show_created_alert}>
        <%= @alert_json %>
      </pre>
      </p>
    </div>
    """
  end
end
