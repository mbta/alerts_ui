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

  @end_sql_asc "SELECT *,
  (SELECT max(obj->>'end')
  FROM unnest(alerts.active_period) obj) AS subq
  FROM \"alerts\"
  ORDER BY subq asc NULLS LAST"

  @end_sql_desc "SELECT *,
  (SELECT max(obj->>'end')
  FROM unnest(alerts.active_period) obj) AS subq
  FROM \"alerts\"
  ORDER BY subq desc NULLS LAST"

  @start_sql_asc "SELECT *,
  (SELECT min(obj->>'start')
  FROM unnest(alerts.active_period) obj) AS subq
  FROM \"alerts\"
  ORDER BY subq asc NULLS LAST"

  @start_sql_desc "SELECT *,
  (SELECT min(obj->>'start')
  FROM unnest(alerts.active_period) obj) AS subq
  FROM \"alerts\"
  ORDER BY subq desc NULLS LAST"

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

  @spec list_all_paginated(atom() | %{:order_by => list(), optional(any()) => any()}) ::
          {:ok, {list(), Flop.Meta.t()}}
  def list_all_paginated(params) do
    # We want Flop to track the "direction" of active_period_start and active_period_end (eg ascending or descending)
    # but we cannot put those params into validate and run directly because they don't exist in our Alert schema
    # so we're removing them from both the order_by and order_directions params as necessary before doing the flop run
    # and then putting them back in our return.
    cond do
      List.first(params.order_by) == :active_period_start ->
        order_by_active_period_query(:active_period_start, params)
        |> flop_run_and_reset_params(Flop.reset_order(params), params)

      List.first(params.order_by) == :active_period_end ->
        order_by_active_period_query(:active_period_end, params)
        |> flop_run_and_reset_params(Flop.reset_order(params), params)

      true ->
        new_params = remove_unwanted_params(params)

        Alert
        |> preload([:informed_entity])
        |> flop_run_and_reset_params(new_params, params)
    end
  end

  defp flop_run_and_reset_params(query, new_params, old_params) do
    {:ok, {result, meta}} =
      Flop.validate_and_run(query, new_params)

    new_meta = Map.put(meta, :flop, old_params)
    {:ok, {result, new_meta}}
  end

  defp remove_unwanted_params(params) do
    active_period_positions = Enum.with_index(params.order_by)
    new_params = params

    new_params =
      case :active_period_start in params.order_by do
        true ->
          delete_from_params(new_params, active_period_positions, :active_period_start)

        false ->
          new_params
      end

    case :active_period_end in params.order_by do
      true ->
        delete_from_params(new_params, active_period_positions, :active_period_end)

      false ->
        new_params
    end
  end

  defp delete_from_params(new_params, positions, field) do
    new_params
    |> Map.put(
      :order_by,
      List.delete_at(new_params.order_by, positions[field])
    )
    |> Map.put(
      :order_directions,
      List.delete_at(new_params.order_directions, positions[field])
    )
  end

  def order_by_active_period_query(field, params) do
    direction = Flop.current_order(params, field)
    dummy_query = from(a in Alert, as: :dummy, select: a.id, limit: 1)

    aggregate_subquery =
      from(d in subquery(dummy_query))
      |> active_period_subquery(field, direction)
      |> select_alert()

    from(q in subquery(aggregate_subquery), preload: [informed_entity: [:trip]])
  end

  defp active_period_subquery(query, :active_period_start, :asc) do
    query
    |> join(:inner, [], raw in fragment(@start_sql_asc), on: true, as: :raw)
  end

  defp active_period_subquery(query, :active_period_start, :desc) do
    query
    |> join(:inner, [], raw in fragment(@start_sql_desc), on: true, as: :raw)
  end

  defp active_period_subquery(query, :active_period_end, :asc) do
    query
    |> join(:inner, [], raw in fragment(@end_sql_asc), on: true, as: :raw)
  end

  defp active_period_subquery(query, :active_period_end, :desc) do
    query
    |> join(:inner, [], raw in fragment(@end_sql_desc), on: true, as: :raw)
  end

  defp select_alert(query) do
    query
    |> select([raw: a], %Alert{
      id: type(a.id, :binary_id),
      alert_id: a.alert_id,
      effect: a.effect,
      effect_detail: a.effect_detail,
      cause: a.cause,
      cause_detail: a.cause_detail,
      header_text: a.header_text,
      description_text: a.description_text,
      severity_level: a.severity_level,
      url: a.url,
      service_effect_text: a.service_effect_text,
      short_header_text: a.short_header_text,
      severity: a.severity,
      created_timestamp: type(a.created_timestamp, :utc_datetime),
      last_modified_timestamp: type(a.last_modified_timestamp, :utc_datetime),
      last_push_notification_timestamp: type(a.last_push_notification_timestamp, :utc_datetime),
      closed_timestamp: type(a.closed_timestamp, :utc_datetime),
      timeframe_text: a.timeframe_text,
      recurrence_text: a.recurrence_text,
      alert_lifecycle: a.alert_lifecycle,
      duration_certainty: a.duration_certainty,
      reminder_times: a.reminder_times,
      active_period: a.active_period
    })
  end
end
