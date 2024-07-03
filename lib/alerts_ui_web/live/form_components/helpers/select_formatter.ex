defmodule AlertsUIWeb.FormComponents.Helpers.SelectFormatter do
  @moduledoc """
  Formats selection dropdowns for affected service components
  """

  alias AlertsUIWeb.DateTimeHelpers
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.{Schedule, Trip}
  alias MBTAV3API.Stops.Stop

  @spec formatted_select_options([Route.t() | Stop.t()]) :: keyword(String.t())
  def formatted_select_options(objects) do
    objects
    |> Enum.uniq()
    |> Enum.sort_by(&sort_order/1)
    |> Enum.map(fn object -> {name_for_option(object), id_for_option(object)} end)
  end

  @spec sort_order(Stop.t() | Route.t() | Schedule.t()) :: non_neg_integer() | nil
  # keep original order from API
  def sort_order(%Stop{}), do: nil
  def sort_order(%Schedule{}), do: nil
  def sort_order(%Route{sort_order: sort_order}), do: sort_order

  @spec name_for_option(Stop.t() | Route.t() | Schedule.t()) :: String.t()
  def name_for_option(%Stop{name: name}), do: name

  def name_for_option(%Route{name: empty_name, long_name: long_name})
      when is_nil(empty_name) or empty_name == "",
      do: long_name

  def name_for_option(%Route{name: name}), do: name

  def name_for_option(%Schedule{
        trip: %Trip{name: trip_name},
        stop: %Stop{name: stop_name},
        departure_time: departure_time
      }) do
    "#{trip_name} (#{DateTimeHelpers.friendly_time(departure_time)} from #{stop_name})"
  end

  @spec id_for_option(Stop.t() | Route.t() | Schedule.t()) :: String.t()
  def id_for_option(%Stop{id: id}), do: id
  def id_for_option(%Route{id: id}), do: id
  def id_for_option(%Schedule{trip: %Trip{id: id}}), do: id

  @spec formatted_trip_options(%{String.t() => [Schedule.t()]}) :: keyword(String.t())
  def formatted_trip_options(schedules_by_route_name) do
    if schedules_by_route_name |> Map.keys() |> length() <= 1 do
      schedules_by_route_name
      |> Map.values()
      |> List.flatten()
      |> formatted_select_options()
    else
      Enum.reduce(schedules_by_route_name, [], fn {route_name, schedules}, acc ->
        acc ++ [{route_name, formatted_select_options(schedules)}]
      end)
    end
  end

  @spec formatted_direction_options([String.t()] | nil) :: keyword(String.t())
  def formatted_direction_options([_ | _]) do
    [
      Outbound: "0",
      Inbound: "1"
    ]
  end

  def formatted_direction_options(_), do: []
end
