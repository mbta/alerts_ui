defmodule AlertsUIWeb.CreateAlertHelpers do
  @moduledoc "API functions for Create Alert."
  use AlertsUIWeb, :live_view

  alias AlertsUIWeb.CreateAlertLive.Helpers.{
    GreenLine,
    SelectFormatter
  }

  alias AlertsUI.Models.{ActivePeriod, Effect, EnhancedSchedule, InformedEntity}
  alias AlertsUI.Routes
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

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

  def return_to(return_to_value) do
    uri = URI.parse(return_to_value)

    if uri.path == "/alerts" do
      "/alerts?#{uri.query}"
    else
      "/"
    end
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
