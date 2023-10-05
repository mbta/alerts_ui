defmodule AlertsUI.Models.Effect do
  @moduledoc """
    Effects to be used in the effect field of Alerts
  """
  use AlertsUI.Schema

  schema "effects" do
    field :name, :string
    timestamps()
  end
end
