defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.Validation do
  import Ecto.Changeset, only: [get_field: 2, add_error: 3]

  @missing [nil, "", []]

  def always_validate_required(changeset, field, message) do
    case get_field(changeset, field) do
      missing when missing in @missing -> add_error(changeset, field, message) |> IO.inspect(label: "CH")
      _ -> changeset
    end
  end
end
