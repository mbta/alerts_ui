defmodule AlertsUIWeb.Step do
  @moduledoc "Describe a step in the multi-step form and where it can go."
  defstruct [:name, :previous, :next, :label]
end

defmodule AlertsUIWeb.CreateAlertLive do
  use AlertsUIWeb, :live_view
  alias AlertsUI.AlertBuilder
  alias AlertsUI.Alerts
  alias AlertsUIWeb.Step

  alias AlertsUIWeb.FormComponents.{
    AlertDetails,
    RouteTypeAndEffect,
    SuccessfulSubmission,
    Timeline
  }

  @steps [
    %Step{
      name: "route_type_and_effect",
      previous: nil,
      next: "details",
      label: "Select Alert Type"
    },
    %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    %Step{name: "success", previous: nil, next: nil, label: "Success"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    first_step = List.first(@steps)
    socket = socket |> assign(%{progress: first_step, alert_data: %{}, steps: @steps})
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("move_progress", %{"value" => name}, socket) do
    {:noreply, assign(socket, :progress, get_step_by_name(name))}
  end

  @impl true
  def handle_info({:step_completed, changeset}, socket) do
    assigns = %{
      progress: get_step_by_name(socket.assigns.progress.next),
      alert_data: Map.merge(socket.assigns.alert_data, changeset |> Map.from_struct())
    }

    {:noreply, assign(socket, assigns)}
  end

  def handle_info({:create_alert, changeset}, socket) do
    socket.assigns.alert_data
    |> Map.merge(changeset |> Map.from_struct())
    |> AlertBuilder.build_alert()
    |> Alerts.create_alert()
    |> case do
      {:ok, _result} ->
        assigns = %{
          progress: get_step_by_name(socket.assigns.progress.next),
          alert_data: nil
        }

        {:noreply, assign(socket, assigns)}

      {:error, result} ->
        errors =
          result
          |> Alerts.parse_changeset_errors()
          |> format_errors

        socket = put_flash(socket, :error, errors)
        {:noreply, socket}
    end
  end

  defp format_errors(errors) do
    Enum.map_join(errors, "; ", fn {title, values} ->
      values =
        values
        |> Enum.map_join(", ", &parse_inner_value(&1))

      "#{title}: #{values}"
    end)
  end

  defp parse_inner_value(value) do
    case is_map(value) do
      true -> format_errors(value)
      false -> value
    end
  end

  defp get_step_by_name(name) do
    Enum.find(@steps, &(&1.name == name))
  end

  defp compare_feed,
    do: Application.get_env(:alerts_ui, :compare_feed) == "true"
end
