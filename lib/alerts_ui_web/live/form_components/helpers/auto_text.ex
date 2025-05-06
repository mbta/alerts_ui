defmodule AlertsUIWeb.FormComponents.Helpers.AutoText do
  @moduledoc """
    Constructs auto-text for header and description from affected service.
  """
  alias AlertsUI.Models.{InformedEntity, SeverityLevel}
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Stop

  defstruct mode: nil,
            effect_detail: nil,
            routes: [],
            trips: [],
            facility: nil,
            direction: nil,
            severity: nil,
            cause: nil,
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
          mode: String.t() | nil,
          effect_detail: String.t() | nil,
          routes: [Route.t()],
          trips: [Trip.t()],
          facility: Facility.t() | nil,
          direction: String.t(),
          severity: integer() | nil,
          cause: String.t() | nil,
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

  @spec severity(integer()) :: String.t()
  def severity(severity) do
    SeverityLevel.severity_description_by_severity(severity)
  end

  defp format_cause(cause_detail) do
    cause_detail |> String.replace("_", " ") |> String.downcase()
  end
end
