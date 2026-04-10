defmodule AlertsUIWeb.FormComponents.Helpers.AutoText.BuildAutoText do
  @moduledoc """
    Constructs auto-text for header from affected service.
  """
  alias AlertsUI.Models.{EnhancedSchedule, InformedEntity, SeverityLevel}
  alias AlertsUIWeb.FormComponents.Helpers.AutoText.AutoTextDuration
  alias AlertsUIWeb.FormComponents.Helpers.{ContentFormatter, DateTimeHelpers, SelectFormatter}
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Stop

  defstruct route_type: nil,
            effect_name: nil,
            routes: [],
            stops: [],
            schedules: [],
            facility: nil,
            service_types: [],
            direction: [],
            severity: nil,
            cause_detail: "",
            start_specifier: nil,
            end_specifier: nil,
            start_time_specifier: nil,
            end_time_specifier: nil,
            start_datetime: nil,
            end_datetime: nil,
            start_date: nil,
            end_date: nil,
            start_time: nil,
            end_time: nil,
            alert_timing: :one_time,
            recurrence_days: []

  @type t :: %__MODULE__{
          route_type: integer() | nil,
          effect_name: String.t() | nil,
          routes: [Route.t()],
          stops: [Stop.t()],
          schedules: [EnhancedSchedule.t()],
          facility: Facility.t() | nil,
          service_types: [integer()],
          direction: [integer()],
          severity: integer() | nil,
          cause_detail: String.t(),
          start_specifier: atom() | nil,
          end_specifier: atom() | nil,
          start_time_specifier: atom() | nil,
          end_time_specifier: atom() | nil,
          start_datetime: NaiveDateTime.t() | nil,
          end_datetime: NaiveDateTime.t() | nil,
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          start_time: Time.t() | nil,
          end_time: Time.t() | nil,
          alert_timing: :one_time | :recurring,
          recurrence_days: [atom()]
        }

  @uses_indefinite_article [
    "ACCIDENT",
    "COAST_GUARD_RESTRICTION",
    "CROSSING_ISSUE",
    "DEMONSTRATION",
    "DISABLED_BUS",
    "DISABLED_TRAIN",
    "DRAWBRIDGE_BEING_RAISED",
    "DRAWBRIDGE_ISSUE",
    "FIRE",
    "HAZMAT_CONDITION",
    "HURRICANE",
    "MECHANICAL_ISSUE",
    "MECHANICAL_PROBLEM",
    "MEDICAL_EMERGENCY",
    "PARADE",
    "POWER_PROBLEM",
    "RAIL_DEFECT",
    "SIGNAL_ISSUE",
    "SIGNAL_PROBLEM",
    "SLIPPERY_RAIL",
    "SPECIAL_EVENT",
    "SPEED_RESTRICTION",
    "SWITCH_ISSUE",
    "SWITCH_PROBLEM",
    "TRACK_PROBLEM",
    "UNRULY_PASSENGER"
  ]

  @uses_definite_article ["HOLIDAY"]

  # duration
  @spec alert_duration(__MODULE__.t()) :: String.t()
  def alert_duration(autotext_data) do
    AutoTextDuration.build_duration_text(autotext_data)
  end

  # cause
  @spec due_to_cause(__MODULE__.t()) :: String.t()
  def due_to_cause(%{cause_detail: ""}), do: ""

  def due_to_cause(%{cause_detail: cause_detail}) do
    "due to #{cause(cause_detail)}"
    |> String.replace("amtrak", "Amtrak")
    |> String.replace("coast guard", "Coast Guard")
  end

  @spec cause(String.t()) :: String.t()
  def cause(cause_detail) when cause_detail in @uses_definite_article do
    "the #{format_cause(cause_detail)}"
  end

  def cause(cause_detail) when cause_detail in @uses_indefinite_article do
    first_letter = String.first(cause_detail)
    article = if first_letter in ["A", "E", "I", "O", "U"], do: "an", else: "a"
    "#{article} #{format_cause(cause_detail)}"
  end

  def cause(cause_detail), do: format_cause(cause_detail)

  # severity
  @spec severity_name(__MODULE__.t()) :: String.t()
  def severity_name(%{severity: nil}), do: ""

  def severity_name(%{severity: severity}) do
    SeverityLevel.severity_description_by_severity(severity)
  end

  # impacted modes/ route types
  @spec impacted_modes(__MODULE__.t()) :: String.t()

  def impacted_modes(%{service_types: service_types}) do
    service_types
    |> Enum.map(&format_service_type/1)
    |> join_together
  end

  # directions
  @spec direction_name(__MODULE__.t()) :: String.t()
  def direction_name(%{direction: [direction], routes: [route]}) do
    if Map.get(route, :direction_names) do
      String.downcase(route.direction_names[direction])
    else
      Map.get(%{0 => "outbound", 1 => "inbound"}, direction)
    end
  end

  def direction_name(_), do: ""

  # stops
  @spec stop_names(__MODULE__.t()) :: String.t()
  def stop_names(%{stops: stops}) do
    stops
    |> Enum.map(&SelectFormatter.name_for_option/1)
    |> join_stops
  end

  # stop form (modifies stops)
  @spec stop_form(__MODULE__.t()) :: String.t()
  def stop_form(%{stops: stops, start_datetime: start_datetime}) do
    standard_form(stops, start_datetime)
  end

  @spec stop_word(__MODULE__.t()) :: String.t()
  def stop_word(%{stops: []}), do: ""
  def stop_word(%{stops: [_stop]}), do: "stop"
  def stop_word(%{stops: _stops}), do: "stops"

  # stop range (between x and y)
  @spec stop_range_between(__MODULE__.t()) :: String.t()
  def stop_range_between(%{stops: []}), do: ""
  def stop_range_between(%{stops: [stop]}), do: "at " <> SelectFormatter.name_for_option(stop)

  def stop_range_between(%{stops: stops}) do
    stop_names = Enum.map(stops, &SelectFormatter.name_for_option/1)
    "between #{List.first(stop_names)} and #{List.last(stop_names)}"
  end

  @spec stop_range_at(__MODULE__.t()) :: String.t()
  def stop_range_at(%{stops: []}), do: ""

  def stop_range_at(%{stops: stops}) when length(stops) > 3 do
    stop_names = Enum.map(stops, &SelectFormatter.name_for_option/1)
    "at #{List.first(stop_names)} through #{List.last(stop_names)}"
  end

  def stop_range_at(%{stops: stops}) do
    stop_names = Enum.map(stops, &SelectFormatter.name_for_option/1)
    "at #{join_together(stop_names)}"
  end

  @spec closest_stop_text(__MODULE__.t()) :: String.t()
  def closest_stop_text(%{direction: [_direction]}) do
    "The closest stops with service are ___ and ___"
  end

  def closest_stop_text(_alert_data) do
    "The closest stops with inbound service are ___ and ___. The closest stops with outbound service are ___ and ___"
  end

  # trips
  @spec trip_names_only(__MODULE__.t()) :: String.t()
  def trip_names_only(%{schedules: []}), do: ""

  def trip_names_only(%{schedules: schedules, route_type: route_type}) do
    trip_word = maybe_pluralize(trip_word(route_type), length(schedules) > 1)

    schedules
    |> Enum.map(fn schedule -> Map.put(schedule, :use_trip_id_in_name?, false) end)
    |> Enum.map(&SelectFormatter.name_for_option(&1, route_type))
    |> join_trips(trip_word)
  end

  @spec trip_names(__MODULE__.t()) :: String.t()
  def trip_names(%{schedules: []}), do: ""

  def trip_names(%{schedules: schedules, route_type: route_type} = autotext_data) do
    trips_string = trip_names_only(autotext_data)
    trip_word = route_type |> trip_word() |> maybe_pluralize(length(schedules) == 2)

    trip_word = if route_type == 2, do: String.capitalize(trip_word), else: trip_word

    "#{trip_word} #{trips_string}"
  end

  defp trip_word(2), do: "train"
  defp trip_word(_), do: "trip"

  @spec trip_form(__MODULE__.t()) :: String.t()
  def trip_form(%{schedules: schedules, start_datetime: start_datetime}) do
    standard_form(schedules, start_datetime)
  end

  # facilities
  @spec facility_name(__MODULE__.t()) :: String.t()
  def facility_name(%{facility: nil}), do: ""

  def facility_name(%{facility: facility}) do
    SelectFormatter.name_for_option(facility)
  end

  # routes (short)
  @spec route_names_short(__MODULE__.t()) :: String.t()
  def route_names_short(%{routes: []}), do: ""

  def route_names_short(%{routes: routes, route_type: route_type}) when length(routes) > 2 do
    format_service_type(route_type)
  end

  def route_names_short(%{routes: _routes} = autotext_data) do
    route_names(autotext_data)
  end

  # routes
  @spec route_names(__MODULE__.t()) :: String.t()
  def route_names(%{routes: []}), do: ""

  def route_names(%{routes: routes, schedules: []}) when length(routes) > 5 do
    route_names =
      routes
      |> Enum.map(&SelectFormatter.name_for_option/1)
      |> Enum.group_by(&first_letter_numeric?/1)

    numerical_routes = Map.get(route_names, true, nil)
    non_numerical_routes = Map.get(route_names, false, nil)

    other_routes_length = length(routes) - 1

    if non_numerical_routes == nil do
      named_route = hd(numerical_routes)
      "Route #{named_route} and #{other_routes_length} other routes"
    else
      named_route = hd(non_numerical_routes)
      "#{named_route} and #{other_routes_length} other routes"
    end
  end

  def route_names(%{routes: routes, schedules: []}) do
    route_names =
      routes
      |> Enum.map(&SelectFormatter.name_for_option/1)
      |> Enum.group_by(&first_letter_numeric?/1)

    numerical_routes = Map.get(route_names, true)
    non_numerical_routes = Map.get(route_names, false)

    numerical_routes_phrase = numerical_routes_phrase(numerical_routes)
    # if there are numerical routes, non-numerical don't get "and"
    non_numerical_routes_phrase =
      non_numerical_routes_phrase(non_numerical_routes, numerical_routes)

    joiner = route_joiner(numerical_routes, non_numerical_routes)
    "#{non_numerical_routes_phrase}#{joiner}#{numerical_routes_phrase}"
  end

  def route_names(%{routes: routes, schedules: schedules} = autotext) do
    # if there are schedules selected, only include the routes which are associated
    # with the selected schedules
    route_ids_from_schedules = Enum.map(schedules, & &1.route.id)
    filtered_routes = Enum.filter(routes, &(&1.id in route_ids_from_schedules))

    autotext |> Map.merge(%{routes: filtered_routes, schedules: []}) |> route_names()
  end

  def route_word([_route]), do: "route"
  def route_word(_routes), do: "routes"

  # route form (modifies routes)
  @spec route_form(__MODULE__.t()) :: String.t()
  def route_form(%{routes: routes, start_datetime: start_datetime}) do
    standard_form(routes, start_datetime)
  end

  defp first_letter_numeric?(route_name) do
    route_name
    |> String.first()
    |> Integer.parse() !== :error
  end

  defp route_joiner(one, two) when is_nil(one) or is_nil(two) do
    ""
  end

  defp route_joiner(_one, _two) do
    " and "
  end

  defp numerical_routes_phrase(nil), do: ""

  defp numerical_routes_phrase(numerical_routes) do
    "#{numerical_routes |> route_word() |> String.capitalize()} #{numerical_routes |> join_together}"
  end

  defp non_numerical_routes_phrase(nil, _), do: ""
  defp non_numerical_routes_phrase(routes, nil), do: join_together(routes)

  defp non_numerical_routes_phrase(routes, _numerical_routes) do
    Enum.join(routes, ", ")
  end

  # formatters

  def join_trips([_ | _] = trips, trip_word) when length(trips) > 2 do
    "#{hd(trips)} and #{length(trips) - 1} other #{trip_word}"
  end

  def join_trips(trips, _), do: join_together(trips)

  def join_stops([_ | _] = stops) when length(stops) > 2 do
    "#{length(stops)} stops"
  end

  def join_stops(stops), do: join_together(stops)

  def join_together(nil), do: ""
  def join_together([]), do: ""

  def join_together([thing]) do
    thing
  end

  def join_together([_, _] = things) do
    Enum.join(things, " and ")
  end

  def join_together(things) do
    things
    |> List.replace_at(-1, "and " <> List.last(things))
    |> Enum.join(", ")
  end

  # add "s" to word if second argument evaluates to true
  def maybe_pluralize(word, true), do: word <> "s"
  def maybe_pluralize(word, false), do: word

  defp format_cause(cause_detail) do
    cause_detail |> String.replace("_", " ") |> String.downcase()
  end

  defp format_service_type(route_type) do
    route_type |> InformedEntity.route_code_mapping() |> ContentFormatter.route_atom_to_string()
  end

  @spec standard_form(list(), NaiveDateTime.t()) :: String.t()
  defp standard_form([], _start_datetime), do: ""

  defp standard_form([_ | _] = entities, start_datetime) do
    current_time = DateTimeHelpers.current_time()

    if DateTimeHelpers.time_is_in_future?(start_datetime, current_time) do
      "will be"
    else
      form_word(entities)
    end
  end

  defp form_word([_item]), do: "is"
  defp form_word(_item), do: "are"
end
