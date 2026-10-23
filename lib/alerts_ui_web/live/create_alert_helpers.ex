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

defmodule AlertsUIWeb.CreateAlertHelpers do
  @moduledoc "API functions for Create Alert."
  use AlertsUIWeb, :live_view

  alias AlertsUI.AlertBuilder
  alias AlertsUI.Alerts
  alias AlertsUI.DBContexts.Users
  alias AlertsUI.Models.{ActivePeriod, Alert, Effect, EnhancedSchedule, InformedEntity}
  alias AlertsUI.Routes

  alias AlertsUIWeb.FormComponents.{
    AccessAffectedService,
    AffectedService,
    AlertDetails,
    Delivery,
    StopRouteAffectedService,
    Submit,
    SystemwideAffectedService,
    TimeRange
  }

  alias AlertsUIWeb.FormComponents.Helpers.{
    AlertData,
    EffectsForRouteTypes
  }

  alias AlertsUIWeb.CreateAlertLive.Helpers.{
    ErrorFormatter,
    GetKeyForModeEffect,
    GreenLine,
    SelectFormatter
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
      next: "preview",
      label: "Alert Details"
    },
    %Step{name: "preview", previous: nil, next: nil, label: "Review and Submit"}
  ]

  @impl true
  def mount(params, session, socket) do
    socket = socket |> assign_new(:return_to, fn -> session["return_to"] end)

    alert_id = Map.get(params, "alert_id")
    existing_alert_or_nil = alert_id && Alerts.get_by_alert_id(alert_id)

    form_type = form_type_from_socket(socket)
    form_title = form_title_from_type(form_type)
    alert_data = alert_data_on_mount(params, form_type, existing_alert_or_nil)

    {
      :ok,
      assign(socket, %{
        page_title: "#{form_title} an Alert",
        progress: progress_on_mount(params, form_type, @steps),
        steps: @steps,
        alert_data: alert_data,
        combination: Map.get(alert_data, :combination),
        selected_routes: [],
        selected_stops: [],
        selected_schedules: [],
        selected_facilities: [],
        selected_route_type: route_type_from_params!(params),
        selected_effect: effect_name_from_params!(params),
        alert_uuid: nil,
        alert_id: alert_id,
        form_type: form_type,
        errors: %{},
        submitted: false,
        obsolete_ids: %{},
        obsolete_id_text: [],
        remounted: remounting?(socket),
        debug_tag: :crypto.strong_rand_bytes(8) |> Base.encode64()
      })
    }
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
      :duplicating -> "Duplicating"
      :creating -> "Create"
    end
  end

  defp progress_on_mount(params, form_type, [first_step, second_step | _]) do
    route_type = Map.get(params, "route_type")
    effect = Map.get(params, "effect")

    if form_type == :creating && (is_nil(route_type) || is_nil(effect)) do
      first_step
    else
      second_step
    end
  end

  def effect_from_url_name(nil), do: nil

  def effect_from_url_name(url_name) do
    url_name
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize(&1))
    |> String.replace("-route", "-Route")
  end

  def effect_to_url_name(effect_name) do
    effect_name
    |> String.split(" ")
    |> Enum.map_join("_", &String.downcase(&1))
  end

  def effect_name_from_params!(params) do
    case Map.get(params, "effect") do
      nil ->
        nil

      effect ->
        effect_name = effect_from_url_name(effect)

        if Effect.effect_map_by_name(effect_name) == %{} do
          raise ArgumentError, "no such effect #{effect_name}"
        else
          effect_name
        end
    end
  end

  def route_type_from_params!(params) do
    case Map.get(params, "route_type") do
      nil ->
        nil

      route_type ->
        route_type_atom = String.to_existing_atom(route_type)

        if InformedEntity.valid_route_type?(route_type_atom) do
          route_type
        else
          raise ArgumentError, "no such route type #{route_type}"
        end
    end
  end

  defp alert_data_on_mount(params, form_type, existing_alert_or_nil) do
    case existing_alert_or_nil do
      nil ->
        assign_from_params(%{}, params)

      alert ->
        alert
        |> AlertData.build_alert_data(form_type)
        |> Map.from_struct()
    end
    |> adjust_by_form_type(form_type)
  end

  @spec adjust_by_form_type(AlertData.t(), atom()) :: AlertData.t()

  defp adjust_by_form_type(alert_data, :duplicating) do
    if AlertsUI.ActiveStatus.get_alert_status(alert_data) == :past do
      now = DateTime.utc_now() |> DateTime.shift_zone!("America/New_York")

      active_period_end_specifier =
        if Map.get(alert_data, :alert_timing, :"one-time") == :"one-time" do
          :later_today
        else
          :until_further_notice
        end

      Map.merge(alert_data, %{
        start_datetime: now,
        end_datetime: nil,
        active_period_start_specifier: :now,
        active_period_start: now,
        active_period_start_date: now |> DateTime.to_date(),
        active_period_end_specifier: active_period_end_specifier,
        active_period_end: nil,
        active_period_end_date: nil,
        notification_specifier: :now,
        notification_period_start: now
      })
    else
      alert_data
    end
    |> Map.put(:reminder_times, [])
  end

  defp adjust_by_form_type(alert_data, _), do: alert_data

  defp assign_from_params(alert_data, params) do
    effect_name = effect_name_from_params!(params)

    route_type_mapping =
      case route_type_from_params!(params) do
        nil ->
          nil

        route_type ->
          mapping =
            route_type
            |> String.to_existing_atom()
            |> InformedEntity.route_type_mapping()

          if is_nil(mapping) && effect_name in EffectsForRouteTypes.list_effects(:facility) do
            :facility
          else
            mapping
          end
      end

    combination =
      GetKeyForModeEffect.get_value_of_key(
        :combination,
        route_type_mapping,
        effect_name
      )

    alert_data
    |> Map.put(:route_type, Map.get(alert_data, :route_type, route_type_mapping))
    |> Map.put(:effect_name, Map.get(alert_data, :effect, effect_name))
    |> Map.put(:combination, Map.get(alert_data, :combination, combination))
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("move_progress", %{"value" => "route_type_and_effect"}, socket) do
    {:noreply,
     assign(socket, progress: get_step_by_name("route_type_and_effect"), alert_data: %{})}
  end

  @impl true
  def handle_event("move_progress", %{"value" => name}, socket) do
    {:noreply, assign(socket, :progress, get_step_by_name(name))}
  end

  @impl true
  def handle_event("accepted_gtfs_modal", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancelled_gtfs_modal", _params, socket) do
    {:noreply, socket |> redirect(to: return_to(socket.assigns.return_to || "/"))}
  end

  def get_routes([4]) do
    [4]
    |> RoutesRepo.by_type(listed_route: false)
    |> Enum.sort_by(&SelectFormatter.sort_order/1)
  end

  def get_routes(route_types) do
    route_types
    |> RoutesRepo.by_type()
    |> Enum.filter(&(Map.get(&1, :description) !== :rail_replacement_bus))
    |> maybe_include_virtual_green_line()
    |> Enum.sort_by(&SelectFormatter.sort_order/1)
  end

  # get all schedules from today until end of rating
  def get_schedules_by_date(route_ids, direction, nil) do
    today =
      DateTime.utc_now()
      |> DateTime.shift_zone!("America/New_York")
      |> ActivePeriod.datetime_to_service_date()

    end_of_rating = SchedulesRepo.end_of_rating()

    schedules =
      Date.range(today, end_of_rating)
      |> Task.async_stream(fn date ->
        route_ids
        |> get_schedules(direction, date)
        |> Enum.group_by(& &1.trip.id)
        |> Enum.map(fn {_k, [first_schedule, last_schedule]} ->
          update_schedule(first_schedule, last_schedule)
        end)
      end)
      |> Stream.filter(fn {result, _item} -> result == :ok end)
      |> Stream.flat_map(fn {:ok, item} -> item end)
      |> Stream.uniq_by(&{&1.trip.id, DateTime.to_time(&1.departure_time), &1.trip.name})
      |> Enum.to_list()
      |> Enum.sort_by(&(&1.departure_time |> DateTime.to_time()), Time)

    # get a map (by {departure time, trip name}) of all schedules whose combination of
    # departure time and trip name occur more than once in the list of schedules
    freq =
      schedules
      |> Enum.frequencies_by(&{DateTime.to_time(&1.departure_time), &1.trip.name})
      |> Enum.filter(fn {_k, v} -> v > 1 end)
      |> Enum.into(%{})

    # Some trips can have the same name and departure time but different trip ids, because
    # they run on different days (eg part of different route patterns)
    # This sets the `:use_trip_id_in_name?` of all the schedules that appear in the frequency list above
    # to `true`, so we know to use the trip_id in the display name so users can tell them apart.
    Enum.map(schedules, fn schedule ->
      if Map.has_key?(freq, {DateTime.to_time(schedule.departure_time), schedule.trip.name}) do
        Map.put(schedule, :use_trip_id_in_name?, true)
      else
        schedule
      end
    end)
  end

  def get_schedules_by_date(route_ids, direction, date) do
    # get schedules for 1 day
    route_ids
    |> get_schedules(direction, date)
    |> filter_out_old_trips
  end

  @spec get_schedules([String.t()], String.t(), Date.t()) :: list()
  defp get_schedules(route_ids, direction, date) do
    directions = directions_from_selection(direction)
    opts = [stop_sequences: [:first, :last], date: date] |> direction_option(directions)

    route_ids
    |> SchedulesRepo.by_route_ids(opts)
    |> Enum.map(fn schedule ->
      map = Map.from_struct(schedule)
      Kernel.struct(EnhancedSchedule, map)
    end)
  end

  # stop route with no route ids (unfiltered)
  def get_stops_for_stop_route(nil, route_type), do: get_stops(nil, route_type)

  def get_stops_for_stop_route(route_ids, 3) do
    # stop route with route ids (filtered), bus
    route_ids
    |> Enum.join(",")
    |> List.wrap()
    |> available_stops_for_bus_stop_route()
  end

  def get_stops_for_stop_route(route_ids, route_type) do
    # stop route with route ids (filtered), other types
    available_stops([0, 1], route_ids, route_type)
  end

  @spec get_stops([String.t()] | nil, integer() | nil, String.t() | nil) :: list()
  def get_stops(route_ids, route_type, direction \\ nil)

  def get_stops(nil, 3, nil) do
    # used for stop-route combination, bus mode.

    # direction filtering does nothing if a route id is not
    # included with the call. Doing 1 call for every route id
    # is too many so we have to chunk them up thus.
    # note- larger chunks take longer. small chunk is good.
    RoutesRepo.by_type(3)
    |> Enum.map(& &1.id)
    |> Enum.chunk_every(10)
    |> Enum.map(&Enum.join(&1, ","))
    |> available_stops_for_bus_stop_route()
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  def get_stops(nil, 1, nil) do
    # used for stop-route combination, subway (also gets light rail)
    (StopsRepo.by_route_type(0, include: "") ++ StopsRepo.by_route_type(1, include: ""))
    |> Enum.sort_by(&String.downcase(&1.name))
    |> Enum.uniq()
  end

  def get_stops(nil, route_type, nil) do
    # used for stop-route combination, other modes
    StopsRepo.by_route_type(route_type, include: "") |> Enum.sort_by(&String.downcase(&1.name))
  end

  def get_stops(["Green"] = route_ids, _route_type, direction) do
    # used in non stop-route combinations, green line
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

  def get_stops(route_ids, route_type, direction) do
    direction
    |> directions_from_selection()
    |> available_stops(route_ids, route_type)
  end

  def get_routes_by_stop(stop_ids, 3) do
    Enum.flat_map(stop_ids, &RoutesRepo.by_stop(&1, "filter[type]": 3))
    |> Enum.filter(&(Map.get(&1, :description) !== :rail_replacement_bus))
    |> Enum.sort_by(&SelectFormatter.sort_order/1)
    |> Enum.uniq()
  end

  def get_routes_by_stop(stop_ids, _route_type) do
    Enum.flat_map(stop_ids, &RoutesRepo.by_stop(&1))
    |> Enum.sort_by(&SelectFormatter.sort_order/1)
    |> Enum.uniq()
  end

  def get_facilities(facility_types) do
    facilties_from_api = FacilitiesRepo.get_by_type(facility_types, include: "stop")

    available_facilities =
      facilties_from_api
      # remove facilities that we don't control
      |> Enum.filter(&(!is_nil(&1.stop)))
      |> Enum.uniq()
      |> Enum.sort_by(&String.downcase(&1.long_name))

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
      |> Enum.sort_by(&String.downcase(&1.name))

    %{stops: available_stops, facilities: available_facilities}
  end

  def handle_info({:selected_routes, selected_routes}, socket) do
    {:noreply, assign(socket, selected_routes: selected_routes)}
  end

  def handle_info({:selected_stops, selected_stops}, socket) do
    {:noreply, assign(socket, selected_stops: selected_stops)}
  end

  def handle_info({:selected_schedules, selected_schedules}, socket) do
    {:noreply, assign(socket, selected_schedules: selected_schedules)}
  end

  def handle_info({:selected_facilities, selected_facilities}, socket) do
    {:noreply, assign(socket, selected_facilities: selected_facilities)}
  end

  def handle_info({:got_obsolete_ids, obsolete_ids_map}, socket) do
    alert_data = socket.assigns.alert_data

    # builds a list of the text to go in the obsolete ids modal
    obsolete_id_text =
      obsolete_ids_map
      # for every field (route, stop, etc in the obsolete ids map)
      |> Enum.map(fn {field_name, obsolete_ids} ->
        # build name of corresponding "original selections" field
        name_part = field_name |> Atom.to_string() |> String.split("_") |> hd

        original_field =
          Map.get(alert_data, String.to_existing_atom("original_#{name_part}_selections"))

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

  @impl true
  def handle_info({:add_errors, errors, name}, socket) do
    updated_errors = socket.assigns.errors |> Map.put(name, errors)
    {:noreply, assign(socket, errors: updated_errors)}
  end

  @impl true
  def handle_info({:section_completed, changeset}, socket) do
    assigns =
      %{
        alert_data:
          Map.merge(
            socket.assigns.alert_data,
            changeset
            |> Map.from_struct()
          )
      }

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_info({:step_completed, changes}, socket) do
    alert_data = Map.merge(socket.assigns.alert_data, changes |> Map.from_struct())
    route_type = Map.get(alert_data, :route_type)
    effect_name = Map.get(alert_data, :effect_name)

    route_type =
      if is_nil(route_type) and
           effect_name in EffectsForRouteTypes.list_effects(:facility) do
        :facility
      else
        route_type
      end

    # any values put in alert data put here will be read in upon creation but not edit (since this step is only reached
    # when going to the second page). this makes it a good place to read default values from our config.
    combination = GetKeyForModeEffect.get_value_of_key(:combination, route_type, effect_name)

    default_severity =
      GetKeyForModeEffect.get_value_of_key(:default_severity, route_type, effect_name)

    default_cause =
      GetKeyForModeEffect.get_value_of_key(:default_cause, route_type, effect_name)

    notification_toggle =
      GetKeyForModeEffect.get_value_of_key(
        :send_push_notification_on_create,
        route_type,
        effect_name
      )

    assigns = %{
      progress: get_step_by_name(socket.assigns.progress.next),
      alert_data:
        Map.merge(alert_data, %{
          combination: combination,
          severity: default_severity,
          cause_detail: default_cause,
          notification_toggle: notification_toggle
        }),
      combination: combination,
      selected_schedules: nil,
      selected_facilities: nil,
      selected_routes: nil,
      selected_stops: nil,
      errors: %{}
    }

    {:noreply, assign(socket, assigns)}
  end

  def handle_info(:show_errors, socket) do
    errors = Map.values(socket.assigns.errors) |> List.flatten()

    socket =
      if Enum.empty?(errors) do
        send_update(Submit, id: "submit", show: true)
        socket
      else
        formatted_errors =
          errors
          |> Enum.map(fn {_title, {message, _error}} -> "#{message}" end)
          |> Enum.uniq()
          |> Enum.join(";")

        display_errors(socket, formatted_errors)
      end

    {:noreply, socket}
  end

  def handle_info(:create_alert, socket) do
    {:noreply, create_alert(socket)}
  end

  defp create_alert(socket) do
    form_type = socket.assigns.form_type

    user = Users.create_or_update_user_from_session(socket.assigns.current_user)

    alert_data = AlertBuilder.build_alert(socket.assigns.alert_data, socket.assigns.combination)

    existing_alert =
      if is_nil(socket.assigns.alert_id) || form_type == :duplicating do
        %Alert{}
      else
        Alerts.get_by_alert_id(socket.assigns.alert_id)
      end

    alert =
      alert_data
      |> Alerts.create_or_update_alert(user, existing_alert)
      |> case do
        {:ok, alert} ->
          alert_id =
            alert.id
            |> Alerts.get_by_id()
            |> Map.get(:alert_id)

          socket
          |> put_flash(:info, flash_text(socket.assigns.alert_id, alert_id, form_type))
          |> redirect(to: return_to(socket.assigns.return_to || "/"))

        {:error, result} ->
          errors =
            result
            |> Alerts.parse_changeset_errors()
            |> format_errors(socket.assigns.combination)

          display_errors(socket, errors)
      end

    Phoenix.PubSub.broadcast(
      AlertsUI.PubSub,
      "alerts",
      {:alerts_updated}
    )

    alert
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
    |> put_flash(:title, "Please fix the following errors:")
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

  @spec available_stops_for_bus_stop_route([String.t()]) :: [Stop.t()]
  defp available_stops_for_bus_stop_route(route_id_lists) do
    outbound =
      route_id_lists
      |> Enum.map(&StopsRepo.by_route(&1, 0, include: ""))
      |> List.flatten()
      |> Enum.uniq()

    inbound =
      route_id_lists
      |> Enum.map(&StopsRepo.by_route(&1, 1, include: ""))
      |> List.flatten()
      |> Enum.uniq()

    both = MapSet.intersection(MapSet.new(outbound), MapSet.new(inbound)) |> MapSet.to_list()

    outbound = (outbound -- both) |> map_direction_names_to_stops(0)
    inbound = (inbound -- both) |> map_direction_names_to_stops(1)

    (inbound ++ both ++ outbound) |> List.flatten()
  end

  @spec available_stops([integer()], [String.t()], integer()) :: [Stop.t()]
  defp available_stops(direction_array, route_ids, route_type) do
    route_ids
    |> Enum.flat_map(fn route ->
      Enum.flat_map(direction_array, &get_stops_by_route(route, &1, route_type))
    end)
  end

  @spec get_stops_by_route(String.t(), integer(), integer()) :: [Stop.t()]
  defp get_stops_by_route(route, direction, 3) do
    route
    |> StopsRepo.by_route(direction, include: "")
    |> map_direction_names_to_stops(direction)
  end

  defp get_stops_by_route(route, direction, _route_type) do
    StopsRepo.by_route(route, direction, include: "")
  end

  defp map_direction_names_to_stops(stops, direction) do
    direction_word = if direction == 0, do: "outbound", else: "inbound"
    Enum.map(stops, fn stop -> Map.put(stop, :name, stop.name <> " (#{direction_word})") end)
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
end
