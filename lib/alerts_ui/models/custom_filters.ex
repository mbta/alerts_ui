defmodule AlertsUI.Models.CustomFilters do
  @moduledoc """
    Home for custom flop fitlers
  """
  import Ecto.Query
  alias AlertsUI.Models.InformedEntity
  alias Flop.Filter

  def service_type_filter(query, %Filter{value: value}, _opts) do
    facility_activities =
      InformedEntity.facility_activities()
      |> Enum.map(&Atom.to_string(&1))
      |> Enum.map(&String.upcase(&1))

    if value == "access" do
      query
      |> where(
        [a, informed_entity: ie],
        fragment(
          ~s(\(?\) && \(?\)),
          ie.activities,
          ^facility_activities
        )
      )
    else
      query
      |> where([a, informed_entity: ie], ie.route_type == ^value)
    end
  end

  @spec multi_column_search_filter(Ecto.Query.t(), Flop.Filter.t(), list()) :: Ecto.Query.t()
  def multi_column_search_filter(query, %Filter{value: value}, _opts) do
    alert_id_search_value = "#{String.replace(value, ~r/\D/, "")}%"

    query
    |> where([a], ilike(a.alert_id, ^alert_id_search_value))
  end

  @spec timeline_filter(Ecto.Query.t(), Flop.Filter.t(), any()) :: Ecto.Query.t()
  def timeline_filter(query, %Filter{value: "future"}, _opts) do
    now = DateTime.utc_now()
    # use active_period_start as a backup when notification_start is blank
    query
    |> where(
      [a],
      (not is_nil(a.notification_period_start) and a.notification_period_start > ^now) or
        (is_nil(a.notification_period_start) and
           (not is_nil(a.active_period_start) and a.active_period_start > ^now))
    )
    |> where(
      [a],
      is_nil(a.closed_timestamp)
    )
  end

  def timeline_filter(query, %Filter{value: "past"}, _opts) do
    now = DateTime.utc_now()

    query
    |> where(
      [a],
      (not is_nil(a.notification_period_end) and a.notification_period_end <= ^now) or
        (not is_nil(a.active_period_end) and a.active_period_end <= ^now)
    )
  end

  def timeline_filter(query, %Filter{value: "current"}, _opts) do
    now = DateTime.utc_now()
    # use active_period_start as a backup when notification_start is blank
    query
    |> where(
      [a],
      (not is_nil(a.notification_period_start) and a.notification_period_start <= ^now) or
        (is_nil(a.notification_period_start) and
           (not is_nil(a.active_period_start) and a.active_period_start <= ^now))
    )
    |> where(
      [a],
      is_nil(a.active_period_end) or a.active_period_end > ^now
    )
  end

  def timeline_filter(query, %Filter{value: _value}, _opts) do
    query
  end
end
