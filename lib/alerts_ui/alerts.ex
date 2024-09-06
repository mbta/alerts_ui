defmodule AlertsUI.Alerts do
  @moduledoc """
    Context for working with alerts in the database
  """
  import Ecto.Changeset
  import Ecto.Query
  alias AlertsUI.Models.Alert
  alias AlertsUI.Repo
  require Logger

  def create_or_update_alert(params, existing_alert \\ %Alert{}) do
    existing_alert
    |> Alert.changeset(params)
    |> PaperTrail.insert_or_update()
    |> case do
      {:ok, %{model: alert}} -> {:ok, alert}
      {:error, result} -> {:error, result}
    end
  end

  def create_draft_alert(params) do
    %Alert{}
    |> Alert.draft_changeset(params)
    |> PaperTrail.insert()
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

  def get_alert_by_alert_id_query(alert_id) do
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

  @spec close_if_end_is_past([Alert.t()], DateTime.t()) :: [Alert.t()]
  def close_if_end_is_past(alerts, current_time \\ DateTime.utc_now()) do
    current_time = DateTime.truncate(current_time, :second)

    alerts
    |> Enum.map(fn alert ->
      end_is_past = end_is_past(current_time, alert.active_period_end)

      if end_is_past do
        close(alert)
      else
        alert
      end
    end)
  end

  defp end_is_past(_current_time, nil), do: false

  defp end_is_past(current_time, end_time),
    do: DateTime.compare(current_time, end_time) in [:eq, :gt]

  @spec filter_on_notification_period([Alert.t()], DateTime.t()) :: [Alert.t()]
  def filter_on_notification_period(alerts, current_time \\ DateTime.utc_now()) do
    Enum.filter(
      alerts,
      fn alert ->
        notification_start = Map.get(alert, :notification_period_start, nil)
        notification_end = Map.get(alert, :notification_period_end, nil)

        starts_before_current_time =
          is_nil(notification_start) or
            DateTime.compare(notification_start, current_time) in [:lt, :eq]

        ends_after_current_time =
          is_nil(notification_end) or
            DateTime.compare(notification_end, current_time) in [:gt, :eq]

        starts_before_current_time and ends_after_current_time
      end
    )
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

  @spec list_all_recently_closed() :: [Alert.t()]
  def list_all_recently_closed do
    Repo.all(
      from(
        a in Alert,
        where: not is_nil(a.closed_timestamp) and a.closed_timestamp > from_now(-5, "minute"),
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

  @spec get_by_id(String.t()) :: Alert.t()
  def get_by_id(uuid) do
    Repo.get_by(
      from(
        a in Alert,
        preload: [informed_entity: [:trip]]
      ),
      id: uuid
    )
  end

  @spec list_all_paginated(map()) :: {[any()], Flop.Meta.t()}
  def list_all_paginated(params) do
    opts = [for: Alert, page_size: 50]

    with {:ok, flop} <- Flop.validate(params, opts) do
      Alert
      |> where([a], a.draft == false or is_nil(a.draft))
      |> Flop.with_named_bindings(flop, &join_informed_entity/2, opts)
      |> preload(informed_entity: [:trip])
      |> select_merge([a], %{
        alert_id: a.alert_id |> type(:integer) |> selected_as(:integer_alert_id)
      })
      |> Flop.run(flop, opts)
    end
  end

  def close(alert, closed_time \\ DateTime.utc_now()) do
    closed_time = DateTime.truncate(closed_time, :second)

    alert
    |> change(
      closed_timestamp: closed_time,
      duration_certainty: :KNOWN
    )
    |> PaperTrail.update!()
  end

  defp join_informed_entity(query, _opts) do
    query
    |> join(:inner, [a], ie in assoc(a, :informed_entity), as: :informed_entity)
  end

  @spec publishable?(String.t() | Alert.t()) :: boolean()
  def publishable?(alert_or_alert_id), do: !draft?(alert_or_alert_id)

  @spec draft?(String.t() | Alert.t()) :: boolean()
  def draft?(%Alert{} = alert), do: !!alert.draft

  def draft?(alert_id) do
    Repo.exists?(
      from(
        a in Alert,
        where: a.alert_id == ^alert_id,
        where: a.draft == true
      )
    )
  end
end
