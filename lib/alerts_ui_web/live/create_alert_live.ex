defmodule AlertsUIWeb.CreateAlertLive do
  use AlertsUIWeb, :live_view

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
  def handle_info({:details_created, _details}, socket) do
    {:noreply, assign(socket, [{:details_hidden, true}, {:success_hidden, false}])}
  end
end
