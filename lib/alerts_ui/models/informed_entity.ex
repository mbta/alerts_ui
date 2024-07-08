defmodule AlertsUI.Models.InformedEntity do
  @moduledoc """
    Models an Informed Entity
  """
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUI.Models.{Activity, Alert, TripDescriptor}
  alias MBTAV3API.Routes.Route

  @facility_activities [
    :bringing_bike,
    :park_car,
    :store_bike,
    :using_escalator,
    :using_wheelchair
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
  Map route type names to integer codes.

    ## Examples
      iex> InformedEntity.route_type_mapping("Light Rail")
      0
  """
  @spec route_type_mapping(String.t()) :: Route.type_int() | nil
  def route_type_mapping("Light Rail"), do: 0
  def route_type_mapping("Subway"), do: 1
  def route_type_mapping("Commuter Rail"), do: 2
  def route_type_mapping("Bus"), do: 3
  def route_type_mapping("Ferry"), do: 4
  def route_type_mapping(_), do: nil

  @doc """
  Map route type codes to service type names.

    ## Examples
      iex> InformedEntity.route_code_mapping(0)
      "Light Rail"
  """
  @spec route_code_mapping(Route.type_int()) :: String.t() | nil
  def route_code_mapping(0), do: "Light Rail"
  def route_code_mapping(1), do: "Subway"
  def route_code_mapping(2), do: "Commuter Rail"
  def route_code_mapping(3), do: "Bus"
  def route_code_mapping(4), do: "Ferry"
  def route_code_mapping(_), do: nil

  @spec route_to_combo_route_mapping() :: %{String.t() => String.t()}
  def route_to_combo_route_mapping do
    %{
      "24" => "2427",
      "27" => "2427",
      "32" => "3233",
      "33" => "3233",
      "37" => "3738",
      "38" => "3738",
      "40" => "4050",
      "50" => "4050",
      "62" => "627",
      "76" => "627",
      "72" => "725",
      "75" => "725",
      "89" => "8993",
      "93" => "8993",
      "116" => "116117",
      "117" => "116117",
      "214" => "214216",
      "216" => "214216",
      "441" => "441442",
      "442" => "441442",
      "741" => "746",
      "742" => "746",
      "743" => "746",
      "Green-E" => "602"
    }
  end
end
