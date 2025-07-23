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

  @spec timeline_filter(any(), Flop.Filter.t(), any()) :: Ecto.Query.t()
  def timeline_filter(query, %Filter{value: "future"}, _opts) do
    now = DateTime.utc_now()

    query
    |> where(
      [a],
      not is_nil(a.notification_period_start) and a.notification_period_start > ^now
    )
    |> order_by(
      asc_nulls_last: :notification_period_end,
      asc: :duration_certainty,
      asc_nulls_last: :active_period_end,
      asc: :active_period_start
    )
  end

  def timeline_filter(query, %Filter{value: "past"}, _opts) do
    now = DateTime.utc_now()

    query
    |> where([a], not is_nil(a.active_period_end) and a.active_period_end <= ^now)
    |> order_by(
      desc: :notification_period_end,
      desc: :active_period_end,
      desc: :active_period_start
    )
  end

  def timeline_filter(query, %Filter{value: "current"}, _opts) do
    now = DateTime.utc_now()

    query
    |> where(
      [a],
      not is_nil(a.active_period_start) and a.active_period_start < ^now and
        (is_nil(a.active_period_end) or a.active_period_end > ^now)
    )
    |> order_by(
      asc_nulls_last: :notification_period_end,
      asc: :duration_certainty,
      asc_nulls_last: :active_period_end,
      asc: :active_period_start
    )
  end

  def timeline_filter(query, %Filter{value: _value}, _opts) do
    order_by(query,
      desc: :notification_period_end,
      desc: :duration_certainty,
      desc: :active_period_end,
      desc: :active_period_start
    )
  end
end
