defmodule AlertsUIWeb.CreateAlertMonoLive do
  @moduledoc """
  A monolithic LiveView for creating and editing alerts.
  """

  use AlertsUIWeb, :live_view

  alias Phoenix.LiveView
  alias AlertsUI.Alerts

  alias AlertsUIWeb.CreateAlertMonoLive.{
    AlertData,
    Title
  }

  alias AlertsUIWeb.CreateAlertMonoLive.Slices.{
    AccessAffectedServiceSlice,
    AffectedServiceSlice,
    AlertDetailsSlice,
    DeliverySlice,
    StopRouteServiceSlice,
    SystemwideServiceSlice,
    ReminderTimesSlice,
    TimelineSlice,
    UrlSlice
  }
  alias AlertsUIWeb.CreateAlertMonoLive.Step

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.{
    AlertData,
    Path
  }

  import Ecto.Changeset, only: [change: 1]

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
      next: "preview",
      label: "Alert Details"
    },
    %Step{name: "preview", previous: nil, next: nil, label: "Preview and Submit"}
  ]

  @impl true
  def mount(params, _session, socket) do
    # initialize the alert data form or throw an exception trying
    {:ok, start_socket(socket, params)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    # accept changes to url params
    {:noreply, sync_socket(socket, params)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    # accept changes to form params
    {:noreply, sync_socket(socket, params)}
  end

  @impl true
  def handle_event("validate", other, socket) do
    # accept changes to form params
    {:noreply, socket}
  end

  @impl true
  def handle_event("push_route_type", params, socket) do
    route_type = Map.get(params, "value")
    path = path_with_route_type(socket.assigns, route_type)

    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("move_progress", %{"value" => "route_type_and_effect"}, socket) do
      IO.inspect("one")
    # {:noreply,
    #  assign(socket, progress: get_step_by_name("route_type_and_effect"), alert_data: %{})}
    {:noreply, socket}
  end

  @impl true
  def handle_event("move_progress", %{"value" => name}, socket) do
    IO.inspect(name, label: :two)
    # {:noreply, assign(socket, :progress, get_step_by_name(name))}
      {:noreply, socket}
  end

  @impl true
  def handle_event("push_effect_name", params, socket) do
    effect_name = Map.get(params, "value")
    path = path_with_route_type_and_effect_name(socket.assigns, effect_name)

    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("reset_search_filter", %{"name" => name}, socket) do
    # i.e., "alert_data[the_field_we_want_to_clear]"
    search_filter_name =
      hd(Regex.run(~r/\[(.*?)\]/, name, capture: :all_but_first))

    params = %{"alert_data" => %{search_filter_name => nil}}
    {:noreply, sync_socket(socket, params)}
  end

  @impl true
  def handle_event("accepted_routes_modal", _params, socket) do
    # no updates necessary here as the relevant values are already in the
    # form
    {:noreply, sync_socket(socket, %{})}
  end

  @impl true
  def handle_event("clear_filter", %{"filter-id" => filter_field}, socket) do
    params = %{"alert_data" => %{filter_field => nil}}
    {:noreply, sync_socket(socket, %{})}
  end

  @impl true
  def handle_event("review", _params, socket) do
    # if valid:
    #   live navigate to `?review=true`, opening the modal
    # else:
    #   open error flash
    {:noreply, socket}
  end

  @impl true
  def handle_event("continue", _params, socket) do
    # dismiss the modal and return to the current state of the form
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    # return to the alert list view, dismissing the form and modal
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit", _params, socket) do
    # commit the alert and redirect to the list view
    {:noreply, socket}
  end

    defp get_step_by_name(name) do
    Enum.find(@steps, &(&1.name == name))
  end

  @doc """
  Initialize a form. Called from `mount/3`.
  """
  @spec start_socket(LiveView.Socket.t(), LiveView.unsigned_params()) :: LiveView.Socket.t()
  def start_socket(socket, params) do
    case {Map.get(params, "alert_id"), socket.assigns.live_action} do
      {nil, :new} ->
        # create a new alert
        socket
        |> assign(:alert_id, nil)
        |> AlertData.init(params, :new)
        |> case do
          {:ok, socket} -> socket
          {:error, socket} -> socket
        end

      {nil, action} when action in [:edit, :duplicate] ->
        raise %ArgumentError{message: "you need an alert id to #{action}"}

      {alert_id, :new} ->
        redirect(socket, ~p"/alerts/mono/edit/#{alert_id}")

      {alert_id, :edit} ->
        # edit an existing alert
        alert = Alerts.get_by_alert_id!(alert_id)

        socket
        |> assign(:alert_id, alert.alert_id)
        |> AlertData.init(params, :edit, alert)
        |> case do
          {:ok, socket} -> socket
          {:error, socket} -> socket
        end

      {alert_id, :duplicate} ->
        # duplicate an existing alert
        alert = Alerts.get_by_alert_id!(alert_id)

        socket
        |> assign(:alert_id, alert.alert_id)
        |> AlertData.init(params, :duplicate, strip_on_duplicate(alert))
        |> case do
          {:ok, socket} -> socket
          {:error, socket} -> socket
        end

      {_alert_id, action} ->
        raise %ArgumentError{message: "no such action #{action}"}
    end
  end

  @doc """
  Accept incoming data. Called from `handle_params/3` and the `validate`
  event handler.
  """
  @spec sync_socket(LiveView.Socket.t(), LiveView.unsigned_params()) :: LiveView.Socket.t()
  def sync_socket(socket, params) do
    case AlertData.sync(socket.assigns.form.source, socket, params) do
      {:ok, socket} -> socket
      {:error, socket} -> socket
    end
  end

  def service_slice(assigns) do
    service_slice_by_combination(assigns.form[:combination].value).render(assigns)
  end

  defp strip_on_duplicate(alert), do: alert

  defp service_slice_by_combination(:SR), do: StopRouteServiceSlice
  defp service_slice_by_combination(:ACCESS), do: AccessServiceSlice
  defp service_slice_by_combination(nil), do: SystemwideServiceSlice
  defp service_slice_by_combination(_), do: AffectedServiceSlice
end
