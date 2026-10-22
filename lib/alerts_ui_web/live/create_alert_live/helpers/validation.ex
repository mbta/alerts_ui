defmodule AlertsUIWeb.CreateAlertLive.Helpers.Validation do
  @moduledoc """
  Shared changeset validation helpers for the alert creation form. Provides
  `always_validate_required/3` which adds an error whenever a field is nil, empty
  string, or empty list — regardless of whether the field appears in changeset changes.
  """

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
