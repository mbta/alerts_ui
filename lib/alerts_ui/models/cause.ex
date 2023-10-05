defmodule AlertsUI.Models.Cause do
  @moduledoc """
    Causes to be used in the cause field of Alerts
  """
  use AlertsUI.Schema

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "causes" do
    field :name, :string
    timestamps()
  end
end
