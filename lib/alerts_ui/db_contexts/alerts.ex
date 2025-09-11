defmodule AlertsUI.Alerts do
  @moduledoc """
    Context for working with alerts in the database
  """
  import Ecto.Changeset
  import Ecto.Query
  alias AlertsUI.Models.Alert
  alias AlertsUI.Repo
  require Logger

  def create_or_update_alert(params, user, existing_alert \\ %Alert{}) do
    existing_alert
    |> Alert.changeset(params)
    |> Ecto.Changeset.put_assoc(:user, user)
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

  @spec update_end_if_estimated([Alert.t()], DateTime.t()) :: [Alert.t()]
  def update_end_if_estimated(alerts, current_time \\ DateTime.utc_now()) do
    alerts
    |> Enum.map(fn alert ->
      start_is_past = time_is_past(current_time, alert.active_period_start)

      update_alert_end(alert, start_is_past, current_time)
    end)
  end

  defp update_alert_end(
         %Alert{
           active_period: [active_period],
           duration_certainty: :ESTIMATED,
           notification_period_end: notification_period_end
         } = alert,
         true,
         current_time
       ) do
    # notification period end is set to the current day's EOS when the alert is made
    two_hours_from_now = DateTime.add(current_time, 2, :hour)

    new_end_time =
      if DateTime.compare(notification_period_end, two_hours_from_now) in [:eq, :gt] do
        two_hours_from_now
      else
        notification_period_end
      end

    params = %{
      active_period: [%{start: active_period.start, end: new_end_time}],
      active_period_end: new_end_time
    }

    alert
    |> Alert.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, %Alert{} = alert} -> alert
      {:error, result} -> result
    end
  end

  defp update_alert_end(alert, _, _), do: alert

  @spec close_if_end_is_past([Alert.t()], DateTime.t()) :: [Alert.t()]
  def close_if_end_is_past(alerts, current_time \\ DateTime.utc_now()) do
    current_time = DateTime.truncate(current_time, :second)

    alerts
    |> Enum.map(fn alert ->
      end_is_past = time_is_past(current_time, alert.active_period_end)

      if end_is_past do
        close(alert)
      else
        alert
      end
    end)
  end

  defp time_is_past(_current_time, nil), do: false

  defp time_is_past(current_time, end_time),
    do: DateTime.compare(current_time, end_time) in [:eq, :gt]

  @spec update_recurring_active_periods(Alert.t(), DateTime.t()) ::
          {:ok, Alert.t()} | {:error, binary()}
  def update_recurring_active_periods(alert, current_time \\ DateTime.utc_now())

  def update_recurring_active_periods(
        %{active_period: [_ | _], recurrence_days: [_ | _]} = alert,
        current_time
      ) do
    %{start: last_ap_start, end: last_ap_end} = alert.active_period |> Enum.reverse() |> hd
    weekday_integers = Enum.map(alert.recurrence_days, &Timex.day_to_num/1)

    last_ap_start_date = DateTime.to_date(last_ap_start)

    next_day_modifier =
      if Date.compare(DateTime.to_date(last_ap_end), last_ap_start_date) == :gt,
        do: 1,
        else: 0

    last_ap_start
    |> DateTime.to_date()
    |> Date.range(Timex.shift(DateTime.to_date(current_time), years: 1))
    |> Enum.filter(&(Timex.weekday(&1) in weekday_integers))
    |> Enum.reject(&(&1 === last_ap_start_date))
    |> Enum.map(fn date ->
      %{
        start:
          date
          |> DateTime.new!(DateTime.to_time(last_ap_start)),
        end:
          date
          |> Date.add(next_day_modifier)
          |> DateTime.new!(DateTime.to_time(last_ap_end))
      }
    end)
    |> Enum.map(fn active_period_params ->
      alert
      |> Ecto.build_assoc(:active_period)
      |> cast(active_period_params, [:start, :end])
      |> PaperTrail.insert()
      |> case do
        {:ok, %{model: alert}} -> {:ok, alert}
        {:error, result} -> {:error, result}
      end
    end)
  end

  def update_recurring_active_periods(alert, _current_time), do: {:ok, alert}

  @spec filter_on_notification_period_start([Alert.t()], DateTime.t()) :: [Alert.t()]
  def filter_on_notification_period_start(alerts, current_time \\ DateTime.utc_now()) do
    Enum.filter(
      alerts,
      fn alert ->
        notification_start = Map.get(alert, :notification_period_start, nil)

        is_nil(notification_start) or
          DateTime.compare(notification_start, current_time) in [:lt, :eq]
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
        preload: [:user, :active_period, :reminder_times, informed_entity: {ie, :trip}],
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
        preload: [:user, :active_period, :reminder_times, informed_entity: {ie, :trip}],
        order_by: [asc: a.alert_id]
      )
    )
  end

  @spec list_all() :: [Alert.t()]
  def list_all do
    Repo.all(
      from(
        a in Alert,
        preload: [:user, :active_period, :reminder_times, informed_entity: [:trip]]
      )
    )
  end

  @spec get_by_alert_id(String.t() | integer()) :: Alert.t()
  def get_by_alert_id(alert_id) when is_integer(alert_id) do
    alert_id
    |> Integer.to_string()
    |> get_by_alert_id
  end

  def get_by_alert_id(alert_id) do
    Repo.get_by(
      from(
        a in Alert,
        preload: [:user, :active_period, :reminder_times, informed_entity: [:trip]]
      ),
      alert_id: alert_id
    )
  end

  @spec get_by_id(String.t()) :: Alert.t()
  def get_by_id(uuid) do
    Repo.get_by(
      from(
        a in Alert,
        preload: [:user, :active_period, :reminder_times, informed_entity: [:trip]]
      ),
      id: uuid
    )
  end

  @spec get_earliest_version(String.t()) :: PaperTrail.Version.t() | nil
  def get_earliest_version(alert_uuid) do
    from(
      version in PaperTrail.Version,
      where: version.item_id == ^alert_uuid and version.event == "insert"
    )
    |> Repo.one()
  end

  @spec get_latest_version(String.t()) :: PaperTrail.Version.t() | nil
  def get_latest_version(alert_uuid) do
    from(
      version in PaperTrail.Version,
      where: version.item_id == ^alert_uuid,
      order_by: [desc: :inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @spec list_all_paginated(map()) :: {[any()], Flop.Meta.t()}
  def list_all_paginated_by_creation_date(params) do
    opts = [for: Alert, page_size: 50]

    with {:ok, flop} <- Flop.validate(params, opts) do
      Alert
      |> order_by([a], asc: a.created_at)
      |> Flop.with_named_bindings(flop, &join_informed_entity/2, opts)
      |> preload(informed_entity: [:trip])
      |> select_merge([a], %{
        alert_id: a.alert_id |> type(:integer) |> selected_as(:integer_alert_id)
      })
      |> Flop.run(flop, opts)
    end
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

  @spec close(Alert.t()) :: Alert.t()
  def close(alert, closed_time \\ DateTime.utc_now()) do
    closed_time = DateTime.truncate(closed_time, :second)

    alert
    |> change(
      active_period_end: closed_time,
      closed_timestamp: closed_time,
      notification_period_end: closed_time,
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

  def delete(alert_id) do
    Alert
    |> Repo.get_by!(alert_id: alert_id)
    |> Repo.delete()
  end

  def foo(bar) do
    from(a in Alert,
      select: a.alert_id,
      where: fragment("to_tsvector('english', header_text) @@ to_tsquery('english', ?)", ^bar)
    )
    |> Repo.all()
  end
end
