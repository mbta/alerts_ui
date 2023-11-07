defmodule AlertsUI.Alerts do
  @moduledoc """
    Context for working with alerts in the database
  """
  import Ecto.Changeset
  import Ecto.Query
  alias AlertsUI.Models.Alert
  alias AlertsUI.Repo
  alias Ecto.Multi
  require Logger

  @spec create_or_modify_alert(map()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def create_or_modify_alert(incoming_alert) do
    result =
      Multi.new()
      |> Multi.one(:most_recent_alert, get_alert_by_alert_id_query(incoming_alert.alert_id))
      |> Multi.run(:changeset, AlertsUI.Alerts, :create_changeset, [incoming_alert])
      |> Multi.insert_or_update(:insert_or_update, fn %{changeset: changeset} -> changeset end)
      |> Repo.transaction()

    case result do
      {:ok, _} ->
        nil

      {:error, _, %{errors: [alert_id: {"alert is not most recent version", []}]}, _} ->
        nil

      {:error, _, changeset, _} ->
        Logger.warning("Error persisting alert with ID #{get_field(changeset, :alert_id)}")
        traverse_errors(changeset, fn {msg, _} -> msg end) |> Logger.warning()
    end

    result
  end

  @spec create_changeset(
          any(),
          %{:most_recent_alert => Alert.t() | nil, optional(any()) => any()},
          map()
        ) ::
          {:error, Ecto.Changeset.t()} | {:ok, Ecto.Changeset.t()}
  def create_changeset(_repo, %{most_recent_alert: nil}, incoming_alert) do
    # if there is no stored alert with the same alert_id, create new changeset for incoming alert
    {:ok, %Alert{} |> Alert.changeset(incoming_alert)}
  end

  def create_changeset(_repo, %{most_recent_alert: stored_alert}, incoming_alert) do
    # if there is a stored alert with the same alert_id, create a modification changeset
    # for it if the incoming alert is more recent. Otherwise create an error changeset so
    # nothing gets created
    incoming_alert_is_more_recent =
      is_last_modified_time_more_recent?(
        Map.get(incoming_alert, :last_modified_timestamp),
        Map.get(stored_alert, :last_modified_timestamp)
      )

    if incoming_alert_is_more_recent do
      {:ok, stored_alert |> Alert.changeset(incoming_alert)}
    else
      {:error, change(%Alert{}, %{}) |> add_error(:alert_id, "alert is not most recent version")}
    end
  end

  defp get_alert_by_alert_id_query(alert_id) do
    from(
      a in Alert,
      where: a.alert_id == ^alert_id,
      preload: [informed_entity: [:trip]]
    )
  end

  @spec is_last_modified_time_more_recent?(map() | nil, Alert.t() | nil) :: boolean()
  def is_last_modified_time_more_recent?(nil, _), do: false
  def is_last_modified_time_more_recent?(_, nil), do: true

  def is_last_modified_time_more_recent?(incoming_time, stored_time) do
    DateTime.compare(incoming_time, stored_time) == :gt
  end

  @spec list_all() :: [Alert.t()]
  def list_all do
    Repo.all(
      from(
        a in Alert,
        preload: [informed_entity: [:trip]]
      )
    )
  end
end
