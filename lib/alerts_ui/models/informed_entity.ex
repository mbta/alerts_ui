defmodule AlertsUI.Models.InformedEntity do
  @moduledoc """
    Models an Informed Entity
  """
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUI.Models.{Activity, Alert, TripDescriptor}

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
end
