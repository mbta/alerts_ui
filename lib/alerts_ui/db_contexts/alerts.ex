defmodule AlertsUI.Alerts do
  @moduledoc """
    Context for working with alerts in the database
  """
  import Ecto.Changeset
  import Ecto.Query
  alias AlertsUI.DBContexts.Users
  alias AlertsUI.Helpers.DateTime, as: DTHelpers
  alias AlertsUI.Models.{ActivePeriod, Alert, User}
  alias AlertsUI.Repo
  alias AlertsUIWeb.Helpers.EffectsForRouteTypes
  alias MBTAV3API.Routes.Repo, as: RoutesRepo

  @spec create_or_update_alert(map(), User.t(), any()) :: {:ok | :error, any()}
  def create_or_update_alert(params, %User{} = user, %Alert{} = existing_alert \\ %Alert{}) do
    existing_alert
    |> Alert.changeset(params)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> PaperTrail.insert_or_update(user: user, origin: "user")
    |> case do
      {:ok, %{model: alert}} -> {:ok, alert}
      {:error, result} -> {:error, result}
    end
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
        close_automatically(alert)
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
        %{
          active_period: [_ | _],
          recurrence_days: [_ | _],
          recurrence_start_time: recurrence_start_time,
          recurrence_end_time: recurrence_end_time
        } = alert,
        current_time
      ) do
    %{start: last_ap_start, end: _last_ap_end} = alert.active_period |> Enum.reverse() |> hd
    weekday_integers = Enum.map(alert.recurrence_days, &Timex.day_to_num/1)

    last_ap_start_date = DateTime.to_date(last_ap_start)

    next_day_modifier =
      if Time.before?(recurrence_start_time, recurrence_end_time), do: 0, else: 1

    last_ap_start
    |> DateTime.to_date()
    |> Date.range(Timex.shift(DateTime.to_date(current_time), years: 1))
    |> Enum.filter(&(Timex.weekday(&1) in weekday_integers))
    |> Enum.reject(&(&1 === last_ap_start_date))
    |> Enum.map(fn date ->
      %{
        start:
          date
          |> DTHelpers.round_up_to_gap!(
            recurrence_start_time,
            "America/New_York"
          )
          |> DateTime.shift_zone!("Etc/UTC"),
        end:
          date
          |> Date.add(next_day_modifier)
          |> DTHelpers.round_up_to_gap!(
            recurrence_end_time,
            "America/New_York"
          )
          |> DateTime.shift_zone!("Etc/UTC")
      }
    end)
    |> Enum.map(fn active_period_params ->
      alert
      |> Ecto.build_assoc(:active_period)
      |> cast(active_period_params, [:start, :end])
      |> Repo.insert()
      |> case do
        {:ok, active_period} -> {:ok, active_period}
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

  @spec active_period_preload_query() :: Ecto.Query.t()
  defp active_period_preload_query do
    from a in ActivePeriod, order_by: a.start
  end

  @spec list_all_open() :: [Alert.t()]
  def list_all_open do
    Repo.all(
      from(
        a in Alert,
        where: is_nil(a.closed_timestamp),
        preload: [
          :user,
          :reminder_times,
          active_period: ^active_period_preload_query(),
          informed_entity: [:trip]
        ],
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
        preload: [
          :user,
          :reminder_times,
          active_period: ^active_period_preload_query(),
          informed_entity: [:trip]
        ],
        order_by: [asc: a.alert_id]
      )
    )
  end

  @spec list_all() :: [Alert.t()]
  def list_all do
    Repo.all(
      from(
        a in Alert,
        preload: [
          :user,
          :reminder_times,
          active_period: ^active_period_preload_query(),
          informed_entity: [:trip]
        ]
      )
    )
  end

  @spec list_a_month_of_commuter_rail(integer(), integer()) :: [Alert.t()]
  def list_a_month_of_commuter_rail(month, year) when is_integer(month) and is_integer(year) do
    Repo.all(
      from(
        a in Alert,
        where: a.primary_service_type == "2",
        where:
          fragment("date_part(?, ?)", "year", a.created_timestamp) == ^year and
            fragment("date_part(?, ?)", "month", a.created_timestamp) == ^month,
        select: a.alert_id,
        order_by: a.created_at
      )
    )
  end

  @spec get_by_alert_id(String.t() | integer()) :: Alert.t() | nil
  def get_by_alert_id(alert_id) when is_integer(alert_id) do
    alert_id
    |> Integer.to_string()
    |> get_by_alert_id
  end

  def get_by_alert_id(alert_id) do
    Repo.get_by(get_by_alert_id_query(), alert_id: alert_id)
  end

  @spec get_by_alert_id!(String.t()) :: Alert.t()
  def get_by_alert_id!(alert_id) do
    Repo.get_by!(get_by_alert_id_query(), alert_id: alert_id)
  end

  defp get_by_alert_id_query do
    from(
      a in Alert,
      preload: [
        :user,
        :reminder_times,
        active_period: ^active_period_preload_query(),
        informed_entity: [:trip]
      ]
    )
  end

  @spec get_by_id(String.t()) :: Alert.t()
  def get_by_id(uuid) do
    Repo.get_by(
      from(
        a in Alert,
        preload: [
          :user,
          :reminder_times,
          active_period: ^active_period_preload_query(),
          informed_entity: [:trip]
        ]
      ),
      id: uuid
    )
  end

  @spec get_by_id(String.t()) :: Ecto.UUID
  def get_uuid_by_alert_id(alert_id) do
    from(
      a in Alert,
      where: a.alert_id == ^alert_id,
      select: a.id,
      limit: 1
    )
    |> Repo.one()
  end

  @spec get_matching_skate_ids([integer()]) :: [integer()]
  def get_matching_skate_ids(skate_ids) do
    from(
      a in Alert,
      where: a.skate_detour_id in ^skate_ids,
      where: is_nil(a.closed_timestamp),
      select: %{skate_detour_id: a.skate_detour_id, alert_id: a.alert_id}
    )
    |> Repo.all()
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
      order_by: [
        desc: fragment("meta->'version'"),
        desc: :inserted_at
      ],
      limit: 1
    )
    |> Repo.one()
  end

  @spec get_all_versions(String.t() | nil) :: PaperTrail.Version.t()
  def get_all_versions(nil), do: []

  def get_all_versions(alert_uuid) do
    from(
      version in PaperTrail.Version,
      where: version.item_id == ^alert_uuid,
      order_by: [
        asc: fragment("meta->'version'"),
        asc: :inserted_at
      ]
    )
    |> Repo.all()
  end

  @spec get_originator_string(PaperTrail.Version | map() | nil) :: String.t() | nil
  def get_originator_string(nil), do: ""

  def get_originator_string(version) do
    # returns user's name linked to the PaperTrail version if available
    # otherwise returns the origin string from the version if available
    originator_id = get_originator_id(version)

    if originator_id do
      user = Users.get_user!(originator_id)
      "#{Map.get(user, :first_name, "")} #{Map.get(user, :last_name, "")}"
    else
      Map.get(version, :origin, "")
    end
  end

  defp get_originator_id(%{originator_id: user_id}) when not is_nil(user_id), do: user_id
  # these two below are for alerts made before 9/17/2025. May be removed when no longer relevant.
  defp get_originator_id(%{item_changes: %{"user_id" => user_id}}), do: user_id
  defp get_originator_id(%{user_id: user_id, origin: "user"}), do: user_id
  defp get_originator_id(_), do: nil

  @spec list_all_paginated_by_id(map()) :: {[any()], Flop.Meta.t()}
  def list_all_paginated_by_id(params) do
    opts = [for: Alert, page_size: 50]

    with {:ok, flop} <- Flop.validate(params, opts) do
      Alert
      |> select_merge([a], %{
        alert_id: a.alert_id |> type(:integer) |> selected_as(:integer_alert_id)
      })
      |> order_by([a], asc: a.alert_id |> type(:integer))
      |> Flop.run(flop, opts)
    end
  end

  @spec list_all_paginated(map()) :: {[any()], Flop.Meta.t()}
  def list_all_paginated(params) do
    opts = [for: Alert, page_size: 50]

    facility_effect_types = EffectsForRouteTypes.list_effects(:facility)

    with {:ok, flop} <- Flop.validate(params, opts) do
      Alert
      |> where([a], a.draft == false or is_nil(a.draft))
      |> select_merge([a], %{
        alert_id: a.alert_id |> type(:integer) |> selected_as(:integer_alert_id),
        # If original_route_selections is not []:
        #   Take the first route and pad it with characters if it's numeric
        #   so that a basic alphanumeric sort will work correctly (because that's what flop does)
        #   E.g. 1 < 4 < 10 < Red Line
        # If it is []:
        #   Use facility if in facility effect types
        #   Otherwise, systemwide
        service_pill_sort_key:
          fragment(
            """
            CASE
              WHEN COALESCE(array_length(?, 1), 0) > 0 THEN
                COALESCE(
                  lpad(NULLIF(regexp_replace((?)[1], '[^0-9].*', ''), ''), 10, '0')
                    || regexp_replace((?)[1], '^[0-9]+', ''),
                  (?)[1]
                )
              WHEN ? = ANY(?) THEN ?
              ELSE ?
            END
            """,
            a.original_route_selections,
            a.original_route_selections,
            a.original_route_selections,
            a.original_route_selections,
            a.effect_name,
            ^facility_effect_types,
            ^"Facility",
            ^"Systemwide"
          )
          |> selected_as(:service_pill_sort_key)
      })
      |> Flop.run(flop, opts)
    end
  end

  # use close_automatically for any alert that's closed by the system
  # it sets defaults for origin and last_push_notification_timestamp
  @spec close_automatically(Alert.t(), DateTime.t()) :: Alert.t()
  def close_automatically(alert, closed_time \\ DateTime.utc_now()) do
    send_all_clear? = alert.duration_certainty == :UNKNOWN
    close(alert, "(Closed automatically)", send_all_clear?, closed_time)
  end

  @spec close(Alert.t(), User.t() | String.t(), boolean(), DateTime.t()) :: Alert.t()
  def close(alert, origin, send_all_clear?, closed_time \\ DateTime.utc_now()) do
    closed_time =
      closed_time
      |> DateTime.shift_zone!("Etc/UTC")
      |> DateTime.truncate(:second)

    last_push_notification_timestamp =
      if send_all_clear?, do: closed_time, else: alert.last_push_notification_timestamp

    closed_alert =
      alert
      |> change(
        active_period_end: closed_time,
        closed_timestamp: closed_time,
        notification_period_end: closed_time,
        last_modified_timestamp: closed_time,
        last_push_notification_timestamp: last_push_notification_timestamp,
        duration_certainty: :KNOWN
      )
      |> update_papertrail(origin)

    Phoenix.PubSub.broadcast(
      AlertsUI.PubSub,
      "alerts",
      {:alerts_updated}
    )

    closed_alert
  end

  defp update_papertrail(alert, %User{} = user) do
    user = Users.create_or_update_user_from_session(user)
    PaperTrail.update!(alert, originator: user, origin: "user")
  end

  defp update_papertrail(alert, origin) when is_binary(origin) do
    PaperTrail.update!(alert, origin: origin)
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

  # Function to retrieve all routes from the DB grouped by mode.

  # Joins Alerts and Informed Entities, and selects on:
  #   - original_route_selections (from Alerts)
  #   - route_type (from IE)
  #   - route_id (from IE)

  # Uses the IE fields to determine the route_type of each route in
  # original_route_selections so that we can group the route filters list by mode
  @spec get_routes_grouped_by_mode() :: map()
  def get_routes_grouped_by_mode do
    RoutesRepo.all()
    |> Enum.map(&{&1.name, &1.type, &1.id})
    |> Enum.concat([{"Green Line", 0, "Green"}])
    |> Enum.uniq()
    |> Enum.filter(fn x -> x != nil end)
    |> Enum.group_by(&elem(&1, 1))
  end
end
