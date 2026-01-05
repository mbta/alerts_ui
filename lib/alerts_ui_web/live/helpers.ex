defmodule AlertsUIWeb.Helpers do
  @moduledoc """
  Other generic frontend helpers
  """
  def is_viewer?(%{roles: roles}) do
    :viewer in roles
  end
  def is_viewer?(_), do: false

  def is_author?(%{roles: roles}) do
    :author in roles
  end
  def is_author?(_), do: false
end
