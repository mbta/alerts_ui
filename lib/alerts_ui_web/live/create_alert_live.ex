defmodule AlertsUIWeb.Step do
  @moduledoc "Describe a step in the multi-step form and where it can go."

  @doc """
  Returns list of atoms allowed in alert lifecycle field of alert

  ## Examples
      iex> %AlertsUIWeb.Step{name: "example", previous: "cool", next: "bean", label: "hi"}
      %AlertsUIWeb.Step{name: "example", previous: "cool", next: "bean", label: "hi"}
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
  use AlertsUIWeb, :live_view

  alias AlertsUI.AlertBuilder
  alias AlertsUI.Alerts
  alias AlertsUI.Models.Alert
  alias AlertsUI.Routes

  alias AlertsUIWeb.FormComponents.{
    AccessAffectedService,
    AffectedService,
    AlertDetails,
    Delivery,
    NotificationPeriod,
    RiderReminders,
    RouteTypeAndEffect,
    StopRouteAffectedService,
    Submit,
    SuccessfulSubmission,
    SystemwideAffectedService,
    Timeline,
    TimeRange
  }

  alias AlertsUIWeb.FormComponents.Helpers.{
    AlertData,
    EffectsForRouteTypes,
    ErrorFormatter,
    GreenLine,
    ServiceEffectCombinations
  }

  alias AlertsUIWeb.Step
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

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
  @spec mount(
          map(),
          any(),
          atom()
          | %{
              :assigns => atom() | %{:live_action => any(), optional(any()) => any()},
              optional(any()) => any()
            }
        ) :: {:ok, any()}
  def mount(params, _session, socket) do
    alert_id = Map.get(params, "alert_id")

    default_form_data =
      %{
        route_type: nil,
        effect_name: nil,
        route_ids: nil,
        trip_ids: nil,
        stop_ids: nil,
        direction: "",
        combination: nil,
        facility_id: nil,
        header_text: nil,
        description_text: nil,
        cause_detail: nil,
        url: nil,
        image_url: nil,
        image_alternative_text: nil,
        severity: nil,
        banner_text: nil,
        view_banner: nil,
        banner_sync_toggle: nil,
        reminder_times: [],
        notification_period_start: nil,
        notification_specifier: :same_as_effect_period,
        alert_data: %{
          active_period_end_specifier: :later_today,
          active_period_start: nil,
          active_period_end: nil,
          alert_timing: :"one-time",
          active_period_start_date: nil,
          active_period_start_time: nil,
          active_period_start_specifier: :now,
          recurrence_days: [],
          active_period_end_time: nil,
          active_period_end_date: nil,
          active_period_start_time_specifier: :start_of_service,
          active_period_end_time_specifier: :end_of_service
        }
      }
      |> Map.put(:selected_trips, nil)

    default_form_data =
      if is_nil(alert_id) do
        default_form_data
      else
        edit_data = AlertData.build_alert_data(alert_id) |> Map.from_struct()
        Map.merge(default_form_data, edit_data)
      end

    [first_step, second_step | _] = @steps
    editing = socket.assigns.live_action == :edit

    socket =
      socket
      |> assign(default_form_data)
      |> assign(%{
        page_title: "Create an Alert",
        progress: if(editing, do: second_step, else: first_step),
        steps: @steps,
        combination: default_form_data.combination,
        alert_uuid: nil,
        alert_id: alert_id,
        errors: %{},
        submitted: false,
        editing: editing
      })

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

  def get_routes(route_types) do
    route_types
    |> RoutesRepo.by_type()
    |> maybe_include_virtual_green_line()
  end

  def get_schedules(nil, _), do: []

  def get_schedules(route_ids, direction) do
    directions = directions_from_selection(direction)
    opts = direction_option([stop_sequences: [:first, :last]], directions)

    route_ids |> SchedulesRepo.by_route_ids(opts) |> filter_out_old_trips
  end

  def get_stops(nil, _direction), do: []

  def get_stops(["Green"] = route_ids, direction) do
    route_ids = Routes.expanding_green_line(route_ids) |> Enum.reverse()

    stops =
      route_ids
      |> Enum.map(fn route_id ->
        stops = StopsRepo.by_route(route_id, 0)
        {route_id, stops}
      end)
      |> GreenLine.put_stops_in_order()

    if direction == "1" do
      Enum.reverse(stops)
    else
      stops
    end
  end

  def get_stops(route_ids, direction) do
    direction
    |> directions_from_selection()
    |> available_stops(route_ids)
  end

  def get_stops_by_route_type(route_type) do
    StopsRepo.by_route_type(route_type) |> Enum.sort_by(& &1.name)
  end

  def get_routes_by_stop(nil, _), do: []

  def get_routes_by_stop(stop_ids, route_type) do
    if route_type == 3 do
      Enum.flat_map(stop_ids, &RoutesRepo.by_stop(&1, type: 3))
    else
      Enum.flat_map(stop_ids, &RoutesRepo.by_stop(&1))
    end
    |> maybe_include_virtual_green_line()
  end

  def get_facilities(facility_types) do
    facilties_from_api = FacilitiesRepo.get_by_type(facility_types, include: "stop")

    available_facilities =
      facilties_from_api
      # remove facilities that we don't control
      |> Enum.filter(&(!is_nil(&1.stop)))
      |> Enum.uniq()
      |> Enum.sort_by(& &1.long_name)

    # gather list of stops associated with facilities, along with array of facility types the stop services
    available_stops =
      available_facilities
      |> Enum.reduce(%{}, fn facility, acc ->
        stop = facility.stop

        if is_nil(stop) do
          acc
        else
          Map.update(
            acc,
            stop.id,
            stop |> Map.put(:facility_types, [facility.type]),
            &Map.put(&1, :facility_types, [facility.type | &1.facility_types] |> Enum.uniq())
          )
        end
      end)
      |> Map.values()
      |> Enum.sort_by(& &1.name)

    %{stops: available_stops, facilities: available_facilities}
  end

  def handle_info({:selected_trips, selected_trips}, socket) do
    {:noreply, assign(socket, selected_trips: selected_trips)}
  end

  def handle_info(:save_as_draft, socket) do
    socket.assigns
    |> Map.put(:draft, true)
    |> AlertBuilder.build_alert(Map.get(socket.assigns, :combination))
    |> Alerts.create_draft_alert()
    |> case do
      {:ok, _result} ->
        socket = put_flash(socket, :info, "Draft Saved Successfully")
        {:noreply, redirect(socket, to: "/alerts/new")}

      {:error, result} ->
        errors =
          result
          |> Alerts.parse_changeset_errors()
          |> format_errors(socket.assigns.combination)

        socket = display_errors(socket, errors)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:add_errors, errors, name}, socket) do
    updated_errors = socket.assigns.errors |> Map.put(name, errors)
    {:noreply, assign(socket, errors: updated_errors)}
  end

  @impl true
  def handle_info({:section_completed, changeset}, socket) do
    assigns =
      %{
        alert_data: Map.merge(socket.assigns.alert_data, changeset |> Map.from_struct())
      }

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_info({:on_form_section_change, changes}, socket) do
    {:noreply, assign(socket, Map.from_struct(changes))}
  end

  @impl true
  def handle_info({:step_completed, changes}, socket) do
    socket = assign(socket, Map.from_struct(changes))
    route_type = Map.get(socket.assigns, :route_type)
    effect_name = Map.get(socket.assigns, :effect_name)

    combination =
      if is_nil(route_type) and
           effect_name in EffectsForRouteTypes.list_effects(:access) do
        :ACCESS
      else
        ServiceEffectCombinations.get_combination(route_type, effect_name)
      end

    socket =
      assign(socket, %{
        progress: get_step_by_name(socket.assigns.progress.next),
        combination: combination,
        errors: %{},
        selected_trips: nil,
        route_ids: [],
        stop_ids: [],
        trip_ids: [],
        direction: ""
      })

    {:noreply, socket}
  end

  def handle_info(:create_alert, socket) do
    errors = Map.values(socket.assigns.errors) |> List.flatten()

    socket =
      if Enum.empty?(errors) do
        create_alert(socket)
      else
        formatted_errors =
          errors
          |> Enum.filter(fn {title, {_, _}} ->
            title not in [:active_period_start_date, :active_period_end_date]
          end)
          |> Enum.map(fn {_title, {message, _error}} -> "#{message}" end)
          |> Enum.uniq()
          |> Enum.join(";")

        display_errors(socket, formatted_errors)
      end

    {:noreply, socket}
  end

  defp create_alert(socket) do
    alert_map =
      socket.assigns
      |> AlertBuilder.build_alert(socket.assigns.combination)

    existing_alert =
      if is_nil(socket.assigns.alert_id) do
        %Alert{}
      else
        Alerts.get_by_alert_id(socket.assigns.alert_id)
      end

    alert_map
    |> Alerts.create_or_update_alert(existing_alert)
    |> case do
      {:ok, alert} ->
        assigns = %{
          progress: get_step_by_name(socket.assigns.progress.next),
          alert_uuid: alert.id
        }

        assign(socket, assigns)

      {:error, result} ->
        errors =
          result
          |> Alerts.parse_changeset_errors()
          |> format_errors(socket.assigns.combination)

        display_errors(socket, errors)
    end
  end

  defp display_errors(socket, errors) do
    [
      {choose_affected_service_component(socket.assigns.combination), "affected_service"},
      {TimeRange, "time_range"},
      {AlertDetails, "alert_details"},
      {Delivery, "delivery"}
    ]
    |> Enum.each(fn {module_name, id} -> send_update(module_name, id: id, submitted: true) end)

    socket
    |> clear_flash
    |> push_event("scroll_to_top", %{})
    |> put_flash(:error, errors)
  end

  @spec directions_from_selection(String.t() | nil) :: [Trip.direction_id_t()]
  # Both directions
  defp directions_from_selection("0"), do: [0]
  defp directions_from_selection("1"), do: [1]
  defp directions_from_selection(_), do: [0, 1]

  @spec direction_option(keyword(), [Trip.direction_id_t()]) :: keyword()
  defp direction_option(opts, [single_direction_id | []]),
    do: put_in(opts[:direction_id], single_direction_id)

  defp direction_option(opts, _both_directions), do: opts

  defp format_errors(errors, combination) do
    errors
    |> ErrorFormatter.parse_field_errors(combination)
    |> Enum.uniq()
    |> Enum.map_join("; ", fn {_title, {message, _error}} -> "#{message}" end)
  end

  defp get_step_by_name(name) do
    Enum.find(@steps, &(&1.name == name))
  end

  @spec maybe_include_virtual_green_line([Route.t()]) :: [Route.t()]
  defp maybe_include_virtual_green_line(routes) do
    if Enum.any?(routes, &green_line_route?/1) do
      [RoutesRepo.green_line() | routes]
    else
      routes
    end
  end

  @spec green_line_route?(Route.t()) :: boolean()
  def green_line_route?(%Route{id: "Green"}), do: true
  def green_line_route?(%Route{id: "Green-B"}), do: true
  def green_line_route?(%Route{id: "Green-C"}), do: true
  def green_line_route?(%Route{id: "Green-D"}), do: true
  def green_line_route?(%Route{id: "Green-E"}), do: true
  def green_line_route?(_), do: false

  @spec available_stops([integer()], [String.t()]) :: [Stop.t()]

  defp available_stops(direction_array, route_ids) do
    route_ids
    |> Enum.flat_map(fn route ->
      Enum.flat_map(direction_array, &StopsRepo.by_route(route, &1))
    end)
  end

  defp choose_affected_service_component(combination) do
    case combination do
      :SR -> StopRouteAffectedService
      :ACCESS -> AccessAffectedService
      nil -> SystemwideAffectedService
      _ -> AffectedService
    end
  end

  def filter_out_old_trips(schedules, current_time \\ DateTime.utc_now()) do
    schedules
    |> Enum.group_by(& &1.trip.id)
    |> Enum.reduce([], fn {_k, [first_stop, last_stop]}, acc ->
      one_hour_from_arrival = Timex.shift(last_stop.arrival_time, hours: 1)

      if DateTime.compare(one_hour_from_arrival, current_time) in [:gt, :eq] do
        # stash last stop name in note field- needed for ferry trip names
        stop = first_stop.stop |> Map.put(:note, last_stop.stop.name)

        schedule_to_return =
          first_stop |> Map.put(:stop, stop) |> Map.put(:arrival_time, last_stop.arrival_time)

        [schedule_to_return | acc]
      else
        acc
      end
    end)
    |> Enum.reverse()
    |> Enum.sort_by(& &1.departure_time, DateTime)
  end
end
