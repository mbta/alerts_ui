defmodule AlertsUIWeb.FormComponents.Helpers.AutoText.BuildAutoText do
  @moduledoc """
    Constructs auto-text for header and description from affected service.
  """
  alias AlertsUIWeb.FormComponents.Helpers.{ContentFormatter, SelectFormatter}
  alias AlertsUI.Models.{EnhancedSchedule, InformedEntity, SeverityLevel}
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Stop

  defstruct route_type: nil,
            effect_detail: nil,
            routes: [],
            schedules: [],
            facility: nil,
            service_types: [],
            direction: [],
            severity: nil,
            cause_detail: "",
            start_specifier: nil,
            end_specifier: nil,
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
          effect_detail: String.t() | nil,
          routes: [Route.t()],
          schedules: [EnhancedSchedule.t()],
          facility: Facility.t() | nil,
          service_types: [integer()],
          # may need to use `CreateAlertLive.directions_from_selection` to get this
          direction: [integer()],
          severity: integer() | nil,
          cause_detail: String.t(),
          start_specifier: atom() | nil,
          end_specifier: atom() | nil,
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
    "DEMONSTRATION",
    "DISABLED_BUS",
    "DRAWBRIDGE_BEING_RAISED",
    "FIRE",
    "HAZMAT_CONDITION",
    "HURRICANE",
    "MEDICAL_EMERGENCY",
    "PARADE",
    "SPECIAL_EVENT",
    "COAST_GUARD_RESTRICTION",
    "CROSSING_ISSUE",
    "DISABLED_TRAIN",
    "MECHANICAL_ISSUE",
    "MECHANICAL_PROBLEM",
    "POWER_PROBLEM",
    "RAIL_DEFECT",
    "SIGNAL_ISSUE",
    "SIGNAL_PROBLEM",
    "SLIPPERY_RAIL",
    "SPEED_RESTRICTION",
    "SWITCH_ISSUE",
    "SWITCH_PROBLEM",
    "TRACK_PROBLEM",
    "UNRULY_PASSENGER"
  ]
  @uses_definite_article ["HOLIDAY"]

  @spec build_header_auto_text(__MODULE__.t()) :: String.t()
  def build_header_auto_text(_auto_text_data) do
    "description autotext"
  end

  @spec build_description_auto_text([Stop.t()]) :: String.t()
  def build_description_auto_text(_stops) do
    "description autotext"
  end

  # cause
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
  @spec severity(integer() | nil) :: String.t()
  def severity(nil), do: ""

  def severity(severity) do
    SeverityLevel.severity_description_by_severity(severity)
  end

  # service type/impacted route_type
  @spec service_types([integer()]) :: String.t()

  def service_types(route_types) do
    route_types
    |> Enum.map(&format_service_type/1)
    |> join_together
  end

  # directions
  def direction_name([direction], [route]) do
    if Map.get(route, :direction_names) do
      route.direction_names[direction]
    else
      Map.get(%{0 => "Outbound", 1 => "Inbound"}, direction)
    end
  end

  def direction_name(_direction, _routes), do: ""

  # stops
  @spec stop_names([Stop.t()]) :: String.t()
  def stop_names(stops) do
    stops
    |> Enum.map(&SelectFormatter.name_for_option/1)
    |> join_together
  end

  # stop form (modifies stops)
  @spec stop_form([Stop.t()]) :: String.t()
  def stop_form([]), do: ""
  def stop_form([_stop]), do: "stop is"
  def stop_form(_stops), do: "stops are"

  # stop range (between x and y)
  @spec stop_range([Stop.t()]) :: String.t()
  def stop_range([]), do: ""
  def stop_range([stop]), do: "at " <> SelectFormatter.name_for_option(stop)

  def stop_range(stops) do
    stop_names = Enum.map(stops, &SelectFormatter.name_for_option/1)
    "between #{List.first(stop_names)} and #{List.last(stop_names)}"
  end

  # trips
  @spec trip_names([EnhancedSchedule.t()], integer()) :: String.t()
  def trip_names([], _), do: ""

  def trip_names(schedules, route_type) do
    trips_string =
      schedules
      |> Enum.map(&SelectFormatter.name_for_option/1)
      |> join_together

    "#{trip_word(schedules, route_type)} #{trips_string}"
  end

  defp trip_word([_schedule], 2), do: "train"
  defp trip_word(_, 2), do: "trains"
  defp trip_word([_schedule], _), do: "trip"
  defp trip_word(_, _), do: "trips"

  @spec trip_form([EnhancedSchedule.t()]) :: String.t()
  def trip_form([]), do: ""
  def trip_form([_schedules]), do: "trip is"
  def trip_form(_schedules), do: "trips are"

  # facilities
  @spec facility_name(Facility.t()) :: String.t()
  def facility_name(nil), do: ""

  def facility_name(facility) do
    SelectFormatter.name_for_option(facility)
  end

  # routes (short)
  @spec route_names_short([Route.t()], integer()) :: String.t()
  def route_names_short([], _route_type), do: ""

  def route_names_short(routes, route_type) when length(routes) > 2 do
    format_service_type(route_type)
  end

  def route_names_short(routes, _route_type) do
    route_names(routes)
  end

  # routes
  @spec route_names([Route.t()]) :: String.t()
  def route_names([]), do: ""

  def route_names(routes) when length(routes) > 5 do
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

  def route_names(routes) do
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
    "#{route_word(numerical_routes)}#{numerical_routes |> join_together}"
  end

  defp non_numerical_routes_phrase(nil, _), do: ""
  defp non_numerical_routes_phrase(routes, nil), do: join_together(routes)

  defp non_numerical_routes_phrase(routes, _numerical_routes) do
    Enum.join(routes, ", ")
  end

  defp route_word([_route]), do: "Route "
  defp route_word(_routes), do: "Routes "

  # formatters
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

  defp format_cause(cause_detail) do
    cause_detail |> String.replace("_", " ") |> String.downcase()
  end

  defp format_service_type(route_type) do
    route_type |> InformedEntity.route_code_mapping() |> ContentFormatter.route_atom_to_string()
  end
end
