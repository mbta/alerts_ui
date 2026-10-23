defmodule AlertsUI.Models.InformedEntity do
  @moduledoc """
    Models an Informed Entity
  """
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUI.Models.{Activity, Alert, TripDescriptor}
  alias AlertsUIWeb.Helpers.EffectsForRouteTypes
  alias MBTAV3API.Routes.Route

  @facility_activities [
    :bringing_bike,
    :park_car,
    :store_bike,
    :using_escalator,
    :using_wheelchair
  ]

  @all_facility_types [
    "BIKE_STORAGE",
    "ELECTRIC_CAR_CHARGERS",
    "ELEVATED_SUBPLATFORM",
    "ELEVATOR",
    "ESCALATOR",
    "FARE_MEDIA_ASSISTANCE_FACILITY",
    "FARE_MEDIA_ASSISTANT",
    "FARE_VENDING_MACHINE",
    "FARE_VENDING_RETAILER",
    "FULLY_ELEVATED_PLATFORM",
    "PARKING_AREA",
    "PICK_DROP",
    "PORTABLE_BOARDING_LIFT",
    "RAMP",
    "TICKET_WINDOW"
  ]

  @activity Activity.activities()

  @permitted_fields ~w(alert_id route_id facility_id direction_id agency_id route_type stop_id activities)a

  @type t :: %__MODULE__{
          id: Ecto.UUID,
          alert_id: Ecto.UUID,
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          agency_id: String.t() | nil,
          route_id: String.t() | nil,
          facility_id: String.t() | nil,
          route_type: Route.type_int() | nil,
          direction_id: integer() | nil,
          stop_id: String.t() | nil,
          activities: [atom()] | nil,
          trip: TripDescriptor.t() | nil
        }

  @type mode_atom_t() :: :light_rail | :subway | :commuter_rail | :bus | :ferry | :access
  schema "informed_entities" do
    belongs_to :alert, Alert
    field :agency_id, :string
    field :route_id, :string
    field :facility_id, :string
    field :route_type, :integer
    field :direction_id, :integer
    field :stop_id, :string
    field :activities, {:array, Ecto.Enum}, values: @activity
    has_one :trip, TripDescriptor
    timestamps()
  end

  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = informed_entity, params) do
    # informed entity must have at least one field
    # per GTFS spec
    informed_entity
    |> cast(params, @permitted_fields)
    |> cast_assoc(:trip, required: false, with: &TripDescriptor.changeset/2)
    |> validate_subset(:activities, @activity)
    |> case do
      %{changes: changes} = changeset when changes == %{} ->
        add_error(changeset, :agency_id, "at least one field must be present")

      changeset ->
        changeset
    end
  end

  @doc """
  The Route ID for this Informed Entity

    ## Examples
      iex> InformedEntity.route_id(%InformedEntity{route_id: "1"})
      "1"
      iex> InformedEntity.route_id(%InformedEntity{})
      nil
  """
  @spec route_id(t()) :: String.t() | nil
  def route_id(%__MODULE__{route_id: route_id}), do: route_id

  @doc """
  Whether this Informed Entity contains a Route ID

    ## Examples
      iex> InformedEntity.route_id?(%InformedEntity{route_id: "1"})
      true
      iex> InformedEntity.route_id?(%InformedEntity{})
      false
  """
  @spec route_id?(t()) :: boolean()
  def route_id?(%__MODULE__{route_id: route_id}), do: !is_nil(route_id)

  @doc """
  The route type for this Informed Entity

    ## Examples
      iex> InformedEntity.route_type(%InformedEntity{route_type: 3})
      3
      iex> InformedEntity.route_type(%InformedEntity{})
      nil
  """
  @spec route_type(t()) :: Route.type_int() | nil
  def route_type(%__MODULE__{route_type: route_type}), do: route_type

  @spec facility_activities :: [atom()]
  def facility_activities, do: @facility_activities

  @spec facility_activity?(atom()) :: boolean()
  def facility_activity?(activity) when activity in @facility_activities, do: true
  def facility_activity?(_), do: false

  @doc """
  Map facility effects to their types

  ## Examples
    iex> InformedEntity.facility_effect_to_types(:BIKE_ISSUE)
    ["BIKE_STORAGE"]
  """
  @spec facility_effect_to_types(atom()) :: [String.t()]
  def facility_effect_to_types(nil), do: nil

  def facility_effect_to_types(type) when is_binary(type) do
    facility_effect_to_types(String.to_existing_atom(type))
  end

  def facility_effect_to_types(:ACCESS_ISSUE),
    do: @all_facility_types -- ["ELEVATOR", "ESCALATOR"]

  def facility_effect_to_types(:FACILITY_ISSUE),
    do: @all_facility_types -- ["ELEVATOR", "ESCALATOR"]

  def facility_effect_to_types(:BIKE_ISSUE), do: ["BIKE_STORAGE"]
  def facility_effect_to_types(:ELEVATOR_CLOSURE), do: ["ELEVATOR"]
  def facility_effect_to_types(:ESCALATOR_CLOSURE), do: ["ESCALATOR"]
  def facility_effect_to_types(:PARKING_CLOSURE), do: ["PARKING_AREA", "PICK_DROP"]
  def facility_effect_to_types(:PARKING_ISSUE), do: ["PARKING_AREA", "PICK_DROP"]
  def facility_effect_to_types(_effect), do: []

  def all_facility_types, do: @all_facility_types

  @doc """
  Map route type atoms to integer codes.

    ## Examples
      iex> InformedEntity.route_type_mapping(:light_rail)
      0
  """
  @spec route_type_mapping(String.t() | mode_atom_t()) :: Route.type_int() | nil
  def route_type_mapping("light_rail"), do: 0
  def route_type_mapping("subway"), do: 1
  def route_type_mapping("commuter_rail"), do: 2
  def route_type_mapping("bus"), do: 3
  def route_type_mapping("ferry"), do: 4
  def route_type_mapping("facility"), do: nil
  def route_type_mapping("systemwide"), do: nil
  def route_type_mapping(:light_rail), do: 0
  def route_type_mapping(:subway), do: 1
  def route_type_mapping(:commuter_rail), do: 2
  def route_type_mapping(:bus), do: 3
  def route_type_mapping(:ferry), do: 4
  def route_type_mapping(_), do: nil

  @doc """
  Map route type codes to service type stoms.

    ## Examples
      iex> InformedEntity.route_code_mapping(0)
      :light_rail
  """
  @spec route_code_mapping(Route.type_int() | nil, String.t() | nil) :: atom()
  def route_code_mapping(code, effect \\ nil)
  def route_code_mapping(0, _effect), do: :light_rail
  def route_code_mapping(1, _effect), do: :subway
  def route_code_mapping(2, _effect), do: :commuter_rail
  def route_code_mapping(3, _effect), do: :bus
  def route_code_mapping(4, _effect), do: :ferry

  def route_code_mapping(nil, effect) do
    if effect in EffectsForRouteTypes.list_effects(:facility) do
      :facility
    else
      :systemwide
    end
  end

  @route_type_atoms [
    :access,
    :bus,
    :commuter_rail,
    :ferry,
    :light_rail,
    :subway,
    :facility,
    :systemwide
  ]

  @doc """
  Boolean for testing route type validity.
  """
  @spec valid_route_type?(mode_atom_t()) :: boolean()
  def valid_route_type?(mode_atom) do
    Enum.member?(@route_type_atoms, mode_atom)
  end
end
