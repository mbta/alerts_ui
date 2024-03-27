defmodule AlertsUI.Models.CustomFilters do
  @moduledoc """
    Home for custom flop fitlers
  """
  import Ecto.Query
  alias AlertsUI.Models.InformedEntity
  alias Flop.Filter

  def empty_filter(query, %Filter{value: _value}, _opts) do
    query
  end

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
        where(query, [a], not is_nil(a.active_period_start) and a.active_period_start > ^now)

      "past" ->
        where(query, [a], not is_nil(a.active_period_end) and a.active_period_end <= ^now)

      _current ->
        where(
          query,
          [a],
          # Not future and not past
          not (not is_nil(a.active_period_start) and a.active_period_start > ^now) and
            not (not is_nil(a.active_period_end) and a.active_period_end <= ^now)
        )
    end
  end
end
