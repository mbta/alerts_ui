defmodule AlertsUIWeb.CreateAlertLive do
  use AlertsUIWeb, :live_view
  alias AlertsUI.Alerts
  alias AlertsUIWeb.FormComponents.{AlertDetails, SuccessfulSubmission}

  @impl true
  def mount(_params, _session, socket) do
    socket = socket |> assign([{:details_hidden, false}, {:success_hidden, true}])
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:details_created, details}, socket) do
    Alerts.create_alert(details |> Map.from_struct())
    |> case do
      {:ok, _result} ->
        {:noreply, assign(socket, [{:details_hidden, true}, {:success_hidden, false}])}

      {:error, result} ->
        errors =
          result
          |> Alerts.parse_changeset_errors()
          |> Enum.map_join(", ", fn {field, reason} -> "#{field}: #{reason}" end)

        socket = put_flash(socket, :error, errors)
        {:noreply, socket}
    end
  end
end
