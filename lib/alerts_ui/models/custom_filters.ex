defmodule AlertsUI.Models.CustomFilters do
  @moduledoc """
    Home for custom flop fitlers
  """
  import Ecto.Query
  alias AlertsUI.Models.InformedEntity

  def service_type_filter(query, %Flop.Filter{value: value}, _opts) do
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
end
