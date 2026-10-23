defmodule AlertsUIWeb.CreateAlertLive.Helpers.AutoText.Templates do
  @moduledoc """
    Text templates for auto-text.
    Header templates: returns a string with interpolated variables.
    | character is used when a character must be right against a variable.
    eg `?due_to_cause|:` will end up looking like `parade:`
    Description templates: for vehicle modes, the template stores counts
    over which text will appear- eg route count: 5 means that routes will
    appear in the text only if there's over 5 of them. A nil value means
    the text won't appear at all. Direction and route can check other fields
    to determine if they appear or not.
  """

  alias AlertsUIWeb.CreateAlertLive.Helpers.{
    AutoText.BuildAutoText,
    AutoText.BuildDescriptionText,
    EffectsForRouteTypes
  }

  alias AlertsUIWeb.FormComponents.Helpers.EffectsForRouteTypes

  @systemwide_effects EffectsForRouteTypes.list_effects(:systemwide)

  @templates [
    # access
    %{
      pattern: {nil, "Bike Issue"},
      header_template: "?facility_names|: issue ?alert_duration ?due_to_cause|.",
      service_effect_template: "?stop_names bicycle issue"
    },
    %{
      pattern: {nil, "Escalator Closure"},
      header_template:
        "?facility_names ?facility_form unavailable ?alert_duration ?due_to_cause|.",
      service_effect_template: "?stop_names escalator unavailable"
    },
    %{
      pattern: {nil, "Parking Closure"},
      header_template: "?facility_names ?facility_form closed ?alert_duration ?due_to_cause|.",
      service_effect_template: "?stop_names parking closure"
    },
    %{
      pattern: {nil, "Elevator Closure"},
      header_template:
        "?facility_names ?facility_form unavailable ?alert_duration ?due_to_cause|.",
      service_effect_template: "?stop_names elevator unavailable"
    },
    %{
      pattern: {nil, "Access Issue"},
      header_template: "?facility_names|: issue ?alert_duration ?due_to_cause|.",
      service_effect_template: "?stop_names access issue"
    },
    %{
      pattern: {nil, "Facility Issue"},
      header_template: "?facility_names|: issue ?alert_duration ?due_to_cause|.",
      service_effect_template: "?stop_names issue"
    },
    %{
      pattern: {nil, "Parking Issue"},
      header_template: "?facility_names|: issue ?alert_duration ?due_to_cause|.",
      service_effect_template: "?stop_names parking issue"
    },

    # systemwide
    %{
      pattern: {nil, "Service Change"},
      header_template: "?impacted_modes service change ?alert_duration ?due_to_cause|.",
      service_effect_template: "?impacted_modes service change"
    },
    %{
      pattern: {nil, "Suspension"},
      header_template:
        "?impacted_modes service ?singular_copula suspended ?alert_duration ?due_to_cause|.",
      service_effect_template: "?impacted_modes service suspension"
    },
    %{
      pattern: {nil, "Amber Alert"},
      header_template: "Amber Alert",
      service_effect_template: "Amber Alert"
    },
    %{
      pattern: {nil, "Notice"},
      header_template: "?impacted_modes notice ?alert_duration ?due_to_cause|.",
      service_effect_template: "?impacted_modes notice"
    },
    %{
      pattern: {nil, "Policy Change"},
      header_template: "Policy change affecting ?impacted_modes service|.",
      service_effect_template: "?impacted_modes policy change"
    },
    %{
      pattern: {nil, "Delay"},
      header_template:
        "?impacted_modes service may experience delays ?alert_duration ?due_to_cause|.",
      service_effect_template: "?impacted_modes delays"
    },
    %{
      pattern: {nil, "Summary"},
      header_template: "?impacted_modes notice ?alert_duration ?due_to_cause|.",
      service_effect_template: "?impacted_modes notice"
    },
    %{
      pattern: {nil, "Schedule Change"},
      header_template: "Planned ?impacted_modes schedule change ?alert_duration ?due_to_cause|.",
      service_effect_template: "?impacted_modes schedule change"
    },
    %{
      pattern: {nil, "Extra Service"},
      header_template: "Extra ?impacted_modes service ?alert_duration ?due_to_cause|.",
      service_effect_template: "Extra ?impacted_modes service"
    },

    # Ferry
    %{
      pattern: {4, "Dock Bypass"},
      header_template:
        "?route_names ?direction_name ?trip_names will not stop at ?stop_names ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: 2,
        direction_count: 1
      },
      service_effect_template: "?stop_names bypassed"
    },
    %{
      pattern: {4, "Dock Closure"},
      header_template: "?stop_names ?stop_form closed ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 0,
        stop_count: 2,
        trip_count: nil,
        direction_count: nil
      },
      service_effect_template: "?stop_names closed"
    },
    %{
      pattern: {4, "Suspension"},
      header_template:
        "?route_names ?direction_name ?trip_names|: service ?singular_copula suspended ?stop_range_between ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: 2,
        direction_count: nil
      },
      service_effect_template: "Suspension of service on ?route_names_short"
    },
    %{
      pattern: {4, "Cancellation"},
      header_template:
        "?route_names ?trip_names ?trip_form cancelled ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: nil,
        trip_count: 2,
        direction_count: 1
      },
      service_effect_template: "?route_names_short trip cancelled"
    },
    %{
      pattern: {4, "Delay"},
      header_template:
        "?route_names ?trip_names operating ?severity_name late ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: 2,
        direction_count: 1
      },
      service_effect_template: "?route_names_short delay"
    },
    %{
      pattern: {4, "Shuttle"},
      header_template:
        "?route_names ?direction_name ?trip_names will be replaced by shuttle buses ?stop_range_between ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        direction_count: nil,
        stop_count: 0,
        trip_count: 2
      },
      service_effect_template: "?route_names_short shuttle"
    },
    %{
      pattern: {4, "Dock Issue"},
      header_template: "Dock issue at ?stop_names ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 0,
        stop_count: 2,
        trip_count: nil,
        direction_count: nil
      },
      service_effect_template: "Dock issue at ?stop_names"
    },

    # Bus
    %{
      pattern: {3, "Stop Closure"},
      header_template: "?stop_names ?stop_form closed ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 0,
        stop_count: 2,
        trip_count: nil,
        direction_count: nil
      },
      service_effect_template: "?stop_names closed"
    },
    %{
      pattern: {3, "Delay"},
      header_template:
        "?route_names ?route_form experiencing ?direction_name delays of ?severity_name ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: nil,
        direction_count: nil
      },
      service_effect_template: "?route_names_short delay"
    },
    %{
      pattern: {3, "Suspension"},
      header_template:
        "?route_names ?direction_name service ?singular_copula suspended ?stop_range_between ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: nil,
        direction_count: nil
      },
      service_effect_template: "Suspension of service on ?route_names"
    },
    %{
      pattern: {3, "Multi-Route Detour"},
      header_template:
        "?route_names ?route_form detoured ?alert_duration|, skipping ?stop_names ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: nil,
        direction_count: nil
      },
      service_effect_template: "?route_names_short detour"
    },
    %{
      pattern: {3, "Stop Move"},
      header_template: "?stop_names ?stop_form moving ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 0,
        stop_count: 2,
        trip_count: nil,
        direction_count: nil
      },
      service_effect_template: "?stop_names stop moved"
    },
    %{
      pattern: {3, "Detour"},
      header_template:
        "?route_names ?direction_name ?route_form detoured ?alert_duration| ?skipping_stop_text ?due_to_cause|. ?closest_stop_text",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: nil,
        direction_count: 1
      },
      service_effect_template: "?route_names_short detour"
    },
    %{
      pattern: {3, "Snow Route"},
      header_template: "?route_names snow route in effect ?alert_duration|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: nil,
        direction_count: 1
      },
      service_effect_template: "?route_names_short on snow route"
    },

    # subway
    %{
      pattern: {1, "Suspension"},
      header_template:
        "?route_names|: ?direction_name service ?singular_copula suspended ?stop_range_between ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: nil,
        direction_count: nil
      },
      service_effect_template: "Suspension of service on ?route_names_short"
    },
    %{
      pattern: {1, "Delay"},
      header_template: "?route_names|: ?direction_name delays of ?severity_name ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: nil,
        direction_count: nil
      },
      service_effect_template: "?route_names_short delay"
    },
    %{
      pattern: {1, "Notice"},
      header_template: "?route_names notice ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: nil,
        direction_count: 1
      },
      service_effect_template: "?route_names notice"
    },
    %{
      pattern: {1, "Service Change"},
      header_template: "?route_names service change ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: nil,
        direction_count: 1
      },
      service_effect_template: "?route_names_short service change"
    },
    %{
      pattern: {1, "Shuttle"},
      header_template:
        "?route_names|: Shuttle buses ?plural_copula replacing ?direction_name service ?stop_range_between ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: nil,
        direction_count: nil
      },
      service_effect_template: "?route_names_short shuttle"
    },
    %{
      pattern: {1, "Single Tracking"},
      header_template:
        "?route_names|: Trains in both directions are operating on a single track  ?stop_range_between|. Riders may experience longer wait times.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: nil,
        direction_count: 1
      },
      service_effect_template: "Single tracking on ?route_names_short"
    },

    # Commuter Rail
    %{
      pattern: {2, "Delay"},
      header_template:
        "?route_names ?trip_names ?trip_form operating ?severity_name behind schedule ?stop_range_between ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        direction_count: 1,
        stop_count: 0,
        trip_count: 2
      },
      service_effect_template: "?route_names_short delay"
    },
    %{
      pattern: {2, "Shuttle"},
      header_template:
        "?route_names ?direction_name ?trip_names will be replaced by a shuttle bus ?stop_range_between ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        direction_count: nil,
        stop_count: 0,
        trip_count: 2
      },
      service_effect_template: "?route_names_short shuttle"
    },
    %{
      pattern: {2, "Track Change"},
      header_template:
        "Please board ?route_names ?trip_names on the ___ platform (Track ___) ?stop_range_at ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        direction_count: 1,
        stop_count: 2,
        trip_count: 2
      },
      service_effect_template: "?route_names_short track change"
    },
    %{
      pattern: {2, "Cancellation"},
      header_template:
        "?route_names ?trip_names ?trip_form cancelled ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        direction_count: 1,
        stop_count: nil,
        trip_count: 2
      },
      service_effect_template: "?route_names_short train cancelled"
    },
    %{
      pattern: {2, "Service Change"},
      header_template: "?route_names ?trip_names service change ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        direction_count: 1,
        stop_count: 0,
        trip_count: 2
      },
      service_effect_template: "?route_names_short service change"
    },
    %{
      pattern: {2, "Suspension"},
      header_template:
        "?route_names ?direction_name ?trip_names|: service ?singular_copula suspended ?stop_range_between ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: 2,
        direction_count: nil
      },
      service_effect_template: "Suspension of service on ?route_names_short"
    },

    # mode not specified
    %{
      pattern: {"Service Change"},
      header_template: "?route_names service change ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: 2,
        direction_count: 1
      },
      service_effect_template: "?route_names_short service change"
    },
    %{
      pattern: {"Shuttle"},
      header_template:
        "Shuttle buses ?plural_copula replacing ?route_names ?direction_name service ?stop_range_between ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: nil,
        direction_count: nil
      },
      service_effect_template: "?route_names_short shuttle"
    },
    %{
      pattern: {"Extra Service"},
      header_template: "Extra service on ?route_names ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: nil,
        trip_count: nil,
        direction_count: nil
      },
      service_effect_template: "Extra ?route_names_short service"
    },
    %{
      pattern: {"Station Closure"},
      header_template: "?stop_names ?stop_form closed ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 0,
        stop_count: 2,
        trip_count: nil,
        direction_count: nil
      },
      service_effect_template: "?stop_names closed"
    },
    %{
      pattern: {"Delay"},
      header_template:
        "?route_names ?trip_names experiencing ?direction_name delays of ?severity_name ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 2,
        trip_count: 2,
        direction_count: 1
      },
      service_effect_template: "?route_names_short delay"
    },
    %{
      pattern: {"Notice"},
      header_template: "?route_names notice ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 2,
        trip_count: 2,
        direction_count: 1
      },
      service_effect_template: "?route_names notice"
    },
    %{
      pattern: {"Schedule Change"},
      header_template: "Planned schedule change on ?route_names ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: nil,
        trip_count: nil,
        direction_count: nil
      },
      service_effect_template: "?route_names_short schedule change"
    },
    %{
      pattern: {"Station Issue"},
      header_template: "Station issue at ?stop_names ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 0,
        stop_count: 2,
        trip_count: nil,
        direction_count: nil
      },
      service_effect_template: "Station issue at ?stop_names"
    },
    %{
      pattern: {"Station Bypass"},
      header_template:
        "?route_names ?direction_name ?trip_names will not stop at ?stop_names ?alert_duration ?due_to_cause|.",
      description_template: %{
        route_count: 5,
        stop_count: 0,
        trip_count: 2,
        direction_count: 1
      },
      service_effect_template: "?stop_names bypassed"
    }
  ]

  @spec build_auto_text(BuildAutoText.t(), atom()) :: String.t()
  def build_auto_text(
        %{route_type: nil, effect_name: effect_name},
        :description_template
      )
      when effect_name in @systemwide_effects do
    ""
  end

  def build_auto_text(
        %{route_type: :facility, effect_name: _effect_name} = autotext_data,
        :description_template
      ) do
    # access
    build_auto_text(Map.put(autotext_data, :route_type, nil), :description_template)
  end

  def build_auto_text(
        %{route_type: nil, effect_name: _effect_name} = autotext_data,
        :description_template
      ) do
    # access
    BuildDescriptionText.affected_facilities(autotext_data)
  end

  def build_auto_text(
        %{route_type: route_type, effect_name: effect_name} = autotext_data,
        :description_template
      )
      when effect_name not in [nil, ""] and not is_nil(route_type) do
    %{
      description_template: %{
        route_count: route_count,
        trip_count: trip_count,
        stop_count: stop_count,
        direction_count: direction_count
      }
    } =
      Enum.find(@templates, fn %{pattern: pattern} ->
        match?(^pattern, {route_type, effect_name}) || match?(^pattern, {effect_name})
      end)

    route_text = get_route_text(route_count, autotext_data)
    direction_text = get_direction_text(direction_count, autotext_data)
    stop_text = get_stop_text(stop_count, autotext_data)
    schedule_text = get_trip_text(trip_count, autotext_data)

    "#{route_text}#{direction_text}#{stop_text}#{schedule_text}" |> String.trim()
  end

  def build_auto_text(
        %{route_type: route_type, effect_name: effect_name} = autotext_data,
        template_type
      ) do
    templates =
      Enum.find(@templates, fn %{pattern: pattern} ->
        match?(^pattern, {route_type, effect_name}) || match?(^pattern, {effect_name})
      end)

    templates[template_type] |> build_template(autotext_data)
  end

  defp get_route_text(route_count, %{schedules: [], routes: routes} = autotext_data)
       when not is_nil(route_count) and length(routes) > route_count do
    # do not return route text if there are any trips
    BuildDescriptionText.affected_routes(autotext_data) <> "\n\n"
  end

  defp get_route_text(_, _), do: ""

  defp get_direction_text(1, %{direction: [_direction], stops: [], route_type: 3} = autotext_data) do
    # do not return direction text if there are any stops (bus only)
    BuildDescriptionText.affected_direction(autotext_data) <> "\n\n"
  end

  defp get_direction_text(1, %{stops: [_ | _], route_type: 3}), do: ""

  defp get_direction_text(1, %{direction: [_direction], schedules: []} = autotext_data) do
    # do not return direction text if there are any trips (other modes)
    BuildDescriptionText.affected_direction(autotext_data) <> "\n\n"
  end

  defp get_direction_text(_, _), do: ""

  defp get_stop_text(stop_count, %{stops: stops} = autotext_data)
       when not is_nil(stop_count) and length(stops) > stop_count do
    BuildDescriptionText.affected_stops(autotext_data) <> "\n\n"
  end

  defp get_stop_text(_, _), do: ""

  defp get_trip_text(schedule_count, %{schedules: schedules} = autotext_data)
       when not is_nil(schedule_count) and length(schedules) > schedule_count do
    BuildDescriptionText.affected_trips(autotext_data) <> "\n\n"
  end

  defp get_trip_text(_, _), do: ""

  defp build_template(nil, _), do: ""

  defp build_template(template, autotext_data) do
    template
    |> String.replace("|", " |")
    |> String.split(" ")
    |> Enum.map_join(" ", fn word ->
      if String.starts_with?(word, "?") do
        get_function_result(word, autotext_data)
      else
        word
      end
    end)
    |> String.replace(" |", "")
    |> String.replace(~r/\s{2,}/, " ")
    |> String.replace(" :", ":")
    |> String.replace(" ,", ",")
    |> String.replace(" .", ".")
    |> String.replace(",.", ".")
    |> String.trim()
  end

  defp get_function_result(string, autotext_data) do
    # calls the function indicated by the template variable
    # the functions all live in the BuildAutoText module
    # and their names match up with the variable minus the ?
    function_name = string |> String.replace("?", "") |> String.to_existing_atom()
    apply(BuildAutoText, function_name, [autotext_data])
  end
end
