defmodule AlertsUI.Models.TripDescriptor do
  @moduledoc """
    Models a Trip Descriptor
  """
  use AlertsUI.Schema
  alias AlertsUI.Models.{InformedEntity, ScheduleRelationship}

  @schedule_relationship ScheduleRelationship.schedule_relationships()

  @type t :: %__MODULE__{
          id: Ecto.UUID,
          informed_entity_id: Ecto.UUID,
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          trip_id: String.t() | nil,
          route_id: String.t() | nil,
          direction_id: integer() | nil,
          start_time: Time.t() | nil,
          start_date: Date.t() | nil,
          schedule_relationship: atom() | nil
        }

  schema "trip_descriptors" do
    belongs_to :informed_entity, InformedEntity
    field :trip_id, :string
    field :route_id, :string
    field :direction_id, :integer
    field :start_time, :time
    field :start_date, :date
    field :schedule_relationship, Ecto.Enum, values: @schedule_relationship
    timestamps()
  end
end
