defmodule AlertsUI.Models.EffectMapping do
  @moduledoc "Describe a map of all aspects of an effect"
  defstruct [:effect_name, :effect, :effect_detail]
end

defmodule AlertsUI.Models.Effect do
  @moduledoc """
    Effects to be used in the effect field of Alerts.
  """
  alias AlertsUI.Models.EffectMapping

  @doc """
  Returns list of atoms allowed in effect field of alert

  ## Examples
      iex> is_list(AlertsUI.Models.Effect.effects)
      true
  """
  def effects,
    do: [
      :ACCESSIBILITY_ISSUE,
      :ADDITIONAL_SERVICE,
      :DETOUR,
      :MODIFIED_SERVICE,
      :NO_EFFECT,
      :NO_SERVICE,
      :OTHER_EFFECT,
      :REDUCED_SERVICE,
      :SIGNIFICANT_DELAYS,
      :STOP_MOVED,
      :UNKNOWN_EFFECT
    ]

  @doc """
  Returns list of effect details

  ## Examples
      iex> is_list(AlertsUI.Models.Effect.effect_details)
      true
  """
  def effect_details do
    effects_tuples()
    |> Enum.map(fn {_n, _e, detail} -> detail end)
  end

  @doc """
  Returns list of effect names

  ## Examples
      iex> is_list(AlertsUI.Models.Effect.effect_names)
      true
  """
  @spec effect_names() :: [String.t()]
  def effect_names do
    effects_tuples()
    |> Enum.map(fn {name, _e, _d} -> name end)
  end

  @spec effect_map_by_name(String.t()) :: struct()
  @doc """
  Returns effect mapping given a name

  ## Examples
      iex> AlertsUI.Models.Effect.effect_map_by_name("Multi-Route Detour")
      %AlertsUI.Models.EffectMapping{effect_name: "Multi-Route Detour", effect: :DETOUR, effect_detail: "DETOUR"}
  """
  def effect_map_by_name(nil), do: %{}

  def effect_map_by_name(search_name) do
    matching_tuple =
      effects_tuples()
      |> Enum.filter(fn {name, _e, _d} -> name == search_name end)
      |> Enum.at(0)

    case matching_tuple do
      {effect_name, effect, effect_detail} ->
        struct(EffectMapping, %{
          effect_name: effect_name,
          effect: effect,
          effect_detail: effect_detail
        })

      _ ->
        %{}
    end
  end

  @spec effect_map_by_detail(String.t() | nil) :: struct() | map() | nil
  @doc """
  Returns effect mapping given a detail. Returns nil if detail is not listed.

  ## Examples
      iex> AlertsUI.Models.Effect.effect_map_by_detail("FACILITY_ISSUE")
      %AlertsUI.Models.EffectMapping{effect_name: "Facility Issue", effect: :OTHER_EFFECT, effect_detail: "FACILITY_ISSUE"}

      iex> AlertsUI.Models.Effect.effect_map_by_detail("BAD_DETAIL")
      nil
  """
  def effect_map_by_detail(nil), do: %{}

  def effect_map_by_detail(search_detail) do
    tuples_list =
      effects_tuples()
      |> Enum.filter(fn {_n, _e, detail} -> detail == search_detail end)

    case tuples_list do
      [_ | _] ->
        {effect_name, effect, effect_detail} = hd(tuples_list)

        struct(EffectMapping, %{
          effect_name: effect_name,
          effect: effect,
          effect_detail: effect_detail
        })

      _ ->
        nil
    end
  end

  @type effect_name :: String.t()
  @type effect :: atom()
  @type effect_detail :: String.t()
  @type effects_tuple ::
          {effect_name :: effect_name(), effect :: effect(), effect_detail :: effect_detail()}

  @spec effects_tuples() :: [effects_tuple()]
  def effects_tuples do
    [
      {"Access Issue", :ACCESSIBILITY_ISSUE, "ACCESS_ISSUE"},
      {"Amber Alert", :UNKNOWN_EFFECT, "AMBER_ALERT"},
      {"Bike Issue", :OTHER_EFFECT, "BIKE_ISSUE"},
      {"Cancellation", :NO_SERVICE, "CANCELLATION"},
      {"Delay", :SIGNIFICANT_DELAYS, "DELAY"},
      {"Detour", :DETOUR, "DETOUR"},
      {"Dock Closure", :NO_SERVICE, "DOCK_CLOSURE"},
      {"Dock Issue", :UNKNOWN_EFFECT, "DOCK_ISSUE"},
      {"Elevator Closure", :ACCESSIBILITY_ISSUE, "ELEVATOR_CLOSURE"},
      {"Escalator Closure", :ACCESSIBILITY_ISSUE, "ESCALATOR_CLOSURE"},
      {"Extra Service", :ADDITIONAL_SERVICE, "EXTRA_SERVICE"},
      {"Facility Issue", :OTHER_EFFECT, "FACILITY_ISSUE"},
      {"Multi-Route Detour", :DETOUR, "DETOUR"},
      {"Parking Closure", :OTHER_EFFECT, "PARKING_CLOSURE"},
      {"Parking Issue", :OTHER_EFFECT, "PARKING_ISSUE"},
      {"Policy Change", :OTHER_EFFECT, "POLICY_CHANGE"},
      {"Schedule Change", :MODIFIED_SERVICE, "SCHEDULE_CHANGE"},
      {"Service Change", :UNKNOWN_EFFECT, "SERVICE_CHANGE"},
      {"Shuttle", :DETOUR, "SHUTTLE"},
      {"Single Tracking", :REDUCED_SERVICE, "DELAY"},
      {"Snow Route", :DETOUR, "SNOW_ROUTE"},
      {"Station Bypass", :NO_SERVICE, "STATION_CLOSURE"},
      {"Station Closure", :NO_SERVICE, "STATION_CLOSURE"},
      {"Station Issue", :UNKNOWN_EFFECT, "STATION_ISSUE"},
      {"Stop Closure", :NO_SERVICE, "STOP_CLOSURE"},
      {"Stop Move", :STOP_MOVED, "STOP_MOVE"},
      {"Stop Shoveling", :OTHER_EFFECT, "STOP_SHOVELING"},
      {"Summary", :OTHER_EFFECT, "SUMMARY"},
      {"Suspension", :DETOUR, "SUSPENSION"},
      {"Track Change", :OTHER_EFFECT, "TRACK_CHANGE"}
    ]
  end
end
