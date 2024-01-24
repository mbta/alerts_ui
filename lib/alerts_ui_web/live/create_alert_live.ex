defmodule AlertsUIWeb.Step do
  @moduledoc "Describe a step in the multi-step form and where it can go."
  defstruct [:name, :prev, :next]
end

defmodule AlertsUIWeb.CreateAlertLive do
  use AlertsUIWeb, :live_view
  alias AlertsUIWeb.Step
  alias AlertsUIWeb.FormComponents.{AlertDetails, RouteTypeAndEffect, SuccessfulSubmission}

  @steps [
    %Step{name: "route_type_and_effect", prev: nil, next: "details"},
    %Step{name: "details", prev: "effect", next: "success"},
    %Step{name: "success", prev: "details", next: nil}
  ]

  @impl true
  def mount(_params, _session, socket) do
    first_step = List.first(@steps)
    socket = socket |> assign([{:progress, first_step}, {:alert_data, %{}}])
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:step_completed, details}, socket) do
    assigns = %{
      progress: next_step(socket.assigns.progress),
      alert_data: Map.merge(socket.assigns.alert_data, details |> Map.from_struct())
    }

    {:noreply, assign(socket, assigns)}
  end

  defp next_step(current_step) do
    Enum.find(@steps, fn step ->
      step.name == current_step.next
    end)
  end
end
