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

      iex> AlertsUI.Models.Cause.get_by_mode_and_detail(nil, "snow")
      :WEATHER

      iex> AlertsUI.Models.Cause.get_by_mode_and_detail(0, "power problem")
      :TECHNICAL_PROBLEM

      iex> AlertsUI.Models.Cause.get_by_mode_and_detail(1, "fire department activity")
      :OTHER_CAUSE

      iex> AlertsUI.Models.Cause.get_by_mode_and_detail(2, "fire department activity")
      :TECHNICAL_PROBLEM

      iex> AlertsUI.Models.Cause.get_by_mode_and_detail(3, "fire")
      :TECHNICAL_PROBLEM

      iex> AlertsUI.Models.Cause.get_by_mode_and_detail(4, "severe weather")
      :WEATHER

      iex> AlertsUI.Models.Cause.get_by_mode_and_detail(:ACCESS, "electrical work")
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
  def cause_map_by_mode(nil) do
    # systemwide
    %{
      "holiday" => :HOLIDAY,
      "police activity" => :POLICE_ACTIVITY,
      "snow" => :WEATHER,
      "special event" => :OTHER_CAUSE,
      "weather" => :WEATHER
    }
  end

  def cause_map_by_mode(0), do: cause_map_by_mode(1)

  def cause_map_by_mode(1) do
    %{
      "accident" => :ACCIDENT,
      "construction" => :CONSTRUCTION,
      "disabled train" => :TECHNICAL_PROBLEM,
      "fire" => :TECHNICAL_PROBLEM,
      "fire department activity" => :OTHER_CAUSE,
      "flooding" => :WEATHER,
      "maintenance" => :MAINTENANCE,
      "medical emergency" => :MEDICAL_EMERGENCY,
      "police activity" => :POLICE_ACTIVITY,
      "power problem" => :TECHNICAL_PROBLEM,
      "signal problem" => :TECHNICAL_PROBLEM,
      "snow" => :WEATHER,
      "special event" => :OTHER_CAUSE,
      "switch problem" => :TECHNICAL_PROBLEM,
      "track problem" => :TECHNICAL_PROBLEM,
      "track work" => :MAINTENANCE,
      "traffic" => :OTHER_CAUSE,
      "weather" => :WEATHER
    }
  end

  def cause_map_by_mode(2) do
    %{
      "Amtrak train traffic" => :OTHER_CAUSE,
      "crossing issue" => :TECHNICAL_PROBLEM,
      "fire department activity" => :TECHNICAL_PROBLEM,
      "freight train interference" => :OTHER_CAUSE,
      "heavy ridership" => :OTHER_CAUSE,
      "holiday" => :HOLIDAY,
      "maintenance" => :MAINTENANCE,
      "mechanical issue" => :TECHNICAL_PROBLEM,
      "medical emergency" => :MEDICAL_EMERGENCY,
      "police activity" => :POLICE_ACTIVITY,
      "rail defect" => :TECHNICAL_PROBLEM,
      "signal issue" => :TECHNICAL_PROBLEM,
      "slippery rail" => :WEATHER,
      "snow" => :WEATHER,
      "speed restriction" => :OTHER_CAUSE,
      "switch issue" => :TECHNICAL_PROBLEM,
      "tie replacement" => :MAINTENANCE,
      "track work" => :CONSTRUCTION,
      "train traffic" => :OTHER_CAUSE,
      "unruly passenger" => :POLICE_ACTIVITY
    }
  end

  def cause_map_by_mode(3) do
    %{
      "accident" => :ACCIDENT,
      "construction" => :CONSTRUCTION,
      "demonstration" => :DEMONSTRATION,
      "disabled bus" => :TECHNICAL_PROBLEM,
      "drawbridge being raised" => :OTHER_CAUSE,
      "electrical work" => :MAINTENANCE,
      "fire" => :TECHNICAL_PROBLEM,
      "hazmat condition" => :OTHER_CAUSE,
      "holiday" => :HOLIDAY,
      "hurricane" => :WEATHER,
      "maintenance" => :MAINTENANCE,
      "medical emergency" => :MEDICAL_EMERGENCY,
      "parade" => :OTHER_CAUSE,
      "police activity" => :POLICE_ACTIVITY,
      "snow" => :WEATHER,
      "special event" => :OTHER_CAUSE,
      "tie replacement" => :MAINTENANCE,
      "traffic" => :OTHER_CAUSE,
      "weather" => :WEATHER
    }
  end

  def cause_map_by_mode(4) do
    %{
      "accident" => :ACCIDENT,
      "Coast Guard restriction" => :OTHER_CAUSE,
      "fire" => :TECHNICAL_PROBLEM,
      "fog" => :WEATHER,
      "high winds" => :WEATHER,
      "holiday" => :HOLIDAY,
      "ice in harbor" => :WEATHER,
      "maintenance" => :MAINTENANCE,
      "mechanical problem" => :TECHNICAL_PROBLEM,
      "medical emergency" => :MEDICAL_EMERGENCY,
      "police activity" => :POLICE_ACTIVITY,
      "severe weather" => :WEATHER
    }
  end

  def cause_map_by_mode(:ACCESS) do
    %{
      "construction" => :CONSTRUCTION,
      "electrical work" => :MAINTENANCE,
      "fire" => :TECHNICAL_PROBLEM,
      "maintenance" => :MAINTENANCE
    }
  end
end
