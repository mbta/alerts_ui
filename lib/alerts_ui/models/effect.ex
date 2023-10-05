defmodule AlertsUI.Models.Effect do
  @moduledoc """
    Effects to be used in the effect field of Alerts
  """
  use AlertsUI.Schema

  @type t :: %__MODULE__{
          name: String.t()
        }

  schema "effects" do
    field :name, :string
    timestamps()
  end
end
