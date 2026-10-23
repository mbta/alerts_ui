defmodule AlertsUIWeb.CreateAlertLive.Helpers.Value do
  @moduledoc """
  Helpers for formatting generic values
  """

  def blank?(nil), do: true
  def blank?(""), do: true
  def blank?(_), do: false
end
