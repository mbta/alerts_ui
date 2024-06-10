defmodule AlertsUI.Alerts do
  @moduledoc """
    Context for working with alerts in the database
  """
  import Ecto.Changeset
  import Ecto.Query
  alias AlertsUI.Models.Alert
  alias AlertsUI.Repo
  require Logger

  defp compare_feed,
    do: Application.get_env(:alerts_ui, :compare_feed) == "true"

  def create_or_update_alert(params, existing_alert \\ %Alert{}) do
    if compare_feed() do
      changeset =
        change(existing_alert, %{})
        |> add_error(:alert_id, "cannot create alert while feed is being compared")

      {:error, changeset}
    else
      existing_alert
      |> Alert.changeset(params)
      |> PaperTrail.insert_or_update()
      |> case do
        {:ok, %{model: alert}} -> {:ok, alert}
        {:error, result} -> {:error, result}
      end
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

  @spec create_or_modify_alert_from_feed(map()) ::
          nil | :ok
  def create_or_modify_alert_from_feed(incoming_alert) do
    most_recent_alert =
      incoming_alert.alert_id
      |> get_alert_by_alert_id_query()
      |> Repo.one()

    case create_changeset_from_feed(
           :repo,
           %{most_recent_alert: most_recent_alert},
           incoming_alert
         ) do
      {:ok, changeset} ->
        insert_or_update(changeset)

      {:error, %{errors: [alert_id: {"alert is not most recent version", []}]}} ->
        nil
    end
  end

  defp insert_or_update(changeset) do
    PaperTrail.Multi.new()
    |> PaperTrail.Multi.insert_or_update(changeset)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      {:error, _, changeset, _} ->
        Logger.warning("Error persisting alert with ID #{get_field(changeset, :alert_id)}")
        traverse_errors(changeset, fn {msg, _} -> msg end) |> Logger.warning()
    end
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

  @spec close_if_end_is_past([Alert.t()], DateTime.t()) :: [Alert.t()]
  def close_if_end_is_past(alerts, current_datetime \\ DateTime.utc_now()) do
    current_datetime = DateTime.truncate(current_datetime, :second)

    alerts
    |> Enum.map(fn alert ->
      end_is_past = end_is_past(current_datetime, alert.active_period_end)
      ends_later_today = ends_later_today(alert.active_period_end, alert.duration_certainty)

      if end_is_past or
           (ends_later_today and past_service_end(alert.active_period_start, current_datetime)) do
        change(alert, closed_timestamp: current_datetime)
        |> PaperTrail.update!()
      else
        alert
      end
    end)
  end

  defp end_is_past(_current_time, nil), do: false

  defp end_is_past(current_time, end_time),
    do: DateTime.compare(current_time, end_time) in [:eq, :gt]

  # this is the case where "later today" was selected in the form
  defp ends_later_today(nil, :ESTIMATED), do: true
  defp ends_later_today(_ap_end, _duration_certainty), do: false

  defp past_service_end(nil, _current_time), do: false

  defp past_service_end(ap_start, current_datetime) do
    start_datetime = Timex.Timezone.convert(datetime, "America/New_York")
    start_date = DateTime.to_date(start_datetime)
    start_time = DateTime.to_time(start_datetime)

    end_of_service_day =
      case Time.before?(start_time, ~T[02:30:00]) do
        true -> DateTime.new!(start_date, ~T[02:30:00], "America/New_York")
        false -> DateTime.new!(Date.add(start_date, 1), ~T[02:30:00], "America/New_York")
      end

    DateTime.compare(current_datetime, end_of_service_day) in [:gt, :eq]
  end

  @spec close_if_not_in_feed([map()], DateTime.t()) :: [map()]
  def close_if_not_in_feed(incoming_alert_list, closed_time \\ DateTime.utc_now()) do
    alert_ids = Enum.map(incoming_alert_list, & &1.alert_id)
    closed_time = DateTime.truncate(closed_time, :second)

    from(
      a in Alert,
      where: a.alert_id not in ^alert_ids,
      where: is_nil(a.closed_timestamp)
    )
    |> Repo.all()
    |> Enum.each(fn alert ->
      change(alert, closed_timestamp: closed_time)
      |> PaperTrail.update()
    end)

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
