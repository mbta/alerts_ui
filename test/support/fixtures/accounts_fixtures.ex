defmodule AlertsUI.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `AlertsUI.Accounts` context.
  """

  alias AlertsUIWeb.User

  def user_fixture(role \\ :user) do
    User.new(unique_user_id(), unique_user_email(), role)
  end

  defp unique_user_id, do: Ecto.UUID.generate()

  defp unique_user_email, do: "user#{System.unique_integer()}@example.com"
end
