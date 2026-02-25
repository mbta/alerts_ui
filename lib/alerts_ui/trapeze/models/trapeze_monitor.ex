defmodule AlertsUI.Trapeze.Models.TrapezeMonitor do
  @moduledoc """
  Monitor Model
  """
  use AlertsUI.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID | nil,
          checked_at: DateTime.t(),
          processed_at: DateTime.t(),
          work_order_changes: [String.t()],
          checksum: String.t(),
          result: String.t(),
          reason: String.t()
        }
  @fields [:checked_at, :processed_at, :work_order_changes, :checksum, :result, :reason]
  @required_fields [:checked_at, :work_order_changes, :result, :reason]

  schema "trapeze_monitors" do
    field :checked_at, :utc_datetime
    field :processed_at, :utc_datetime
    field :work_order_changes, {:array, :string}, default: []
    field :checksum, :string
    field :result, :string
    field :reason, :string

    timestamps()
  end

  @doc false
  def changeset(monitor, attrs) do
    monitor
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end
end
