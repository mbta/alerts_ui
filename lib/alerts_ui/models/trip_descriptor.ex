defmodule AlertsUI.Models.TripDescriptor do
  @moduledoc """
    Models a Trip Descriptor
  """
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUI.Models.{ExtendedTime, InformedEntity, ScheduleRelationship}

  @schedule_relationship ScheduleRelationship.schedule_relationships()

  @permitted_fields ~w(informed_entity_id trip_id route_id direction_id schedule_relationship)a

  @type t :: %__MODULE__{
          id: Ecto.UUID,
          informed_entity_id: Ecto.UUID,
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          trip_id: String.t() | nil,
          route_id: String.t() | nil,
          direction_id: integer() | nil,
          start_time: ExtendedTime.t() | nil,
          start_date: Date.t() | nil,
          schedule_relationship: atom() | nil
        }

  schema "trip_descriptors" do
    belongs_to :informed_entity, InformedEntity
    field :trip_id, :string
    field :route_id, :string
    field :direction_id, :integer
    embeds_one :start_time, ExtendedTime
    field :start_date, :date
    field :schedule_relationship, Ecto.Enum, values: @schedule_relationship
    timestamps()
  end

  @spec new(any) :: struct
  def new(fields) do
    struct!(__MODULE__, fields)
  end

  @spec create_changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = trip, params) do
    trip
    |> cast(params, @permitted_fields)
    |> validate_inclusion(:schedule_relationship, @schedule_relationship)
    |> cast_embed(:start_time, required: false, with: &ExtendedTime.changeset/2)
    |> assoc_constraint(:informed_entity)
    |> validate_trip_rules(params)
  end

  @spec validate_trip_rules(Ecto.Changeset.t(), map) :: Ecto.Changeset.t()
  def validate_trip_rules(changeset, params) do
    # Per the GTFS spec, trip descriptors must have either a trip_id or all of:
    # route_id, direction_id, start_time, and a schedule_relationship equal to :SCHEDULED

    case Map.get(params, :trip_id) |> is_nil do
      true ->
        changeset
        |> validate_required([:route_id, :direction_id, :start_time, :schedule_relationship])
        |> validate_inclusion(:schedule_relationship, [:SCHEDULED])

      false ->
        changeset
        |> validate_required([:trip_id])
    end
  end
end
