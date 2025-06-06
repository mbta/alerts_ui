defmodule AlertsUIWeb.FormComponents.Helpers.AutoText.Templates do
  @moduledoc """
    Text templates for auto-text.
    | character is used when a character must be right against a variable.
    eg `?due_to_cause|:` will end up looking like `parade:`
  """

  alias AlertsUIWeb.FormComponents.Helpers.AutoText.BuildAutoText

  @templates [
    # access
    %{
      pattern: {nil, "Bike Issue"},
      header_template: "?facility_name issue ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {nil, "Escalator Closure"},
      header_template: "?facility_name unavailable ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {nil, "Parking Closure"},
      header_template: "?facility_name closed ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {nil, "Elevator Closure"},
      header_template: "?facility_name unavailable ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {nil, "Access Issue"},
      header_template: "?facility_name issue ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {nil, "Facility Issue"},
      header_template: "?facility_name issue ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {nil, "Parking Issue"},
      header_template: "?facility_name issue ?alert_duration ?due_to_cause"
    },
    # systemwide
    %{
      pattern: {nil, "Service Change"},
      header_template: "?impacted_modes notice: ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {nil, "Suspension"},
      header_template: "?impacted_modes service suspended ?alert_duration ?due_to_cause"
    },
    %{pattern: {nil, "Amber Alert"}, header_template: "Amber Alert"},
    %{
      pattern: {nil, "Policy Change"},
      header_template: "Policy change affecting ?impacted_modes service"
    },
    %{
      pattern: {nil, "Delay"},
      header_template:
        "?impacted_modes service may experience delays ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {nil, "Summary"},
      header_template: "?impacted_modes notice ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {nil, "Schedule Change"},
      header_template: "Planned ?impacted_modes schedule change ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {nil, "Extra Service"},
      header_template: "Extra ?impacted_modes service ?alert_duration ?due_to_cause"
    },
    # Ferry
    %{
      pattern: {4, "Dock Closure"},
      header_template: "?stop_names closed ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {4, "Suspension"},
      header_template: "?route_names suspended ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {4, "Cancellation"},
      header_template: "?route_names ?trip_names cancelled ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {4, "Delay"},
      header_template:
        "?route_names ?trip_names operation ?severity_name late ?alert_duration ?due_to_cause"
    },
    # Bus
    %{
      pattern: {3, "Cancellation"},
      header_template: "?route_names - ?trip_names_only cancelled ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {3, "Stop Closure"},
      header_template:
        "The following ?stop_form closed ?alert_duration ?due_to_cause|: ?stop_names"
    },
    %{
      pattern: {3, "Stop Shovelling"},
      header_template:
        "?route_names ?direction_name bus stops have been cleared of snow ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {3, "Delay"},
      header_template:
        "?route_names ?route_form_only experiencing ?direction_name delays of ?severity_name ?due_to_cause"
    },
    %{
      pattern: {3, "Suspension"},
      header_template: "?route_names ?direction_name suspended ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {3, "Multi-Route Detour"},
      header_template: "?route_names detoured ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {3, "Stop Move"},
      header_template: "?stop_names stop moving ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {3, "Detour"},
      header_template: "?route_names detoured ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {3, "Snow Route"},
      header_template: "?route_names snow route in effect ?alert_duration"
    },
    # subway
    %{
      pattern: {1, "Suspension"},
      header_template:
        "?route_names|: ?direction_name service is suspended ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {1, "Delay"},
      header_template: "?route_names|: ?direction_name delays of ?severity_name ?due_to_cause"
    },
    %{
      pattern: {1, "Service Change"},
      header_template: "?route_names|: ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {1, "Shuttle"},
      header_template:
        "?route_names|: Shuttle buses replace ?direction_name service ?alert_duration ?due_to_cause"
    },

    # Commuter Rail
    %{
      pattern: {2, "Delay"},
      header_template:
        "?route_names ?trip_names ?trip_form operating ?severity_name behind schedule ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {2, "Shuttle"},
      header_template:
        "?route_names ?direction_name ?trip_names will be replaced by a shuttle bus ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {2, "Track Change"},
      header_template:
        "Please board ?route_names ?trip_names on opposite track ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {2, "Cancellation"},
      header_template:
        "?route_names ?trip_names ?trip_form cancelled ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {2, "Service Change"},
      header_template: "?route_names notice: ?trip_names ?alert_duration ?due_to_cause"
    },

    # mode not specified
    %{
      pattern: {"Service Change"},
      header_template: "?route_names notice: ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {"Dock Issue"},
      header_template: "Change at ?stop_names ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {"Shuttle"},
      header_template:
        "Shuttle buses replacing ?route_names ?direction_name service ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {"Suspension"},
      header_template:
        "?route_names ?direction_name service suspended ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {"Extra Service"},
      header_template: "Extra service on ?route_names ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {"Station Closure"},
      header_template: "?stop_names closed ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {"Delay"},
      header_template:
        "?route_names ?trip_names experiencing ?direction_name delays of ?severity_name ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {"Schedule Change"},
      header_template: "Planned schedule change on ?route_names ?alert_duration ?due_to_cause"
    },
    %{
      pattern: {"Station Issue"},
      header_template: "Change at ?stop_names ?alert_duration ?due_to_cause"
    }
  ]

  @spec build_auto_text(BuildAutoText.t(), atom()) :: String.t()
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
    |> String.replace("  ", " ")
  end

  defp get_function_result(string, autotext_data) do
    # calls the function indicated by the template variable
    # the functions all live in the BuildAutoText module
    # and their names match up with the variable minus the ?
    function_name = string |> String.replace("?", "") |> String.to_existing_atom()
    apply(BuildAutoText, function_name, [autotext_data])
  end
end
