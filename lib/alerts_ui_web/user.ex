defmodule AlertsUIWeb.User do
  @moduledoc """
  Represents a user who's logged in to the site. All data comes from Keycloak.
  """

  defstruct [
    :id,
    :email,
    :first_name,
    :last_name,
    role: :user
  ]

  @type id :: String.t()
  @type role :: :user | :admin

  @type t :: %__MODULE__{
          id: String.t(),
          email: String.t(),
          first_name: String.t(),
          last_name: String.t(),
          role: role()
        }

  @doc """
  Create a new User struct.
  """
  @spec new(
          id :: id(),
          email :: String.t(),
          first_name :: String.t(),
          last_name :: String.t(),
          role :: role()
        ) :: t()
  def new(id, email, first_name, last_name, role \\ :user) do
    %__MODULE__{
      id: id,
      email: email,
      first_name: first_name,
      last_name: last_name,
      role: role
    }
  end

  @doc """
  Returns the ID for a user.

  iex> AlertsUIWeb.User.id(%AlertsUIWeb.User{id: "123", email: "user@example.com"})
  "123"
  """
  @spec id(t()) :: id()
  def id(%__MODULE__{id: id}), do: id
end
