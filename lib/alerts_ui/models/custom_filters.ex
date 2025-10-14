defmodule AlertsUI.Models.CustomFilters do
  @moduledoc """
    Home for custom flop fitlers
  """
  import Ecto.Query
  alias AlertsUIWeb.FormComponents.Helpers.EffectsForRouteTypes
  alias Flop.Filter

  def service_type_filter(query, %Filter{value: values}, _opts) when is_list(values) do
    access_effect_names = EffectsForRouteTypes.list_effects(:facility)
    direct_routes = values |> Enum.filter(fn x -> Integer.parse(x) != :error end)
    access_routes = values |> Enum.filter(fn x -> Integer.parse(x) == :error end)

    query
    |> distinct(true)
    |> where(
      [a, informed_entity: ie],
      ie.route_type in ^direct_routes or
        ("access" in ^access_routes and a.effect_name in ^access_effect_names)
    )
  end

  def service_type_filter(query, %Filter{value: value} = filter, opts) do
    service_type_filter(query, %{filter | value: [value]}, opts)
  end

  def effects_filter(query, _filter, _opts) do
    query
  end

  def routes_filter(query, _filter, _opts) do
    query
  end

  @spec multi_column_search_filter(Ecto.Query.t(), Flop.Filter.t(), list()) :: Ecto.Query.t()
  def multi_column_search_filter(query, %Filter{value: value}, _opts) do
    # replace slashes so we can search for commuter rail lines better
    text_search_value = String.replace(value, "/", " ")

    query
    |> where(
      [a],
      fragment("header_text_index_col @@ websearch_to_tsquery('english', ?)", ^text_search_value) or
        ilike(a.alert_id, ^value)
    )
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
      not is_nil(a.closed_timestamp) or
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
    |> where(
      [a],
      is_nil(a.closed_timestamp)
    )
  end

  def timeline_filter(query, %Filter{value: _value}, _opts) do
    query
  end
end
