defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertData do
  import Ecto.Changeset, only: [get_field: 2]

  def alert_data_from_form(form, :route_type) do
    get_field(form.source, :route_type) |> String.to_existing_atom()
  end

  def alert_data_from_form(form, key) do
    get_field(form.source, key)
  end
end
