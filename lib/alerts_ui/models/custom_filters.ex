defmodule AlertsUI.Models.CustomFilters do
  @moduledoc """
    Home for custom flop fitlers
  """
  import Ecto.Query
  alias AlertsUI.Models.InformedEntity

  def service_type_filter(query, %Flop.Filter{value: value, op: _op}, _opts) do
    facility_activities =
      InformedEntity.facility_activities()
      |> Enum.map(&Atom.to_string(&1))
      |> Enum.map(&String.upcase(&1))

    case value == "access" do
      false ->
        query
        |> where([a, informed_entity: ie], ie.route_type == ^value)

      true ->
        query
        |> where(
          [a, informed_entity: ie],
          fragment(
            ~s(\(?\) && \(?\)),
            ie.activities,
            ^facility_activities
          )
        )
    end
  end
end
