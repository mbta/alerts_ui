defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertData do
  import Ecto.Changeset, only: [get_field: 2]

  @moduledoc """
  Helpers for dealing with alert data.
  """

  @doc """
  Get alert data from the changeset. Required (at least) by URL params.
  """
  def alert_data_from_form(form, :route_type) do
    case get_field(form.source, :route_type) do
      nil -> nil
      route_type -> String.to_existing_atom(route_type)
    end
  end

  def alert_data_from_form(form, key) do
    get_field(form.source, key)
  end

  def show_details?(form) do
    !is_nil(alert_data_from_form(form, :route_type)) &&
      !is_nil(alert_data_from_form(form, :effect_name))
  end
end
