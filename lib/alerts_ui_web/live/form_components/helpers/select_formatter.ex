defmodule AlertsUIWeb.FormComponents.Helpers.SelectFormatter do
  @moduledoc """
  Formats selection dropdowns for affected service components
  """

  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.FormComponents.Helpers.DateTimeFormatters
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Stop

  defstruct options: nil,
            search_term: "",
            route_type: nil,
            values_to_keep: [],
            schedules_by_route_name: nil

  @type t :: %__MODULE__{
          options: [Route.t() | Stop.t()] | nil,
          search_term: String.t(),
          route_type: integer() | nil,
          values_to_keep: [String.t()],
          schedules_by_route_name: %{} | nil
        }

  @doc """
  Returns a keyword list of names and objects given a list of structs.
  If the second arg is true and the structs are stops the values will
  be a combo of names and ids (used in affected_service only).
  Also filters out results based on a search term.

  The split_stops? option will return ids for stops as "stop_name|stop_id". This preserves the direction
  information in the name for use by the autotext generator in alert_details. This defaults to false.
  """
  @spec formatted_select_options(t(), boolean()) :: keyword(String.t())
  def formatted_select_options(select_data, split_stops? \\ false)

  def formatted_select_options(
        %__MODULE__{
          options: options,
          route_type: route_type,
          search_term: search_term,
          values_to_keep: values_to_keep
        },
        split_stops?
      )
      when not is_nil(options) do
    options
    |> Enum.uniq()
    |> Enum.sort_by(&sort_order/1)
    |> Enum.map(fn object ->
      {name_for_option(object, route_type), id_for_option(object, split_stops?)}
    end)
    |> apply_search(search_term, values_to_keep)
  end

  def formatted_select_options(
        %__MODULE__{schedules_by_route_name: schedules_by_route_name} = filterable,
        _
      )
      when not is_nil(schedules_by_route_name) do
    # if only 1 route is selected
    if schedules_by_route_name |> Map.keys() |> length() <= 1 do
      options =
        schedules_by_route_name
        |> Map.values()
        |> List.flatten()

      Map.put(filterable, :options, options)
      |> formatted_select_options()

      # else multiple routes are selected
    else
      Enum.reduce(schedules_by_route_name, [], fn {route_name, schedules}, acc ->
        acc ++ [{route_name, formatted_select_options(Map.put(filterable, :options, schedules))}]
      end)
    end
  end

  @spec apply_search(list(), String.t() | nil, [String.t()]) :: list()
  def apply_search(options, nil, _), do: options
  def apply_search(options, "", _), do: options

  def apply_search(options, search_term, values_to_keep) do
    search_term = String.downcase(search_term || "")

    Enum.filter(options, fn {option, value} ->
      (option || "")
      |> String.downcase()
      |> String.contains?(search_term) || value in values_to_keep
    end)
  end

  @spec sort_order(Stop.t() | Route.t() | EnhancedSchedule.t() | Facility.t()) ::
          non_neg_integer() | nil
  # keep original order from API
  def sort_order(%Stop{}), do: nil
  def sort_order(%EnhancedSchedule{}), do: nil
  def sort_order(%Facility{}), do: nil
  def sort_order(%Route{sort_order: sort_order}), do: sort_order

  @spec name_for_option(
          Stop.t() | Route.t() | Facility.t() | EnhancedSchedule.t(),
          integer() | nil
        ) ::
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
        %EnhancedSchedule{
          last_stop_name: last_stop_name,
          stop: %Stop{name: stop_name},
          departure_time: departure_time
        },
        4
      ) do
    "#{DateTimeFormatters.friendly_time(departure_time)} from #{stop_name} to #{last_stop_name}"
  end

  def name_for_option(
        %EnhancedSchedule{
          trip: %Trip{name: trip_name, id: trip_id},
          stop: %Stop{name: stop_name},
          departure_time: departure_time,
          use_trip_id_in_name?: true
        },
        _route_type
      ) do
    "#{trip_name} (#{DateTimeFormatters.friendly_time(departure_time)} from #{stop_name}) #{trip_id}"
  end

  def name_for_option(
        %EnhancedSchedule{
          trip: %Trip{name: trip_name},
          stop: %Stop{name: stop_name},
          departure_time: departure_time
        },
        _route_type
      ) do
    "#{trip_name} (#{DateTimeFormatters.friendly_time(departure_time)} from #{stop_name})"
  end

  def name_for_option(nil, nil), do: ""

  @doc """
  If first arg is a stop struct and the second arg is true, return a combo of stop name and id
  Otherwise this returns the IDs
  """
  @spec id_for_option(Stop.t() | Route.t() | EnhancedSchedule.t() | Facility.t(), boolean()) ::
          String.t()
  def id_for_option(%Stop{name: name, id: id}, true), do: "#{name}|#{id}"
  def id_for_option(%Stop{id: id}, false), do: id
  def id_for_option(%Route{id: id}, _), do: id
  def id_for_option(%Facility{id: id}, _), do: id
  def id_for_option(%EnhancedSchedule{trip: %Trip{id: id}}, _), do: id

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
