defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.Validation do
  import Ecto.Changeset, only: [get_field: 2, add_error: 3]

  @missing [nil, "", []]

  def always_validate_required(changeset, fields) when is_map(fields) do
    # takes a map of fields and messages eg (%{header_text: "can't be blank"})
    Enum.reduce(fields, changeset, fn {field, message}, acc ->
      always_validate_required(acc, field, message)
    end)
  end

  def always_validate_required(changeset, field, message) do
    case get_field(changeset, field) do
      missing when missing in @missing -> add_error(changeset, field, message)
      _ -> changeset
    end
  end
end
