defmodule AlertsUI.Models.CustomFilters do
  @moduledoc """
    Home for custom flop fitlers
  """
  import Ecto.Query
  alias AlertsUI.Models.{ActivePeriod, InformedEntity}
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

  def timeline_filter(query, %Filter{value: value}, _opts) do
    now = DateTime.utc_now()

    case value do
      "future" ->
        query
        |> where([a], not is_nil(a.active_period_start) and a.active_period_start > ^now)
        |> order_by(asc_nulls_last: :notification_period_end, asc: :duration_certainty, asc: :active_period_start)

      "past" ->
        query
        |> where([a], not is_nil(a.active_period_end) and a.active_period_end <= ^now)
        |> order_by(asc: :active_period_end, asc: :active_period_start)

      "current" ->
        query
        |> where(
          [a],
          not is_nil(a.active_period_start) and a.active_period_start < ^now and
            (is_nil(a.active_period_end) or a.active_period_end > ^now)
        )
        |> order_by(asc_nulls_last: :notification_period_end, asc: :duration_certainty, asc: :active_period_start)

      _all ->
        order_by(query, asc_nulls_first: :active_period_end)
    end
  end
end
