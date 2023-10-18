defmodule AlertsUI.Alerts do
  @moduledoc """
    Functions for working with alerts in the database
  """
  import Ecto.Changeset
  import Ecto.Query
  alias AlertsUI.Models.Alert
  alias AlertsUI.Repo
  require Logger

  @spec create_alert(map()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def create_alert(alert) do
    # this is temporarily filtering out duplicate alerts
    # To do-  only insert duplicate alerts if last modified timestamp is unique?
    result =
      Alert.create_changeset(%Alert{}, alert)
      |> unsafe_validate_unique(:alert_id, Repo)
      |> Repo.insert()

    case result do
      {:error,
       %Ecto.Changeset{
         errors: [alert_id: {"has already been taken", _}]
       } = _changeset} ->
        nil

      {:error, changeset} ->
        Logger.warning("Error persisting alert with ID #{get_field(changeset, :alert_id)}")
        traverse_errors(changeset, fn {msg, _} -> msg end) |> Logger.warning()

      {:ok, _} ->
        nil
    end

    result
  end

  def list_all_versions_of_alert(alert) when is_struct(alert) do
    list_all_versions_of_alert(alert.alert_id)
  end

  def list_all_versions_of_alert(alert_id) do
    Repo.all(
      from(
        a in Alert,
        where: a.alert_id == ^alert_id,
        order_by: [desc: a.created_timestamp],
        preload: [informed_entity: [:trip]]
      )
    )
  end

  def list_all_alerts do
    Repo.all(
      from(
        a in Alert,
        preload: [informed_entity: [:trip]]
      )
    )
  end
end
