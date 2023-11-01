defmodule AlertsUI.Alerts do
  @moduledoc """
    Context for working with alerts in the database
  """
  import Ecto.Changeset
  import Ecto.Query
  alias AlertsUI.Models.Alert
  alias AlertsUI.Repo
  require Logger

  @spec create_alert(map()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def create_alert(alert) do
    result =
      Alert.create_changeset(%Alert{}, alert)
      |> Repo.insert()

    case result do
      {:error, changeset} ->
        Logger.warning("Error persisting alert with ID #{get_field(changeset, :alert_id)}")
        traverse_errors(changeset, fn {msg, _} -> msg end) |> Logger.warning()

      {:ok, _} ->
        nil
    end

    result
  end

  @spec list_all_versions(Alert.t() | String.t()) :: [Alert.t()]
  def list_all_versions(%Alert{alert_id: alert_id}) do
    list_all_versions(alert_id)
  end

  def list_all_versions(alert_id) do
    Repo.all(
      from(
        a in Alert,
        where: a.alert_id == ^alert_id,
        order_by: [desc: a.last_modified_timestamp],
        preload: [informed_entity: [:trip]]
      )
    )
  end

  @spec get_most_recent_version(Alert.t() | String.t()) :: Alert.t() | nil
  def get_most_recent_version(alert) when is_struct(alert) do
    get_most_recent_version(alert.alert_id)
  end

  def get_most_recent_version(alert_id) do
    from(
      a in Alert,
      where: a.alert_id == ^alert_id,
      order_by: [desc: a.last_modified_timestamp],
      preload: [informed_entity: [:trip]]
    )
    |> first()
    |> Repo.one()
  end

  @spec is_most_recent_version?(Alert.t()) :: boolean()
  def is_most_recent_version?(incoming_alert) do
    case get_most_recent_version(incoming_alert.alert_id) do
      nil -> true
      stored_alert -> is_last_modified_time_more_recent?(incoming_alert, stored_alert)
    end
  end

  defp is_last_modified_time_more_recent?(incoming_alert, stored_alert) do
    DateTime.compare(incoming_alert.last_modified_timestamp, stored_alert.last_modified_timestamp) ==
      :gt
  end

  def list_all do
    Repo.all(
      from(
        a in Alert,
        preload: [informed_entity: [:trip]]
      )
    )
  end
end
