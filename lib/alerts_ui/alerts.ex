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

  defp compare_feed,
    do: Application.get_env(:alerts_ui, :compare_feed) == "true"

  def create_alert(params) do
    if compare_feed() do
      changeset =
        change(%Alert{}, %{})
        |> add_error(:alert_id, "cannot create alert while feed is being compared")

      {:error, changeset}
    else
      %Alert{}
      |> Alert.changeset(params)
      |> Repo.insert()
    end
  end

  def create_draft_alert(params) do
    %Alert{}
    |> Alert.draft_changeset(params)
    |> Repo.insert()
  end

  @spec parse_changeset_errors(Ecto.Changeset.t()) :: %{optional(atom()) => list()}
  def parse_changeset_errors(changeset) do
    traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @spec get_max_alert_id() :: integer()
  def get_max_alert_id do
    from(a in Alert,
      select: fragment("max(cast((?) as integer))", a.alert_id)
    )
    |> Repo.one!() || 0
  end

  @spec create_or_modify_alert_from_feed(map()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def create_or_modify_alert_from_feed(incoming_alert) do
    result =
      Multi.new()
      |> Multi.one(:most_recent_alert, get_alert_by_alert_id_query(incoming_alert.alert_id))
      |> Multi.run(:changeset, AlertsUI.Alerts, :create_changeset_from_feed, [incoming_alert])
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

  @spec create_changeset_from_feed(
          any(),
          %{:most_recent_alert => Alert.t() | nil, optional(any()) => any()},
          map()
        ) ::
          {:error, Ecto.Changeset.t()} | {:ok, Ecto.Changeset.t()}
  def create_changeset_from_feed(_repo, %{most_recent_alert: nil}, incoming_alert) do
    # if there is no stored alert with the same alert_id, create new changeset for incoming alert
    {:ok, %Alert{} |> Alert.changeset(incoming_alert)}
  end

  # don't overwrite active period if it's empty and alert is closed
  def create_changeset_from_feed(
        _repo,
        %{most_recent_alert: stored_alert},
        %{active_period: [], closed_timestamp: closed_timestamp} = incoming_alert
      )
      when closed_timestamp !== nil do
    # if there is a stored alert with the same alert_id, create a modification changeset
    # for it if the incoming alert is more recent. Otherwise create an error changeset so
    # nothing gets created
    incoming_alert_is_more_recent =
      last_modified_time_more_recent?(
        Map.get(incoming_alert, :last_modified_timestamp),
        Map.get(stored_alert, :last_modified_timestamp)
      )

    if incoming_alert_is_more_recent do
      stored_alert_with_preloads =
        stored_alert
        |> Repo.preload(informed_entity: [:trip])

      incoming_alert =
        incoming_alert
        |> Map.delete(:active_period)
        |> Map.delete(:active_period_start)
        |> Map.delete(:active_period_end)

      {:ok, stored_alert_with_preloads |> Alert.changeset(incoming_alert)}
    else
      {:error, change(%Alert{}, %{}) |> add_error(:alert_id, "alert is not most recent version")}
    end
  end

  def create_changeset_from_feed(_repo, %{most_recent_alert: stored_alert}, incoming_alert) do
    incoming_alert_is_more_recent =
      last_modified_time_more_recent?(
        Map.get(incoming_alert, :last_modified_timestamp),
        Map.get(stored_alert, :last_modified_timestamp)
      )

    if incoming_alert_is_more_recent do
      stored_alert_with_preloads =
        stored_alert
        |> Repo.preload(informed_entity: [:trip])

      {:ok, stored_alert_with_preloads |> Alert.changeset(incoming_alert)}
    else
      {:error, change(%Alert{}, %{}) |> add_error(:alert_id, "alert is not most recent version")}
    end
  end

  defp get_alert_by_alert_id_query(alert_id) do
    from(
      a in Alert,
      where: a.alert_id == ^alert_id
    )
  end

  @spec last_modified_time_more_recent?(map() | nil, Alert.t() | nil) :: boolean()
  def last_modified_time_more_recent?(nil, _), do: false
  def last_modified_time_more_recent?(_, nil), do: true

  def last_modified_time_more_recent?(incoming_time, stored_time) do
    DateTime.compare(incoming_time, stored_time) != :lt
  end

  @spec close_if_not_in_feed([map()], DateTime.t()) :: [map()]
  def close_if_not_in_feed(incoming_alert_list, closed_time \\ DateTime.utc_now()) do
    alert_ids = Enum.map(incoming_alert_list, & &1.alert_id)

    from(
      a in Alert,
      where: a.alert_id not in ^alert_ids,
      where: is_nil(a.closed_timestamp)
    )
    |> Repo.update_all(set: [closed_timestamp: closed_time])

    incoming_alert_list
  end

  @spec list_all_open() :: [Alert.t()]
  def list_all_open do
    # Using an inner join here reduces the
    # number of overall queries
    # ref. https://hexdocs.pm/ecto/Ecto.Query.html#preload/3
    Repo.all(
      from(
        a in Alert,
        where: is_nil(a.closed_timestamp),
        inner_join: ie in AlertsUI.Models.InformedEntity,
        on: ie.alert_id == a.id,
        preload: [informed_entity: {ie, :trip}],
        order_by: [asc: a.alert_id]
      )
    )
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

  @spec get_by_alert_id(String.t()) :: Alert.t()
  def get_by_alert_id(alert_id) do
    Repo.get_by(
      from(
        a in Alert,
        preload: [informed_entity: [:trip]]
      ),
      alert_id: alert_id
    )
  end

  @spec list_all_paginated(map()) :: {[any()], Flop.Meta.t()}
  def list_all_paginated(params) do
    opts = [for: Alert, page_size: 50]

    with {:ok, flop} <- Flop.validate(params, opts) do
      Alert
      |> Flop.with_named_bindings(flop, &join_informed_entity/2, opts)
      |> preload(informed_entity: [:trip])
      |> Flop.run(flop, opts)
    end
  end

  defp join_informed_entity(query, _opts) do
    query
    |> join(:inner, [a], ie in assoc(a, :informed_entity), as: :informed_entity)
  end

  @spec publishable?(String.t()) :: boolean()
  def publishable?(alert_or_alert_id), do: !draft?(alert_or_alert_id)

  @spec draft?(String.t()) :: boolean()
  def draft?(%Alert{} = alert), do: !!alert.draft

  def draft?(alert_id) do
    !!Repo.get_by(
      from(
        a in Alert,
        select: a.draft
      ),
      alert_id: alert_id
    )
  end
end
