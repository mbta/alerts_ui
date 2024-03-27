defmodule AlertsUI.Models.InformedEntity do
  @moduledoc """
    Models an Informed Entity
  """
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUI.Models.{Activity, Alert, TripDescriptor}

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
          route_type: integer() | nil,
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

  @spec facility_activities :: [atom()]
  def facility_activities, do: @facility_activities

  @spec facility_activity?(atom()) :: boolean()
  def facility_activity?(activity) when activity in @facility_activities, do: true
  def facility_activity?(_), do: false

  def route_type_mapping do
    %{
      "Light Rail" => 0,
      "Subway" => 1,
      "Commuter Rail" => 2,
      "Bus" => 3,
      "Ferry" => 4
    }
  end

  def route_type_mapping_from_integer do
    %{
      0 => "Light Rail",
      1 => "Subway",
      2 => "Commuter Rail",
      3 => "Bus",
      4 => "Ferry"
    }
  end

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
