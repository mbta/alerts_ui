defmodule AlertsUIWeb.CreateAlertLive.Step do
  @moduledoc "Describes a timeline step in the multi-step form and what its previous and next steps are."

  @doc """
  Returns list of atoms allowed in alert lifecycle field of alert
  A value of nil for previous means this is the first step, and nil for
  next means it's the last step. Otherwise
  these values should reference the name strings of other steps.
  Label is the text that shows up in the timeline.
  """
  defstruct [:name, :previous, :next, :label]

  @type t :: %__MODULE__{
          name: String.t(),
          previous: String.t() | nil,
          next: String.t() | nil,
          label: String.t()
        }
end

defmodule AlertsUIWeb.CreateAlertLive do
  @moduledoc """
  A monolithic LiveView for creating and editing alerts.
  """

  use AlertsUIWeb, :live_view
  require Logger

  alias AlertsUI.AlertBuilder
  alias AlertsUI.Alerts
  alias AlertsUI.Configs.ModeEffect
  alias AlertsUI.Models.Alert
  alias AlertsUI.Models.InformedEntity
  alias Phoenix.LiveView

  alias AlertsUIWeb.CreateAlertLive.{
    AlertData,
    Title
  }

  alias AlertsUIWeb.CreateAlertLive.Helpers.{ModeEffectChange, NotificationToggle}

  alias AlertsUIWeb.CreateAlertLive.Slices.{
    AccessAffectedServiceSlice,
    AffectedServiceSlice,
    AlertDetailsSlice,
    DeliverySlice,
    NotificationPeriodSlice,
    ReminderTimesSlice,
    StopRouteServiceSlice,
    SubmitSlice,
    SystemwideServiceSlice,
    TimelineSlice,
    TimeRangeSlice,
    UrlSlice
  }

  alias AlertsUIWeb.CreateAlertLive.Step

  alias AlertsUIWeb.CreateAlertLive.Helpers.{
    EntityValidator,
    ErrorFormatter,
    ObsoleteEntities,
    ServiceEffectCombinations
  }

  alias AlertsUIWeb.{PredictionSuppressionWarningModal, TripEndWarningModal}

  alias Phoenix.LiveView

  alias AlertsUIWeb.CreateAlertLive.Helpers.AlertDataHelpers

  alias AlertsUIWeb.CreateAlertLive.Helpers.Path, as: PathHelper

  alias AlertsUI.DBContexts.Users
  alias MBTAV3API.Stops.Stop
  alias Phoenix.LiveView.AsyncResult

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
    %Step{name: "preview", previous: nil, next: nil, label: "Review and Submit"}
  ]

  @gtfs_modal_id "gtfs-warning-modal"
  @change_mode_effect_modal_id "change-mode-effect-modal"

  @impl true
  def mount(params, session, socket) do
    # initialize the alert data form or throw an exception trying
    form_type = form_type_from_socket(socket)
    form_title = form_title_from_type(form_type)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(AlertsUI.PubSub, "persisting")
    end

    socket =
      socket
      |> assign(%{
        page_title: "#{form_title} Alert",
        selections: %{},
        check_predictions: false,
        check_trip_end: false,
        form_type: form_type,
        obsolete_id_text: [],
        obsolete_ids: nil,
        submitting?: false,
        submitted?: false,
        stops_touched?: false,
        image_preview_size: nil,
        first_async_load: true,
        skate_detours: %AsyncResult{},
        used_detours: %AsyncResult{},
        steps: @steps,
        change_type: false,
        persisting_alert: false,
        modal_open_map: %{@gtfs_modal_id => false, @change_mode_effect_modal_id => false},
        gtfs_modal_id: @gtfs_modal_id,
        change_mode_effect_modal_id: @change_mode_effect_modal_id,
        # Used for keeping track of original state of an alert when changing its mode/effect type
        original_alert_form: nil
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
  def handle_params(
        %{"review" => "true"} = params,
        _url,
        %{assigns: %{submitted?: false}} = socket
      ) do
    # handles the case where someone hits reload on the review modal
    {:noreply, sync_socket(socket, Map.drop(params, ["review"]))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, sync_socket(socket, params)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    # accept changes to form params
    {:noreply, sync_socket(socket, params)}
  end

  def handle_event("recover_form", params, socket) do
    # fires if the socket disconnects and reconnects
    # resync the socket with the current form data and no target
    params = Map.drop(params, ["_target"])
    {:noreply, sync_socket(socket, params)}
  end

  @impl true
  def handle_event("stop_selector_blur", _params, socket) do
    {:noreply, socket |> assign(:stops_touched?, true) |> sync_socket(%{})}
  end

  @impl true
  def handle_event(
        "push_route_type",
        params,
        %{assigns: %{change_type: true}} = socket
      ) do
    route_type = Map.get(params, "value")

    # if we switch modes, we should clear the effect, except if we are going back to the originally selected mode
    original_route_type = socket.assigns.form[:route_type].value
    original_effect_name = socket.assigns.form[:effect_name].value
    mode_name = InformedEntity.route_code_mapping(original_route_type) |> Atom.to_string()
    draft_effect = if route_type === mode_name, do: original_effect_name, else: nil

    {:noreply, socket |> assign(%{path_route_type: route_type, path_effect_name: draft_effect})}
  end

  @impl true
  def handle_event("push_route_type", params, socket) do
    route_type = Map.get(params, "value")
    path = PathHelper.path_with_route_type(socket.assigns, route_type)

    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("move_progress", %{"value" => "route_type_and_effect"}, socket) do
    socket =
      socket
      |> assign(%{
        progress: get_step_by_name("route_type_and_effect"),
        path_route_type: Atom.to_string(PathHelper.path_route_type_from_socket(socket)),
        path_effect_name: PathHelper.path_effect_name_from_socket(socket),
        selections: %{},
        change_type: true
      })
      |> push_patch(to: PathHelper.path(socket.assigns))

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "move_progress",
        %{"value" => "details"},
        %{assigns: %{change_type: true}} = socket
      ) do
    # The case of moving from form page 1 to form page 2 via the "Alert Details" timeline button
    socket =
      socket
      |> assign(%{progress: get_step_by_name("details"), change_type: false})
      |> sync_socket(%{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("move_progress", %{"value" => name}, socket) do
    {:noreply, assign(socket, :progress, get_step_by_name(name))}
  end

  @impl true
  def handle_event(
        "push_effect_name",
        params,
        %{assigns: %{change_type: true}} = socket
      ) do
    effect_name = Map.get(params, "value")
    next_route_type = InformedEntity.route_type_mapping(socket.assigns.path_route_type)
    create? = socket.assigns.form_type === :creating
    edit? = socket.assigns.form_type === :editing

    # On edit/duplicate, we always compare to the saved form
    # On create, we compare to the last form the user edited
    form_to_compare =
      if create?,
        do: ModeEffectChange.condensed_form(socket.assigns.form),
        else: socket.assigns.original_alert_form

    %{new: form_updates, replaced: replaced_values} =
      ModeEffectChange.new_form_values(form_to_compare, next_route_type, effect_name)

    notification_toggle =
      if edit?,
        do: true,
        else:
          NotificationToggle.get_notification_toggle_default(
            %{notification_toggle: nil, route_type: next_route_type},
            effect_name,
            socket.assigns.form_type
          )

    updated_source =
      change(
        form_to_compare.source,
        Map.merge(
          %{
            route_type: next_route_type,
            effect_name: effect_name,
            combination: AlertDataHelpers.combination_for(next_route_type, effect_name),
            # We want to initialize with the default for the NEW mode/effect
            notification_toggle: notification_toggle
          },
          form_updates
        )
      )
      |> Map.put(:errors, [])

    socket =
      socket
      |> assign(%{
        draft_form: Phoenix.Component.to_form(updated_source),
        path_effect_name: effect_name,
        submitted?: false,
        first_async_load: true
      })

    # If there are no replaced values, go to form page 2.
    # Otherwise, show the warning modal.
    socket =
      if Enum.empty?(replaced_values) do
        socket
        |> assign(%{
          form: socket.assigns.draft_form,
          progress: get_step_by_name(socket.assigns.progress.next),
          change_type: false
        })
        |> sync_socket(%{})
      else
        send(self(), {:changing_mode_effect, replaced_values})
        socket
      end

    {:noreply, socket}
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

  @impl true
  def handle_event("review", _params, socket) do
    # starts review process
    # shows error flash if errors
    # otherwise shows warning modals
    alert_data = Map.merge(socket.assigns.form.source.data, socket.assigns.form.source.changes)

    autotext_data = AlertDetailsSlice.autotext_map(alert_data, socket.assigns)

    socket =
      socket
      |> assign(%{
        submitting?: true,
        submitted?: true,
        check_predictions: false,
        check_trip_end: false
      })
      |> sync_socket(%{"alert_data" => autotext_data})

    {:noreply, socket}
  end

  @impl true
  def handle_event("open_review_modal", _params, %{assigns: assigns} = socket) do
    # actually opens the review modal
    effect_name = assigns.form[:effect_name].value

    path_route_type =
      assigns[:path_route_type] || PathHelper.path_route_type_from_socket(socket)

    path =
      PathHelper.path_with_route_type_and_effect_name(
        %{assigns | path_route_type: path_route_type},
        effect_name
      ) <> "?review=true"

    socket =
      socket
      |> assign(
        check_predictions: false,
        check_trip_end: false
      )
      |> push_patch(to: path)

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
  def handle_event(
        "check_for_trip_warnings",
        _params,
        %LiveView.Socket{assigns: %{} = assigns} = socket
      ) do
    alert_data =
      socket.assigns.form.data

    trip_arrival_time =
      TimeRangeSlice.get_trip_arrival_time_for_validate(
        alert_data.trip_ids,
        socket.assigns.selections
      )

    show_trip_end_warning? =
      TripEndWarningModal.show_warning?(
        trip_arrival_time,
        alert_data.active_period_start,
        alert_data.modal_date
      )

    if show_trip_end_warning? do
      {:noreply,
       assign(socket, %{
         check_predictions: false,
         check_trip_end: true
       })}
    else
      effect_name = assigns.form[:effect_name].value

      path_route_type =
        assigns[:path_route_type] || PathHelper.path_route_type_from_socket(socket)

      path =
        PathHelper.path_with_route_type_and_effect_name(
          %{assigns | path_route_type: path_route_type},
          effect_name
        ) <> "?review=true"

      {:noreply,
       socket
       |> assign(:submitting?, false)
       |> push_patch(to: path)}
    end
  end

  @impl true
  def handle_event("dismiss_prediction_warning", _params, socket) do
    {:noreply, socket |> assign(check_predictions: false)}
  end

  @impl true
  def handle_event("dismiss_trip_end_warning", _params, socket) do
    {:noreply, socket |> assign(check_trip_end: false)}
  end

  @impl true
  def handle_event("cancel_review", _params, socket) do
    effect_name = socket.assigns.path_effect_name
    path = PathHelper.path_with_route_type_and_effect_name(socket.assigns, effect_name)

    socket =
      assign(socket,
        check_predictions: false,
        check_trip_end: false
      )

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
    {:noreply, socket |> set_modal_open(@gtfs_modal_id, false)}
  end

  @impl true
  def handle_event("cancelled_gtfs_modal", _params, socket) do
    {:noreply,
     socket
     |> set_modal_open(@gtfs_modal_id, false)
     |> redirect(to: return_to(socket.assigns.return_to || "/"))}
  end

  @impl true
  def handle_event("accepted_change_mode_effect_modal", _params, socket) do
    {:noreply,
     socket
     |> set_modal_open(@change_mode_effect_modal_id, false)
     |> assign(%{
       form: socket.assigns.draft_form,
       progress: get_step_by_name(socket.assigns.progress.next),
       change_type: false
     })
     |> sync_socket(%{})}
  end

  @impl true
  def handle_event("cancelled_change_mode_effect_modal", _params, socket) do
    original_form = socket.assigns.original_alert_form

    {:noreply,
     socket
     |> set_modal_open(@change_mode_effect_modal_id, false)
     # Revert back to the originally chosen route and effect types
     |> assign(%{
       path_route_type:
         Atom.to_string(
           PathHelper.path_route_type(original_form[:route_type], original_form[:effect_name])
         ),
       path_effect_name: original_form[:effect_name]
     })}
  end

  defp set_modal_open(socket, id, state) do
    new_modal_state =
      Map.merge(socket.assigns.modal_open_map, %{id => state})

    socket |> assign(modal_open_map: new_modal_state)
  end

  def check_predictions(params, socket) do
    # form data with properly capitalized effect name
    alert_data =
      socket.assigns.form.data
      |> Map.update!(:effect_name, &PathHelper.effect_from_url_name/1)

    show_prediction_warning? = PredictionSuppressionWarningModal.show_warning?(alert_data)

    if show_prediction_warning? do
      assign(socket, %{
        check_predictions: true
      })
    else
      {_, socket} = handle_event("check_for_trip_warnings", params, socket)
      socket
    end
  end

  @impl true
  def handle_async(:fetch_selections, {:ok, new_selections}, socket) do
    socket = handle_obsolete_ids(socket, new_selections)

    first_async_load =
      if socket.assigns.first_async_load, do: false, else: socket.assigns.first_async_load

    pending_route_ids = Map.get(new_selections, :pending_auto_select_route_ids)

    socket = translate_stop_names_and_ids(socket, new_selections)
    socket = scroll_stop_list(socket, socket.assigns.first_async_load)

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

  def scroll_stop_list(%{assigns: %{form: form}} = socket, true) do
    # scrolls to pre-selected stop if editing
    stop_name_and_id = List.first(form.data.stop_names_and_ids || [])

    if stop_name_and_id do
      push_event(socket, "scrollToSelection", %{
        select_name: "stop_names_and_ids",
        type: "stop",
        value: stop_name_and_id
      })
    else
      socket
    end
  end

  def scroll_stop_list(socket, _), do: socket

  # In the case of converting an alert with stops to SR, we need to adjust the `stop_names_and_ids` because
  # the names will change depending on direction. For example, in a Bus Delay, we would have both
  # South Station (inbound) and South Station (outbound). But in SR, we would only have South Station.
  # This uses `stop_ids` as the source of truth, and then adjusts `stop_names_and_ids` to match fetched stops
  defp translate_stop_names_and_ids(socket, %{available_stops: available_stops}) do
    form = socket.assigns.form
    combination = form[:combination].value

    if combination === :SR do
      stop_ids = form[:stop_ids].value

      selected_stops =
        Enum.filter(available_stops, fn stop -> stop.id in stop_ids end)
        |> Enum.map(fn %Stop{id: id, name: name} -> "#{name}|#{id}" end)

      updated_source =
        change(
          form.source,
          %{stop_names_and_ids: selected_stops}
        )

      socket
      |> assign(%{
        form: Phoenix.Component.to_form(updated_source)
      })
    else
      socket
    end
  end

  defp translate_stop_names_and_ids(socket, _), do: socket

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
      |> assign(
        obsolete_id_text: obsolete_id_text,
        obsolete_ids: obsolete_ids_map
      )
      |> set_modal_open(@gtfs_modal_id, true)
      |> push_event("show-modal", %{id: @gtfs_modal_id})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:adjust_optgroups, %{data: optgroups_to_adjust}}, socket) do
    socket = push_event(socket, "adjustOptgroupColor", %{data: optgroups_to_adjust})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:changing_mode_effect, _replaced_values}, socket) do
    socket =
      socket
      |> set_modal_open(@change_mode_effect_modal_id, true)
      |> push_event("show-modal", %{id: @change_mode_effect_modal_id})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:persisting_start}, socket) do
    {:noreply, assign(socket, persisting_alert: true)}
  end

  @impl true
  def handle_info({:persisting_end}, socket) do
    {:noreply, assign(socket, persisting_alert: false)}
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
    socket =
      case {Map.get(params, "alert_id"), socket.assigns.live_action} do
        {nil, :new} ->
          create_new_alert(socket, params)

        {alert_id, :new} ->
          redirect(socket, ~p"/alerts/edit/#{alert_id}")

        {alert_id, :edit} ->
          edit_existing_alert(socket, params, alert_id)

        {alert_id, :duplicate} ->
          duplicate_existing_alert(socket, params, alert_id)

        {_alert_id, action} ->
          raise %ArgumentError{message: "no such action #{action}"}
      end

    if Map.get(socket.assigns, :form) do
      socket |> assign(:original_alert_form, ModeEffectChange.condensed_form(socket.assigns.form))
    else
      socket
    end
  end

  defp create_new_alert(
         %{assigns: %{} = _assigns} = socket,
         %{"effect_name" => effect_name, "route_type" => route_type} = params
       ) do
    effect_name = AlertDataHelpers.humanize_effect_name(route_type, effect_name)

    if effect_name === nil do
      redirect(socket, to: ~p"/alerts/new")
    else
      # create a new alert
      {_, socket} = AlertData.init(socket, params, :new)

      socket
    end
  end

  defp create_new_alert(
         %{assigns: %{} = _assigns} = socket,
         %{"route_type" => route_type} = params
       ) do
    mode_effect = ModeEffect.mode_effects_by_route_type_name(String.to_existing_atom(route_type))

    if mode_effect === nil do
      redirect(socket, to: ~p"/alerts/new")
    else
      {_, socket} = AlertData.init(socket, params, :new)
      socket
    end
  rescue
    # This would happen if we are given an arbitrary route_type
    ArgumentError ->
      redirect(socket, to: ~p"/alerts/new")
  end

  defp create_new_alert(
         %{assigns: %{} = _assigns} = socket,
         params
       ) do
    # create a new alert
    {_, socket} = AlertData.init(socket, params, :new)

    socket
  end

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
  def sync_socket(%LiveView.Socket{assigns: %{} = assigns} = socket, params) do
    case AlertData.sync(assigns.form.source, socket, params) do
      {:ok, socket} ->
        if assigns.submitting? do
          socket = assign(socket, :submitting?, false)
          check_predictions(params, socket)
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

  def rendered_service_slice(assigns) do
    service_slice(assigns).render(assigns)
  end

  def service_slice(combination) when is_atom(combination) do
    service_slice_by_combination(combination)
  end

  def service_slice(assigns) do
    form = Map.get(assigns, :form)
    service_slice_by_combination(form[:combination].value)
  end

  @spec service_slice_by_combination(any()) ::
          AlertsUIWeb.CreateAlertLive.Slices.AccessAffectedServiceSlice
          | AlertsUIWeb.CreateAlertLive.Slices.AffectedServiceSlice
          | AlertsUIWeb.CreateAlertLive.Slices.StopRouteServiceSlice
          | AlertsUIWeb.CreateAlertLive.Slices.SystemwideServiceSlice
  def service_slice_by_combination(:SR), do: StopRouteServiceSlice
  def service_slice_by_combination(:ACCESS), do: AccessAffectedServiceSlice
  def service_slice_by_combination(nil), do: SystemwideServiceSlice
  def service_slice_by_combination(_), do: AffectedServiceSlice

  defp strip_on_duplicate(alert), do: alert

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
    |> Enum.uniq_by(fn {_k, {message, _}} -> message end)
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
    send(self(), {:persisting_start})

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
      |> AlertDataHelpers.atomize_fields()
      |> AlertDataHelpers.strip_banner_text_unless_enabled()
      |> AlertDataHelpers.strip_recurrence_days_if_one_time()
      |> AlertBuilder.build_alert(alert_data.combination)

    existing_alert =
      if is_nil(socket.assigns.alert_id) || form_type == :duplicating do
        %Alert{}
      else
        Alerts.get_by_alert_id(socket.assigns.alert_id)
      end

    alert_params =
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
          send(self(), {:persisting_end})

          errors =
            changeset
            |> Alerts.parse_changeset_errors()
            |> ErrorFormatter.parse_field_errors(socket.assigns.form[:combination].value)

          Logger.error("Errors upon alert submission: #{format_errors(errors)}")
          display_errors(assign(socket, :submitting?, false), errors)
      end

    Phoenix.PubSub.broadcast(
      AlertsUI.PubSub,
      "alerts",
      {:alerts_updated}
    )

    alert_params
  end
end
