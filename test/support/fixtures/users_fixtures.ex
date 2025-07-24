defmodule AlertsUI.UsersFixtures do
  @moduledoc """
  This module defines test helpers for creating users
  """

  alias AlertsUI.DBContexts.Users
  alias AlertsUI.Models.User

  @doc """
  Creates a User and inserts into DB
  """
  def create_db_user(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        keycloak_id: "123-456",
        email: unique_user_email(),
        first_name: "some first_name",
        last_name: "some last_name",
        role: :user
      })
      |> Users.create_user()

    user
  end

  @doc """
  Creates a User
  If you want to pass in a different name, you also have to pass in a role
  eg user_fixture(:user, %{first_name: "Dr", last_name: "Acula"})
  """
  def user_fixture(
        role \\ :user,
        %{first_name: first_name, last_name: last_name} \\ %{
          first_name: "Firstname",
          last_name: "Lastname"
        }
      ) do
    User.new(unique_user_id(), unique_user_email(), first_name, last_name, role)
  end

  defp unique_user_id, do: Ecto.UUID.generate()

  defp unique_user_email, do: "user#{System.unique_integer()}@example.com"
end
