defmodule AlertsUIWeb.FormComponents.Helpers.SelectFormatter do
  @moduledoc """
  Formats selection dropdowns for affected service components
  """

  alias AlertsUIWeb.DateTimeHelpers
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.{Schedule, Trip}
  alias MBTAV3API.Stops.Stop

  @spec formatted_select_options([Route.t() | Stop.t()], integer() | nil) :: keyword(String.t())
  def formatted_select_options(objects, route_type) do
    objects
    |> Enum.uniq()
    |> Enum.sort_by(&sort_order/1)
    |> Enum.map(fn object -> {name_for_option(object, route_type), id_for_option(object)} end)
  end

  @spec formatted_select_options([Route.t() | Stop.t()], String.t(), integer() | nil) ::
          keyword(String.t())
  def formatted_select_options(objects, filter_value, route_type, values_to_keep \\ []) do
    objects
    |> formatted_select_options(route_type)
    |> filter_options(filter_value, values_to_keep)
  end

  @spec filter_options(list(), String.t() | nil, [String.t()]) :: list()
  def filter_options(options, nil, _), do: options
  def filter_options(options, "", _), do: options

  def filter_options(options, filter_value, values_to_keep) do
    filter_value = String.downcase(filter_value || "")

    Enum.filter(options, fn {option, value} ->
      (option || "")
      |> String.downcase()
      |> String.contains?(filter_value) || value in values_to_keep
    end)
  end

  @spec sort_order(Stop.t() | Route.t() | Schedule.t() | Facility.t()) :: non_neg_integer() | nil
  # keep original order from API
  def sort_order(%Stop{}), do: nil
  def sort_order(%Schedule{}), do: nil
  def sort_order(%Facility{}), do: nil
  def sort_order(%Route{sort_order: sort_order}), do: sort_order

  @spec name_for_option(Stop.t() | Route.t() | Facility.t() | Schedule.t(), integer() | nil) ::
          String.t()
  def name_for_option(item, route_type \\ nil)
  def name_for_option(%Stop{name: name}, _rt), do: name

  def name_for_option(%Route{name: empty_name, long_name: long_name}, _rt)
      when is_nil(empty_name) or empty_name == "",
      do: long_name

  def name_for_option(%Route{name: name}, _rt), do: name

  def name_for_option(%Facility{long_name: nil, short_name: short_name}, _rt),
    do: short_name

  def name_for_option(%Facility{long_name: long_name}, _rt), do: long_name

  def name_for_option(
        %Schedule{
          stop: %Stop{name: stop_name, note: last_stop_name},
          departure_time: departure_time
        },
        4
      ) do
    "#{DateTimeHelpers.friendly_time(departure_time)} from #{stop_name} to #{last_stop_name}"
  end

  def name_for_option(
        %Schedule{
          trip: %Trip{name: trip_name},
          stop: %Stop{name: stop_name},
          departure_time: departure_time
        },
        _route_type
      ) do
    "#{trip_name} (#{DateTimeHelpers.friendly_time(departure_time)} from #{stop_name})"
  end

  @spec id_for_option(Stop.t() | Route.t() | Schedule.t() | Facility.t()) :: String.t()
  def id_for_option(%Stop{id: id}), do: id
  def id_for_option(%Route{id: id}), do: id
  def id_for_option(%Facility{id: id}), do: id
  def id_for_option(%Schedule{trip: %Trip{id: id}}), do: id

  @spec formatted_trip_options(%{String.t() => [Schedule.t()]}, integer(), String.t(), [
          String.t()
        ]) ::
          keyword(String.t())
  def formatted_trip_options(schedules_by_route_name, route_type, filter_value, options_to_keep) do
    if schedules_by_route_name |> Map.keys() |> length() <= 1 do
      schedules_by_route_name
      |> Map.values()
      |> List.flatten()
      |> formatted_select_options(filter_value, route_type, options_to_keep)
    else
      Enum.reduce(schedules_by_route_name, [], fn {route_name, schedules}, acc ->
        acc ++ [{route_name, formatted_select_options(schedules, filter_value, route_type)}]
      end)
    end
  end

  @spec formatted_direction_options([String.t()] | nil, map()) :: keyword(String.t())
  def formatted_direction_options([route_id], direction_names_map) do
    directions = Map.get(direction_names_map, route_id)

    if directions do
      Enum.map(directions, fn {k, v} ->
        {v, Integer.to_string(k)}
      end)
    else
      [
        Outbound: "0",
        Inbound: "1"
      ]
    end
  end

  def formatted_direction_options([_ | _], _) do
    [
      Outbound: "0",
      Inbound: "1"
    ]
  end

  def formatted_direction_options(_, _), do: []
end
