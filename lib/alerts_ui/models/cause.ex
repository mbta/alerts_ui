defmodule AlertsUI.Models.Cause do
  @moduledoc """
    Causes to be used in the cause field of Alerts.
  """

  @doc """
  Returns list of atoms allowed in cause field of alert

  ## Examples
      iex> is_list(AlertsUI.Models.Cause.causes)
      true
  """
  def causes,
    do: [
      :UNKNOWN_CAUSE,
      :OTHER_CAUSE,
      :TECHNICAL_PROBLEM,
      :STRIKE,
      :DEMONSTRATION,
      :ACCIDENT,
      :HOLIDAY,
      :WEATHER,
      :MAINTENANCE,
      :CONSTRUCTION,
      :POLICE_ACTIVITY,
      :MEDICAL_EMERGENCY
    ]

  @doc """
  Returns a cause given a cause detail and a mode

  ## Examples
      iex> AlertsUI.Models.Cause.get_by_mode_and_detail(1, "")
      :UNKNOWN_CAUSE

      iex> AlertsUI.Models.Cause.get_by_mode_and_detail(nil, "SNOW")
      :WEATHER

      iex> AlertsUI.Models.Cause.get_by_mode_and_detail(0, "POWER_PROBLEM")
      :TECHNICAL_PROBLEM

      iex> AlertsUI.Models.Cause.get_by_mode_and_detail(1, "FIRE_DEPARTMENT_ACTIVITY")
      :OTHER_CAUSE

      iex> AlertsUI.Models.Cause.get_by_mode_and_detail(2, "FIRE_DEPARTMENT_ACTIVITY")
      :TECHNICAL_PROBLEM

      iex> AlertsUI.Models.Cause.get_by_mode_and_detail(3, "FIRE")
      :TECHNICAL_PROBLEM

      iex> AlertsUI.Models.Cause.get_by_mode_and_detail(4, "SEVERE_WEATHER")
      :WEATHER

      iex> AlertsUI.Models.Cause.get_by_mode_and_detail(:ACCESS, "ELECTRICAL_WORK")
      :MAINTENANCE
  """
  @spec get_by_mode_and_detail(integer() | nil | :ACCESS, String.t()) :: atom()
  def get_by_mode_and_detail(_mode, ""), do: :UNKNOWN_CAUSE

  def get_by_mode_and_detail(mode, detail) do
    cause_map_by_mode(mode) |> Map.get(detail)
  end

  @doc """
  Returns map between cause details and causes per mode (route type)

  ## Examples
      iex> is_map(AlertsUI.Models.Cause.cause_map_by_mode(nil))
      true

      iex> is_map(AlertsUI.Models.Cause.cause_map_by_mode(1))
      true

      iex> is_map(AlertsUI.Models.Cause.cause_map_by_mode(:ACCESS))
      true
  """
  @spec cause_map_by_mode(integer() | :ACCESS | nil) :: map()
  def cause_map_by_mode(mode) do
    case mode do
      nil ->
        # systemwide
        %{
          "HOLIDAY" => :HOLIDAY,
          "POLICE_ACTIVITY" => :POLICE_ACTIVITY,
          "SNOW" => :WEATHER,
          "SPECIAL_EVENT" => :OTHER_CAUSE,
          "WEATHER" => :WEATHER
        }

      m when m in [0, 1] ->
        %{
          "ACCIDENT" => :ACCIDENT,
          "CONSTRUCTION" => :CONSTRUCTION,
          "DISABLED_TRAIN" => :TECHNICAL_PROBLEM,
          "FIRE" => :TECHNICAL_PROBLEM,
          "FIRE_DEPARTMENT_ACTIVITY" => :OTHER_CAUSE,
          "FLOODING" => :WEATHER,
          "MAINTENANCE" => :MAINTENANCE,
          "MEDICAL_EMERGENCY" => :MEDICAL_EMERGENCY,
          "POLICE_ACTIVITY" => :POLICE_ACTIVITY,
          "POWER_PROBLEM" => :TECHNICAL_PROBLEM,
          "SIGNAL_PROBLEM" => :TECHNICAL_PROBLEM,
          "SINGLE_TRACKING" => :MAINTENANCE,
          "SNOW" => :WEATHER,
          "SPECIAL_EVENT" => :OTHER_CAUSE,
          "SWITCH_PROBLEM" => :TECHNICAL_PROBLEM,
          "TRACK_PROBLEM" => :TECHNICAL_PROBLEM,
          "TRACK_WORK" => :MAINTENANCE,
          "TRAFFIC" => :OTHER_CAUSE,
          "WEATHER" => :WEATHER
        }

      2 ->
        %{
          "AMTRAK_TRAIN_TRAFFIC" => :OTHER_CAUSE,
          "CROSSING_ISSUE" => :TECHNICAL_PROBLEM,
          "FIRE_DEPARTMENT_ACTIVITY" => :TECHNICAL_PROBLEM,
          "FREIGHT_TRAIN_INTERFERENCE" => :OTHER_CAUSE,
          "HEAVY_RIDERSHIP" => :OTHER_CAUSE,
          "HOLIDAY" => :HOLIDAY,
          "MAINTENANCE" => :MAINTENANCE,
          "MECHANICAL_ISSUE" => :TECHNICAL_PROBLEM,
          "MEDICAL_EMERGENCY" => :MEDICAL_EMERGENCY,
          "POLICE_ACTIVITY" => :POLICE_ACTIVITY,
          "RAIL_DEFECT" => :TECHNICAL_PROBLEM,
          "SIGNAL_ISSUE" => :TECHNICAL_PROBLEM,
          "SLIPPERY_RAIL" => :WEATHER,
          "SNOW" => :WEATHER,
          "SPEED_RESTRICTION" => :OTHER_CAUSE,
          "SWITCH_ISSUE" => :TECHNICAL_PROBLEM,
          "TIE_REPLACEMENT" => :MAINTENANCE,
          "TRACK_WORK" => :CONSTRUCTION,
          "TRAIN_TRAFFIC" => :OTHER_CAUSE,
          "UNRULY_PASSENGER" => :POLICE_ACTIVITY
        }

      3 ->
        %{
          "ACCIDENT" => :ACCIDENT,
          "CONSTRUCTION" => :CONSTRUCTION,
          "DEMONSTRATION" => :DEMONSTRATION,
          "DISABLED_BUS" => :TECHNICAL_PROBLEM,
          "DRAWBRIDGE_BEING_RAISED" => :OTHER_CAUSE,
          "ELECTRICAL_WORK" => :MAINTENANCE,
          "FIRE" => :TECHNICAL_PROBLEM,
          "HAZMAT_CONDITION" => :OTHER_CAUSE,
          "HOLIDAY" => :HOLIDAY,
          "HURRICANE" => :WEATHER,
          "MAINTENANCE" => :MAINTENANCE,
          "MEDICAL_EMERGENCY" => :MEDICAL_EMERGENCY,
          "PARADE" => :OTHER_CAUSE,
          "POLICE_ACTIVITY" => :POLICE_ACTIVITY,
          "SNOW" => :WEATHER,
          "SPECIAL_EVENT" => :OTHER_CAUSE,
          "TIE_REPLACEMENT" => :MAINTENANCE,
          "TRAFFIC" => :OTHER_CAUSE,
          "WEATHER" => :WEATHER
        }

      4 ->
        %{
          "ACCIDENT" => :ACCIDENT,
          "COAST_GUARD_RESTRICTION" => :OTHER_CAUSE,
          "FIRE" => :TECHNICAL_PROBLEM,
          "FOG" => :WEATHER,
          "HIGH_WINDS" => :WEATHER,
          "HOLIDAY" => :HOLIDAY,
          "ICE_IN_HARBOR" => :WEATHER,
          "MAINTENANCE" => :MAINTENANCE,
          "MECHANICAL_PROBLEM" => :TECHNICAL_PROBLEM,
          "MEDICAL_EMERGENCY" => :MEDICAL_EMERGENCY,
          "POLICE_ACTIVITY" => :POLICE_ACTIVITY,
          "SEVERE_WEATHER" => :WEATHER
        }

      :ACCESS ->
        %{
          "CONSTRUCTION" => :CONSTRUCTION,
          "ELECTRICAL_WORK" => :MAINTENANCE,
          "FIRE" => :TECHNICAL_PROBLEM,
          "MAINTENANCE" => :MAINTENANCE
        }
    end
  end
end
