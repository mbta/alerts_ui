defmodule AlertsUI.Models.InformedEntity do
  @moduledoc """
    Models an Informed Entity
  """
  use AlertsUI.Schema
  alias AlertsUI.Models.{Activity, Alert, TripDescriptor}

  @activity Activity.activities()

  @type t :: %__MODULE__{
          id: Ecto.UUID,
          alert_id: Ecto.UUID,
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          agency_id: String.t() | nil,
          route_id: String.t() | nil,
          route_type: integer() | nil,
          direction_id: integer() | nil,
          stop_id: String.t() | nil,
          activities: [atom()] | nil,
          trip: TripDescriptor | nil
        }

  schema "informed_entities" do
    belongs_to :alert, Alert
    field :agency_id, :string
    field :route_id, :string
    field :route_type, :integer
    field :direction_id, :integer
    field :stop_id, :string
    field :activities, {:array, Ecto.Enum}, values: @activity
    has_one :trip, TripDescriptor
    timestamps()
  end
end
