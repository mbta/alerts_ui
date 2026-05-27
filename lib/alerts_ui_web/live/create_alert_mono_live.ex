defmodule AlertsUIWeb.CreateAlertMonoLive do
  @moduledoc """
  A monolithic LiveView for creating and editing alerts.
  """

  use AlertsUIWeb, :live_view

  alias Phoenix.LiveView
  alias AlertsUI.AlertBuilder
  alias AlertsUI.Alerts
  alias AlertsUI.Models.Alert

  alias AlertsUIWeb.FormComponents.Helpers.ErrorFormatter

  alias AlertsUIWeb.CreateAlertMonoLive.{
    AlertData,
    Title
  }

  alias AlertsUIWeb.CreateAlertMonoLive.Slices.{
    AccessAffectedServiceSlice,
    AffectedServiceSlice,
    AlertDetailsSlice,
    DeliverySlice,
    ReminderTimesSlice,
    SubmitSlice,
    StopRouteServiceSlice,
    TimelineSlice,
    TimeRangeSlice,
    NotificationPeriodSlice,
    UrlSlice
  }

  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.CreateAlertMonoLive.Step

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.{
    AlertData,
    Path,
    Selections
  }

  alias AlertsUI.DBContexts.Users

  import Ecto.Changeset, only: [change: 2]

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
  def mount(params, session, socket) do
    # initialize the alert data form or throw an exception trying
    socket =
      socket
      |> assign(:selections, %{})
      |> assign(:form_type, form_type_from_socket(socket))
      |> assign(:submitting?, false)
      |> assign_new(:return_to, fn -> session["return_to"] end)

    {:ok, start_socket(socket, params)}
  end

  defp form_type_from_socket(socket) do
    case socket.assigns.live_action do
      :edit -> :editing
      :duplicate -> :duplicating
      _ -> :creating
    end
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
  def handle_event("push_route_type", params, socket) do
    route_type = Map.get(params, "value")
    path = path_with_route_type(socket.assigns, route_type)

    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("move_progress", %{"value" => "route_type_and_effect"}, socket) do
    cleared_source =
      change(
        socket.assigns.form.source,
        %{
          route_type: nil,
          effect_name: nil,
          combination: nil,
          route_ids: nil,
          stop_ids: nil,
          trip_ids: nil,
          facility_ids: nil
        }
      )

    socket =
      assign(
        socket,
        %{
          form: Phoenix.Component.to_form(cleared_source),
          progress: get_step_by_name("route_type_and_effect"),
          path_route_type: nil,
          path_effect_name: nil,
          selections: nil
        }
      )

    {:noreply, push_patch(socket, to: path(socket.assigns))}
  end

  @impl true
  def handle_event("move_progress", %{"value" => name}, socket) do
    {:noreply, assign(socket, :progress, get_step_by_name(name))}
  end

  @impl true
  def handle_event("push_effect_name", params, socket) do
    effect_name = Map.get(params, "value")
    path = path_with_route_type_and_effect_name(socket.assigns, effect_name)

    socket =
      socket
      |> assign(:progress, get_step_by_name(socket.assigns.progress.next))
      |> push_patch(to: path)

    {:noreply, socket}
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

  # @impl true
  def handle_event("review", _params, socket) do
    # if valid:
    #   live navigate to `?review=true`, opening the modal
    # else:
    #   open error flash
    socket =
      socket
      |> assign(:submitting?, true)
      |> sync_socket()

    {:noreply, socket}
  end

  @impl true
  def handle_event("continue", _params, socket) do
    # dismiss the modal and return to the current state of the form
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply,
     push_navigate(socket,
       to: return_to(socket.assigns[:return_to] || "/alerts")
     )}
  end

  @impl true
  def handle_event("save", params, socket) do
    {:noreply, persist_valid_alert(socket)}
  end

  @impl true
  def handle_event("accept_filter", _params, %{assigns: %{selections: selections}} = socket) do
    selections =
      socket.assigns
      |> assign_unwrapped_selections()
      |> Map.get(:selections)

    case Map.get(selections, :on_filter_accept) do
      handler when is_function(handler) -> {:noreply, handler.(socket)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("accept_filter", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_filter", params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("check_predictions", params, socket) do
    if AlertsUIWeb.PredictionSuppressionWarningModal.show_warning?(socket.assigns) do
      {:noreply, socket |> assign(check_predictions: true)}
    else
      handle_event("review", params, socket)
    end
  end

  @impl true
  def handle_event("dismiss_prediction_warning", _params, socket) do
    {:noreply, socket |> assign(check_predictions: false)}
  end

  @impl true
  def handle_event("cancel_review", _params, socket) do
    effect_name = socket.assigns.path_effect_name
    path = path_with_route_type_and_effect_name(socket.assigns, effect_name)
    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event(
        "image-preview-size",
        %{"id" => "size-of-image", "image_preview_size" => image_preview_size},
        socket
      ) do
    {:noreply,
     assign(socket,
       alert_data: Map.put(socket.assigns.alert_data, :image_preview_size, image_preview_size)
     )}
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
        |> AlertData.init(params, :edit, alert)
        |> case do
          {:ok, socket} -> socket
          {:error, socket} -> socket
        end

      {alert_id, :duplicate} ->
        # duplicate an existing alert
        alert = Alerts.get_by_alert_id!(alert_id)

        socket
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
  def sync_socket(socket, params \\ %{}) do
    case AlertData.sync(socket.assigns.form.source, socket, params) do
      {:ok, socket} ->
        if socket.assigns.submitting? do
          effect_name = socket.assigns.form[:effect_name].value

          path_route_type =
            socket.assigns[:path_route_type] || path_route_type_from_socket(socket)

          path =
            path_with_route_type_and_effect_name(
              %{socket.assigns | path_route_type: path_route_type},
              effect_name
            ) <> "?review=true"

          socket
          |> assign(:submitting?, false)
          |> push_patch(to: path)
        else
          socket
        end

      {:error, socket} ->
        if socket.assigns.submitting? do
          # errors =
          #  result
          #  |> Alerts.parse_changeset_errors()
          #  |> format_errors(combination)

          socket
          |> assign(:submitting?, false)
          |> display_errors()
        else
          socket
        end
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

  defmodule ServiceSliceDispatcher do
    alias AlertsUIWeb.CreateAlertMonoLive.Slices.{
      AccessAffectedServiceSlice,
      AffectedServiceSlice,
      StopRouteServiceSlice,
      SystemwideServiceSlice
    }

    def affected_service_component(combination) do
      case combination do
        :SR -> StopRouteServiceSlice
        :ACCESS -> AccessAffectedServiceSlice
        nil -> SystemwideServiceSlice
        _ -> AffectedServiceSlice
      end
    end

    def render(assigns) do
      combination = assigns.form[:combination].value
      affected_service_component(combination).render(assigns)
    end
  end

  defp display_errors(%{assigns: %{form: form}} = socket) do
    formatted_errors =
      socket.assigns.form.errors
      |> Enum.map(fn {_title, {message, _error}} -> "#{message}" end)
      |> Enum.uniq()
      |> Enum.join(";")

    socket
    |> clear_flash
    |> push_event("scroll_to_top", %{})
    |> put_flash(:error, formatted_errors)
    |> put_flash(:title, "Please fix the following errors:")
  end

  defp display_errors(socket), do: socket

  defp format_errors(errors, combination) do
    errors
    |> ErrorFormatter.parse_field_errors(combination)
    |> Enum.uniq()
    |> Enum.map_join("; ", fn {_title, {message, _error}} -> "#{message}" end)
  end

  def return_to(return_to_value) do
    uri = URI.parse(return_to_value)

    if uri.path == "/alerts" do
      "/alerts?#{uri.query}"
    else
      "/"
    end
  end

  defp flash_text(nil, alert_id, _form_type), do: "New alert ##{alert_id} created"

  defp flash_text(assigns_alert_id, alert_id, :duplicating),
    do: "Alert ##{alert_id} duplicated from ##{assigns_alert_id}"

  defp flash_text(_assigns_alert_id, alert_id, _form_type), do: "Alert ##{alert_id} updated"

  defp persist_valid_alert(socket) do
    alert_data = socket.assigns.form.source.data
    form_type = socket.assigns.form_type

    user = Users.create_or_update_user_from_session(socket.assigns.current_user)

    alert_params =
      AlertBuilder.build_alert(
        alert_data,
        alert_data.combination
      )

    existing_alert =
      if is_nil(socket.assigns.alert_id) || form_type == :duplicating do
        %Alert{}
      else
        Alerts.get_by_alert_id(socket.assigns.alert_id)
      end

    alert_params
    |> Alerts.create_or_update_alert(user, existing_alert)
    |> case do
      {:ok, alert} ->
        alert_id =
          alert.id
          |> Alerts.get_by_id()
          |> Map.get(:alert_id)

        flash = flash_text(socket.assigns.alert_id, alert_id, form_type)

        socket
        |> put_flash(:info, flash)
        |> redirect(to: return_to(socket.assigns.return_to || "/"))

      {:error, changeset} ->
        raise "couldn't persist alert but it was supposed to be valid: #{inspect(changeset.errors)}"
    end
  end
end
