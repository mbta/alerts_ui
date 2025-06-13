defmodule AlertsUI.DBUsersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `AlertsUI.DB.Users` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "some email",
        first_name: "some first_name",
        last_name: "some last_name",
        role: :user
      })
      |> AlertsUI.DB.Users.create_user()

    user
  end
end
