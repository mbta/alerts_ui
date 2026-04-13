defmodule AlertsUIWeb.UserHelpers do
  @moduledoc """
  Other generic frontend helpers related to users
  """
  def developer?(%{roles: roles}) do
    :developer in roles
  end

  def developer?(_), do: false

  def author?(%{roles: roles}) do
    :author in roles
  end

  def author?(_), do: false
end
