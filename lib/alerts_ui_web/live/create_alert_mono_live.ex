defmodule AlertsUIWeb.CreateAlertMonoLive do
  @moduledoc """
  A monolithic LiveView for creating and editing alerts.
  """

  use AlertsUIWeb, :live_view
  require Logger

  alias AlertsUI.AlertBuilder
  alias AlertsUI.Alerts
  alias AlertsUI.Models.Alert
  alias Phoenix.LiveView

  alias AlertsUIWeb.CreateAlertMonoLive.{
    AlertData,
    Title
  }

  alias AlertsUIWeb.CreateAlertMonoLive.Slices.{
    AccessAffectedServiceSlice,
    AffectedServiceSlice,
    AlertDetailsSlice,
    DeliverySlice,
    NotificationPeriodSlice,
    ReminderTimesSlice,
    StopRouteServiceSlice,
    SubmitSlice,
    TimelineSlice,
    TimeRangeSlice,
    UrlSlice
  }

  alias AlertsUIWeb.CreateAlertMonoLive.Step

  alias AlertsUIWeb.FormComponents.Helpers.{
    EntityValidator,
    ErrorFormatter,
    ObsoleteEntities,
    ServiceEffectCombinations
  }

  alias Phoenix.LiveView

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertData

  alias AlertsUIWeb.CreateAlertMonoLive.Helpers.Path, as: PathHelper

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
    form_type = form_type_from_socket(socket)
    form_title = form_title_from_type(form_type)

    socket =
      socket
      |> assign(%{
        page_title: "#{form_title} Alert",
        selections: %{},
        check_predictions: false,
        form_type: form_type,
        obsolete_id_text: [],
        obsolete_ids: nil,
        submitting?: false,
        submitted?: false,
        image_preview_size: nil,
        first_async_load: true
      })
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

  defp form_title_from_type(title) do
    case title do
      :editing -> "Edit"
      :duplicating -> "Duplicate"
      :creating -> "Create"
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
    path = PathHelper.path_with_route_type(socket.assigns, route_type)

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
      socket
      |> start_socket(%{})
      |> assign(%{
        form: Phoenix.Component.to_form(cleared_source),
        progress: get_step_by_name("route_type_and_effect"),
        path_route_type: nil,
        path_effect_name: nil,
        selections: nil
      })
      |> push_patch(to: PathHelper.path(socket.assigns))

    {:noreply, socket}
  end

  @impl true
  def handle_event("move_progress", %{"value" => name}, socket) do
    {:noreply, assign(socket, :progress, get_step_by_name(name))}
  end

  @impl true
  def handle_event("push_effect_name", params, socket) do
    effect_name = Map.get(params, "value")
    path = PathHelper.path_with_route_type_and_effect_name(socket.assigns, effect_name)

    socket =
      socket
      |> assign(:progress, get_step_by_name(socket.assigns.progress.next))
      |> push_navigate(to: path)

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_search_filter", %{"name" => name}, socket) do
    # i.e., "alert_data[the_field_we_want_to_clear]"
    search_filter_name =
      hd(Regex.run(~r/\[(.*?)\]/, name, capture: :all_but_first))

    params = %{
      "_target" => ["alert_data", search_filter_name],
      "alert_data" => %{search_filter_name => nil}
    }

    {:noreply, sync_socket(socket, params)}
  end

  @impl true
  def handle_event("accepted_routes_modal", _params, socket) do
    # no updates necessary here as the relevant values are already in the
    # form
    {:noreply, sync_socket(socket, %{})}
  end

  @impl true
  def handle_event("clear_filter", _params, %{assigns: %{selections: selections}} = socket) do
    case Map.get(selections, :on_filter_clear) do
      handler when is_function(handler) -> {:noreply, handler.(socket)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_filter", _params, socket) do
    {:noreply, socket}
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
      |> assign(:submitted?, true)
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
  def handle_event("save", _params, socket) do
    {:noreply, persist_valid_alert(socket)}
  end

  @impl true
  def handle_event("accept_filter", _params, %{assigns: %{selections: selections}} = socket) do
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
  def handle_event("cancel_filter", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("check_predictions", params, socket) do
    # form data with properly capitalized effect name
    alert_data =
      socket.assigns.form.data
      |> Map.put(:effect_name, PathHelper.effect_from_url_name(socket.assigns.path_effect_name))

    if AlertsUIWeb.PredictionSuppressionWarningModal.show_warning?(alert_data) do
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
    path = PathHelper.path_with_route_type_and_effect_name(socket.assigns, effect_name)
    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event(
        "image-preview-size",
        %{"id" => "size-of-image", "image_preview_size" => image_preview_size},
        socket
      ) do
    {:noreply, assign(socket, :image_preview_size, image_preview_size)}
  end

  @impl true
  def handle_event("accepted_gtfs_modal", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancelled_gtfs_modal", _params, socket) do
    {:noreply, socket |> redirect(to: return_to(socket.assigns.return_to || "/"))}
  end

  @impl true
  def handle_async(:fetch_selections, {:ok, new_selections}, socket) do
    socket = handle_obsolete_ids(socket, new_selections)

    first_async_load =
      if socket.assigns.first_async_load, do: false, else: socket.assigns.first_async_load

    pending_route_ids = Map.get(new_selections, :pending_auto_select_route_ids)

    # Always override route_ids — no guard for pre-existing selections; see design spec.
    socket =
      if is_nil(pending_route_ids) do
        assign(socket, %{selections: new_selections})
      else
        socket
        |> assign(:selections, %{new_selections | pending_auto_select_route_ids: nil})
        |> sync_socket(%{"alert_data" => %{"route_ids" => pending_route_ids}})
      end
      |> assign(first_async_load: first_async_load)

    {:noreply, socket}
  end

  @impl true
  def handle_async(_, {:exit, reason}, socket) do
    require Logger
    Logger.error("Selections load failed: #{inspect(reason)}")

    case socket.assigns[:selections] do
      %{loading: _} = sel -> {:noreply, assign(socket, :selections, %{sel | loading: false})}
      _ -> {:noreply, socket}
    end
  end

  defp handle_obsolete_ids(socket, new_selections) do
    form = socket.assigns.form

    required_fields =
      socket.assigns.form[:combination].value
      |> ServiceEffectCombinations.required_fields()
      |> Enum.reject(&(&1 == :direction))
      |> Enum.sort()

    mapping = %{
      route_ids: :available_routes,
      trip_ids: :available_schedules,
      stop_ids: :available_stops,
      facility_ids: :available_facilities
    }

    obsolete_ids =
      Enum.map(required_fields, fn field ->
        new_selections =
          new_selections |> Map.from_struct() |> filter_stops_from_facility_result()

        ids =
          (EntityValidator.get_obsolete_ids(
             form[field].value,
             new_selections[mapping[field]]
           ) || [])
          |> Enum.reject(&is_nil/1)

        {field, ids}
      end)
      |> Enum.into(%{})

    # socket.assigns.obsolete_ids is only nil on the first check, so this can't happen twice
    cond do
      obsolete_ids_found?(obsolete_ids) and is_nil(socket.assigns.obsolete_ids) ->
        form_data = Map.from_struct(form.data)

        ids_with_obsolete_entities_removed =
          ObsoleteEntities.all_obsolete_entities_removed(
            form_data,
            obsolete_ids,
            required_fields
          )

        original_selections =
          Map.take(form_data, [
            :original_route_selections,
            :original_trip_selections,
            :original_stop_selections,
            :original_facility_selections
          ])

        new_form_data =
          struct(AlertData, Map.merge(form_data, ids_with_obsolete_entities_removed))

        new_form_source = Map.put(form.source, :data, new_form_data)
        new_form = form |> Map.put(:data, new_form_data) |> Map.put(:source, new_form_source)

        # sending original selections so we can show the names in the modal
        send(self(), {:got_obsolete_ids, obsolete_ids, original_selections})

        assign(socket, %{obsolete_ids: obsolete_ids, form: new_form})
        |> sync_socket(%{"alert_data" => ids_with_obsolete_entities_removed})

      is_nil(socket.assigns.obsolete_ids) ->
        # sets obsolete ids to empty map so we don't go through this loop again.
        assign(socket, %{obsolete_ids: obsolete_ids})

      true ->
        socket
    end
  end

  defp obsolete_ids_found?(nil), do: false

  defp obsolete_ids_found?(obsolete_ids) do
    Enum.any?(obsolete_ids, fn {_k, v} -> !Enum.empty?(v) end)
  end

  @impl true
  def handle_info({:got_obsolete_ids, obsolete_ids_map, original_selections}, socket) do
    # builds a list of the text to go in the obsolete ids modal
    obsolete_id_text =
      obsolete_ids_map
      # for every field (route, stop, etc in the obsolete ids map)
      |> Enum.map(fn {field_name, obsolete_ids} ->
        # build name of corresponding "original selections" field
        name_part = field_name |> Atom.to_string() |> String.split("_") |> hd

        original_field =
          Map.get(
            original_selections,
            String.to_existing_atom("original_#{name_part}_selections")
          )

        # build map of original selected ids -> names
        original_names_map =
          (original_field || [])
          |> Enum.map(fn name_and_id ->
            [name, id] = String.split(name_and_id, "|")

            {id, if(name == "", do: id, else: name)}
          end)
          |> Enum.into(%{})

        # build text title
        title =
          field_name
          |> Atom.to_string()
          |> String.replace("_id", "")
          |> String.replace("ys", "ies")
          |> String.capitalize()

        # step through obsolete ids and gets names if available
        # the ID is used as a fallback
        names =
          Enum.map(obsolete_ids, fn obsolete_id ->
            Map.get(original_names_map, obsolete_id, obsolete_id) <> " [#{obsolete_id}]"
          end)

        {title, names}
      end)
      |> Enum.reject(fn {_title, names} -> Enum.empty?(names) end)

    socket =
      socket
      |> assign(obsolete_id_text: obsolete_id_text, obsolete_ids: obsolete_ids_map)
      |> push_event("show-gtfs-modal", %{id: "gtfs-warning-modal"})

    {:noreply, socket}
  end

  defp get_step_by_name(name) do
    Enum.find(@steps, &(&1.name == name))
  end

  defp filter_stops_from_facility_result(%{
         available_facilities: %{facilities: facilities, stops: _stops}
       }) do
    %{available_facilities: facilities}
  end

  defp filter_stops_from_facility_result(available_entities), do: available_entities

  @doc """
  Initialize a form. Called from `mount/3`.
  """
  # @spec start_socket(LiveView.Socket.t(), LiveView.unsigned_params()) :: LiveView.Socket.t()
  def start_socket(socket, params) do
    case {Map.get(params, "alert_id"), socket.assigns.live_action} do
      {nil, :new} ->
        create_new_alert(socket, params)

      {nil, action} when action in [:edit, :duplicate] ->
        raise %ArgumentError{message: "you need an alert id to #{action}"}

      {alert_id, :new} ->
        redirect(socket, ~p"/alerts/mono/edit/#{alert_id}")

      {alert_id, :edit} ->
        edit_existing_alert(socket, params, alert_id)

      {alert_id, :duplicate} ->
        duplicate_existing_alert(socket, params, alert_id)

      {_alert_id, action} ->
        raise %ArgumentError{message: "no such action #{action}"}
    end
  end

  defp create_new_alert(%{assigns: %{} = _assigns} = socket, params) do
    # create a new alert
    {_, socket} = AlertData.init(socket, params, :new)

    socket
  end

  defp create_new_alert(socket, _params), do: socket

  defp edit_existing_alert(socket, params, alert_id) do
    # edit an existing alert
    alert = Alerts.get_by_alert_id!(alert_id)

    socket
    |> AlertData.init(params, :edit, alert)
    |> case do
      {:ok, socket} -> socket
      {:error, socket} -> socket
    end
  end

  defp duplicate_existing_alert(socket, params, alert_id) do
    # duplicate an existing alert
    alert = Alerts.get_by_alert_id!(alert_id)

    socket
    |> AlertData.init(params, :duplicate, strip_on_duplicate(alert))
    |> case do
      {:ok, socket} -> socket
      {:error, socket} -> socket
    end
  end

  @doc """
  Accept incoming data. Called from `handle_params/3` and the `validate`
  event handler.
  """
  @spec sync_socket(LiveView.Socket.t(), map()) :: LiveView.Socket.t()
  def sync_socket(socket, params \\ %{})

  def sync_socket(%LiveView.Socket{assigns: %{} = assigns} = socket, params) do
    case AlertData.sync(assigns.form.source, socket, params) do
      {:ok, socket} ->
        if assigns.submitting? do
          effect_name = assigns.form[:effect_name].value

          path_route_type =
            assigns[:path_route_type] || PathHelper.path_route_type_from_socket(socket)

          path =
            PathHelper.path_with_route_type_and_effect_name(
              %{assigns | path_route_type: path_route_type},
              effect_name
            ) <> "?review=true"

          socket
          |> assign(:submitting?, false)
          |> push_patch(to: path)
        else
          socket
        end

      {:error, socket} ->
        if assigns.submitting? do
          socket
          |> assign(:submitting?, false)
          |> display_errors()
        else
          socket
        end
    end
  end

  def sync_socket(socket, _), do: socket

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

  defp display_errors(%{assigns: %{form: form}} = socket), do: display_errors(socket, form.errors)

  defp display_errors(socket, errors) do
    socket
    |> clear_flash
    |> push_event("scroll_to_top", %{})
    |> put_flash(:error, format_errors(errors))
    |> put_flash(:title, "Please fix the following errors:")
  end

  defp format_errors(errors) do
    errors
    |> Enum.uniq()
    |> Enum.map_join("; ", &format_error/1)
  end

  defp format_error({_title, {messages, _error}}) when is_list(messages),
    do:
      messages
      |> Enum.map(&format_message/1)
      |> Enum.uniq()
      |> Enum.join("; ")

  defp format_error({_title, {message, _error}}), do: format_message(message)

  defp format_message(%{} = messages),
    do: Enum.map(messages, fn {_key, value} -> format_message(value) end)

  defp format_message(message), do: "#{message}"

  def return_to(return_to_value) do
    uri = URI.parse(return_to_value)

    if uri.path == "/alerts" do
      "/alerts?#{uri.query}"
    else
      "/"
    end
  end

  def filter_out_old_trips(schedules, current_time \\ DateTime.utc_now()) do
    schedules
    |> Enum.group_by(& &1.trip.id)
    |> Enum.reduce([], fn {_k, [first_schedule, last_schedule]}, acc ->
      one_hour_from_arrival = Timex.shift(last_schedule.arrival_time, hours: 1)

      if DateTime.compare(one_hour_from_arrival, current_time) in [:gt, :eq] do
        [update_schedule(first_schedule, last_schedule) | acc]
      else
        acc
      end
    end)
    |> Enum.reverse()
    |> Enum.sort_by(& &1.departure_time, DateTime)
  end

  def update_schedule(first_schedule, last_schedule) do
    # updates first schedule with arrival time from last schedule, which is otherwise discarded
    # last stop name is needed for ferry trip names
    first_schedule
    |> Map.put(:time_of_last_trip_arrival, last_schedule.arrival_time)
    |> Map.put(:last_stop_name, last_schedule.stop.name)
  end

  defp flash_text(nil, alert_id, _form_type), do: "New alert ##{alert_id} created"

  defp flash_text(assigns_alert_id, alert_id, :duplicating),
    do: "Alert ##{alert_id} duplicated from ##{assigns_alert_id}"

  defp flash_text(_assigns_alert_id, alert_id, _form_type), do: "Alert ##{alert_id} updated"

  defp persist_valid_alert(socket) do
    alert_data = socket.assigns.form.source.data

    alert_data =
      alert_data
      |> Map.merge(%{
        effect_name: PathHelper.effect_from_url_name(alert_data.effect_name)
      })

    form_type = socket.assigns.form_type

    user = Users.create_or_update_user_from_session(socket.assigns.current_user)

    alert_params =
      alert_data
      |> AlertData.alert_data_v2_to_v1()
      |> AlertBuilder.build_alert(alert_data.combination)

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
        # Form validation should prevent us from getting here
        # but in case we do, we log an error and show
        # an error flash to the user
        errors =
          changeset
          |> Alerts.parse_changeset_errors()
          |> ErrorFormatter.parse_field_errors(socket.assigns.form[:combination].value)

        Logger.error("Errors upon alert submission: #{format_errors(errors)}")
        display_errors(assign(socket, :submitting?, false), errors)
    end
  end
end
