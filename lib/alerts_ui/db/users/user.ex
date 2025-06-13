defmodule AlertsUI.DB.User do
  @moduledoc """
  The User schema.
  """
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUI.Models.Alert

  schema "users" do
    field :email, :string
    field :first_name, :string
    field :last_name, :string
    field :role, Ecto.Enum, values: [:user, :admin]
    has_many :alerts, Alert, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :first_name, :last_name, :role])
    |> validate_required([:email, :first_name, :last_name, :role])
    |> unique_constraint(:email)
  end
end
