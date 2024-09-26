defmodule AlertsUI.Models.ReminderTime do
  @moduledoc """
    Models a reminder time
  """
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUI.Models.Alert

  @permitted_fields ~w(reminder_time)a

  @type t :: %__MODULE__{
          id: Ecto.UUID,
          alert_id: Ecto.UUID,
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          reminder_time: DateTime.t()
        }

  schema "reminder_times" do
    belongs_to :alert, Alert
    field :reminder_time, :utc_datetime
    timestamps()
  end

  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = reminder_time, params) do
    reminder_time
    |> cast(params, @permitted_fields)
    |> assoc_constraint(:alert)
  end
end
