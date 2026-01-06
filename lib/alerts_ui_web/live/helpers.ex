defmodule AlertsUIWeb.Helpers do
  @moduledoc """
  Other generic frontend helpers
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
