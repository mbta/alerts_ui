defmodule AlertsUIWeb.CreateAlertMonoLive do
  @moduledoc """
  A monolithic LiveView for creating and editing alerts.
  """

  require Logger

  use AlertsUIWeb, :live_view

  alias Phoenix.LiveView
  alias AlertsUI.Alerts
  alias AlertsUIWeb.CreateAlertMonoLive.{AlertData, Timeline}
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.{UrlSlice}

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.{
    AlertData,
    Path,
    Params
  }

  @impl true
  def mount(params, _session, socket) do
    # initialize the alert data form or throw an exception trying
    {:ok, start_socket(socket, with_atomized_keys(params))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    # accept changes to url params
    {:noreply, sync_socket(socket, with_atomized_keys(params))}
  end

  @impl true
  def handle_event("validate", params, socket) do
    # accept changes to form params
    {:noreply, sync_socket(socket, with_atomized_keys(params))}
  end

  @impl true
  def handle_event("push_route_type", params, socket) do
    route_type = Map.get(params, "value")

    path = path_with_route_type(
      socket.assigns.live_action,
      route_type,
      alert_data_from_form(socket.assigns.form, :alert_id)
    )

    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("push_effect_name", params, socket) do
    effect_name = Map.get(params, "value")

    path = path_with_route_type_and_effect_name(
      socket.assigns.live_action,
      alert_data_from_form(socket.assigns.form, :route_type),
      effect_name,
      alert_data_from_form(socket.assigns.form, :alert_id)
    )

    {:noreply, push_patch(socket, to: path)}
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

  @doc """
  Initialize a form. Called from `mount/3`.
  """
  @spec start_socket(LiveView.Socket.t(), LiveView.unsigned_params()) :: LiveView.Socket.t()
  def start_socket(socket, params) do
    case {Map.get(params, :alert_id), socket.assigns.live_action} do
      {nil, :new} ->
        # create a new alert
        form =
          params
          |> AlertData.init(:new)
          |> to_form()

        assign(socket, :form, form)

      {nil, action} when action in [:edit, :duplicate] ->
        raise %ArgumentError{message: "you need an alert id to #{action}"}

      {alert_id, :edit} ->
        # edit an existing alert
        alert = Alerts.get_by_alert_id!(alert_id)

        form =
          params
          |> AlertData.init(:edit, alert)
          |> to_form()

         assign(socket, :form, form)

      {alert_id, :duplicate} ->
        # duplicate an existing alert
        alert = Alerts.get_by_alert_id!(alert_id)

        form =
          params
          |> AlertData.init(:duplicate, strip_on_duplicate(alert))
          |> to_form()

        assign(socket, :form, form)

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
    form =
      socket.assigns.form.source
      |> AlertData.sync(params)
      |> to_form()

    assign(socket, :form, form)
  end

  defp strip_on_duplicate(alert), do: alert
end
