defmodule AlertsUI.Models.User do
  @moduledoc """
  The User schema. All data comes from Keycloak
  """
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUI.Models.Alert

  @type role :: :user | :admin

  @type t :: %__MODULE__{
          # User doesn't have an id until they create an alert
          # and are added to the DB
          id: Ecto.UUID | nil,
          keycloak_id: String.t(),
          email: String.t(),
          first_name: String.t(),
          last_name: String.t(),
          role: role()
        }

  schema "users" do
    field :email, :string
    field :keycloak_id, :string
    field :first_name, :string
    field :last_name, :string
    field :role, Ecto.Enum, values: [:user, :admin]
    has_many :alerts, Alert

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :keycloak_id, :first_name, :last_name, :role])
    |> validate_required([:email, :first_name, :last_name, :role])
    |> unique_constraint(:email)
  end

  @doc """
  Create a new User struct.
  """
  @spec new(
          keycloak_id :: String.t(),
          email :: String.t(),
          first_name :: String.t(),
          last_name :: String.t(),
          role :: role()
        ) :: t()
  def new(keycloak_id, email, first_name, last_name, role \\ :user) do
    %__MODULE__{
      id: nil,
      keycloak_id: keycloak_id,
      email: email,
      first_name: first_name,
      last_name: last_name,
      role: role
    }
  end

  @doc """
  Returns the Keycloak ID for a user.

  iex> AlertsUI.Models.User.keycloak_id(%AlertsUI.Models.User{keycloak_id: "123", email: "user@example.com"})
  "123"
  """
  @spec keycloak_id(t()) :: String.t()
  def keycloak_id(%__MODULE__{keycloak_id: keycloak_id}), do: keycloak_id
end
