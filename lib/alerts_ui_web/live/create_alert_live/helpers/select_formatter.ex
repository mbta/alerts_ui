defmodule AlertsUIWeb.CreateAlertLive.Helpers.SelectFormatter do
  @moduledoc """
  Formats selection dropdowns for affected service components
  """

  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUI.Models.SkateDetour
  alias AlertsUIWeb.Helpers.DateTimeFormatters
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Stop

  defstruct options: nil,
            search_term: "",
            route_type: nil,
            values_to_keep: [],
            schedules_by_route_name: nil,
            option_prefix: "option"

  @type t :: %__MODULE__{
          options: [Route.t() | Stop.t()] | nil,
          search_term: String.t(),
          route_type: integer() | nil,
          values_to_keep: [String.t()],
          schedules_by_route_name: %{} | nil,
          option_prefix: String.t()
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
          values_to_keep: values_to_keep,
          option_prefix: option_prefix
        },
        split_stops?
      )
      when not is_nil(options) do
    options
    |> Enum.sort_by(&sort_order/1)
    |> Enum.map(fn object ->
      name = name_for_option(object, route_type)
      id = id_for_option(object, split_stops?)

      base_attrs = [key: name, value: id, id: "#{option_prefix}-#{id}"]

      if tooltip_id?(object) do
        Keyword.merge(
          base_attrs,
          title: tooltip_content(object)
        )
      else
        base_attrs
      end
    end)
    |> apply_search(search_term, values_to_keep)
    |> Enum.uniq()
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

  @spec apply_search(list() | any(), String.t() | nil, [String.t()]) :: list()
  def apply_search(options, nil, _), do: options
  def apply_search(options, "", _), do: options

  def apply_search(options, search_term, value) when not is_list(value) do
    apply_search(options, search_term, [value])
  end

  def apply_search(options, search_term, values_to_keep) do
    search_term = String.downcase(search_term || "")

    Enum.filter(options, fn option ->
      key = Keyword.get(option, :key)
      value = Keyword.get(option, :value, "")

      Enum.join([key, value], " ")
      |> String.replace("|", " ")
      |> String.downcase()
      |> String.contains?(search_term) || value in values_to_keep
    end)
  end

  @spec sort_order(Stop.t() | Route.t() | EnhancedSchedule.t() | Facility.t() | SkateDetour.t()) ::
          non_neg_integer() | nil
  # keep original order from API
  def sort_order(%Stop{}), do: nil
  def sort_order(%EnhancedSchedule{}), do: nil
  def sort_order(%Facility{}), do: nil
  def sort_order(%Route{sort_order: sort_order}), do: sort_order
  def sort_order(_), do: nil

  @spec name_for_option(
          Stop.t() | Route.t() | Facility.t() | EnhancedSchedule.t() | SkateDetour.t(),
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

  def name_for_option(
        %SkateDetour{
          nearest_intersection: nearest_intersection,
          missed_stops: missed_stops
        },
        _route_type
      ) do
    plural = if length(missed_stops) > 1, do: "s", else: ""

    if nearest_intersection do
      missed_stop_text =
        if missed_stops in [[], nil] do
          ""
        else
          " (#{length(missed_stops)} skipped stop#{plural}) "
        end

      "Start: #{nearest_intersection}#{missed_stop_text}"
    else
      "Skipped stop#{plural}: #{Enum.join(missed_stops, ",")}"
    end
  end

  def name_for_option({name, _value}, nil), do: name

  def name_for_option(_, nil), do: ""

  @doc """
  If first arg is a stop struct and the second arg is true, return a combo of stop name and id
  Otherwise this returns the IDs
  """
  @spec id_for_option(
          Stop.t() | Route.t() | EnhancedSchedule.t() | Facility.t() | SkateDetour.t(),
          boolean()
        ) ::
          String.t()
  def id_for_option(%Stop{name: name, id: id}, true), do: "#{name}|#{id}"
  def id_for_option(%Stop{id: id}, false), do: id
  def id_for_option(%Route{id: id}, _), do: id
  def id_for_option(%Facility{id: id}, _), do: id
  def id_for_option(%EnhancedSchedule{trip: %Trip{id: id}}, _), do: id
  def id_for_option(%SkateDetour{id: id}, _), do: id
  def id_for_option(option, _), do: option |> elem(1) |> to_string()

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

  defp tooltip_id?(object) do
    case object do
      %Stop{} -> true
      %EnhancedSchedule{} -> true
      %SkateDetour{} -> true
      _ -> false
    end
  end

  defp tooltip_content(%EnhancedSchedule{} = object) do
    insert_newline_in_long_tooltip("Trip ID #{id_for_option(object, false)}")
  end

  defp tooltip_content(%SkateDetour{} = detour) do
    plural = if length(detour.missed_stops) > 1, do: "s", else: ""

    last_updated = DateTimeFormatters.timestamp_date_time(detour.updated_at)
    "Last updated: #{last_updated}. (#{length(detour.missed_stops)} skipped stop#{plural})"
  end

  defp tooltip_content(object) do
    type =
      object
      |> Map.get(:__struct__, "")
      |> Atom.to_string()
      |> String.split(".")
      |> List.last()

    "#{type} ID #{id_for_option(object, false)}"
  end

  defp insert_newline_in_long_tooltip(tooltip) do
    # if the tooltip (title) is too long, split along the hyphens
    # and insert a newline character into a list item from roughly the middle
    # then put it back together
    if String.length(tooltip) > 30 do
      tooltip_list = String.split(tooltip, "-")

      midway_point = Integer.floor_div(length(tooltip_list), 2)

      tooltip_list
      |> List.replace_at(midway_point, "\n" <> Enum.at(tooltip_list, midway_point))
      |> Enum.join("-")
    else
      tooltip
    end
  end
end
