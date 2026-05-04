defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertData do
  alias AlertsUI.Models.Alert

  import Ecto.Changeset, only: [get_field: 2]

  @moduledoc """
  Helpers for dealing with alert data.
  """

  @doc """
  Get alert data from the changeset. Used for passing data as props,
  as `form[:field]` gives you a field struct rather than an actual value.
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

  def get_route_type(nil), do: nil
  def get_route_type("access"), do: nil
  def get_route_type("systemwide"), do: nil

  def get_route_type(%Alert{} = alert) do
    get_route_type(alert.primary_service_type)
  end

  def get_route_type(route_type_string_int) do
    String.to_integer(route_type_string_int)
  end
end
