defmodule AlertsUIWeb.FormComponents.Helpers.AutoText do
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
            direction: nil,
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
          direction: String.t(),
          severity: integer() | nil,
          cause_detail: String.t(),
          start_specifier: atom() | nil,
          end_specifier: atom() | nil,
          start_datetime: DateTime.t() | nil,
          end_datetime: DateTime.t() | nil,
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

  # service type/impacted mode
  @spec service_types([integer()]) :: String.t()

  def service_types(modes) do
    modes
    |> Enum.map(&format_service_type/1)
    |> join_together
  end

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

  # formatters
  defp join_together([]), do: ""

  defp join_together([thing]) do
    thing
  end

  defp join_together([_, _] = things) do
    Enum.join(things, " and ")
  end

  defp join_together(things) do
    things
    |> List.replace_at(-1, "and " <> List.last(things))
    |> Enum.join(", ")
  end

  defp format_cause(cause_detail) do
    cause_detail |> String.replace("_", " ") |> String.downcase()
  end

  defp format_service_type(mode) do
    mode |> InformedEntity.route_code_mapping() |> ContentFormatter.route_atom_to_string()
  end
end
