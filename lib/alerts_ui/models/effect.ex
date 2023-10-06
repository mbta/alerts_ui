defmodule AlertsUI.Models.Effect do
  @moduledoc """
    Effects to be used in the effect field of Alerts
  """
  use AlertsUI.Schema

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "effects" do
    field :name, :string
    timestamps()
  end
end
