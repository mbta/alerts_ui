defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.AlertDetailsSlice do
  @moduledoc """
  Slice that manages the core alert details: header text, description, cause,
  severity, URL, and image. Drives auto-text generation from route/effect context
  and validates text fields and media URLs.
  """

  import Ecto.Changeset

  alias AlertsUI.Models.{Alert, Cause, SeverityLevel}
  alias AlertsUIWeb.CreateAlertMonoLive.Helpers.Path, as: EffectHelper
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.AccessAffectedServiceSlice
  alias AlertsUIWeb.FormComponents.Helpers.AutoText.{AlertDataToAutoText, Templates}
  alias AlertsUIWeb.FormComponents.Helpers.{DateTimeHelpers, GetKeyForModeEffect}
  alias MBTAV3API.Stops.Stop
  alias Phoenix.LiveView.AsyncResult

  use AlertsUIWeb, :html

  defstruct [
    :effect_name,
    :route_type,
    :combination,
    # time range
    :active_period_start_specifier,
    :active_period_end_specifier,
    :active_period_start_time_specifier,
    :active_period_end_time_specifier,
    :active_period_start,
    :active_period_end,
    :active_period_start_date,
    :active_period_end_date,
    :active_period_start_time,
    :active_period_end_time,
    :alert_timing,
    :recurrence_days,
    # affected service
    :severity,
    :cause_detail,
    :image_alternative_text,
    direction: [],
    header_text: "",
    header_sync_toggle: true,
    description_text: "",
    description_sync_toggle: true,
    service_effect_text: "",
    image_url: "",
    url: ""
  ]

  defimpl Slice, for: __MODULE__ do
    import Ecto.Changeset
    alias AlertsUI.Models.Alert
    alias AlertsUIWeb.CreateAlertMonoLive.Helpers.Validation
    alias AlertsUIWeb.CreateAlertMonoLive.Slices.AccessAffectedServiceSlice
    alias AlertsUIWeb.FormComponents.Helpers.DateTimeHelpers
    alias MBTAV3API.Stops.Stop
    alias Phoenix.LiveView.AsyncResult

    @severity_options SeverityLevel.severity_tuples()
                      |> Enum.map(fn {desc, severity, _level} -> {desc, severity} end)

    @required_fields %{header_text: "can't be blank"}

    @cdn_host "cdn.mbta.com"

    @time_range_fields [
      :active_period_start_specifier,
      :active_period_end_specifier,
      :active_period_start_time_specifier,
      :active_period_end_time_specifier,
      :active_period_start,
      :active_period_end,
      :active_period_start_date,
      :active_period_end_date,
      :active_period_start_time,
      :active_period_end_time,
      :alert_timing,
      :recurrence_days
    ]

    def mount(_details_data, socket, _base_params), do: socket

    def extract(details_data, _alert, _params) do
      details_data
      |> Map.drop(@time_range_fields)
      |> remove_invalid_cause_detail()
    end

    def transform(details_data, changeset, params, socket) do
      effect_name = EffectHelper.effect_from_url_name(details_data.effect_name || "")

      severity = get_severity(details_data, effect_name)
      cause_detail = get_cause_detail(details_data, effect_name)

      # checking for a nil target prevents autotext from changing when the user hasn't actually selected
      # anything (eg upon submission)
      # if trying to get this to fire in a test, you need to add eg `_target: [:foo, "header_text"]` to
      # the map you give to render_change
      [_, target | _] = Map.get(params, "_target", [nil, nil])

      header_sync_toggle = header_sync_toggle(target, details_data.header_sync_toggle)

      description_sync_toggle =
        description_sync_toggle(target, details_data.description_sync_toggle)

      details_params =
        %{
          header_sync_toggle: header_sync_toggle,
          description_sync_toggle: description_sync_toggle,
          severity: severity,
          cause_detail: cause_detail,
          image_alternative_text: details_data.image_alternative_text
        }

      Enum.reduce(details_params, changeset, fn {key, value}, changeset ->
        force_change(changeset, key, value)
      end)
      |> update_cause_from_detour(target, socket.assigns.skate_detours)
    end

    defp update_cause_from_detour(
           changeset,
           "skate_detour_id",
           %AsyncResult{ok?: true, result: skate_detours}
         ) do
      detour_id = get_field(changeset, :skate_detour_id)
      detour = Enum.find(skate_detours, &(&1.id == detour_id))
      new_cause = (Map.get(detour, :reason) || "") |> String.upcase() |> String.replace(" ", "_")

      force_change(changeset, :cause_detail, new_cause)
    end

    defp update_cause_from_detour(changeset, _target, _), do: changeset

    defp header_sync_toggle("header_text", true), do: false
    defp header_sync_toggle(_, current_toggle), do: current_toggle

    defp description_sync_toggle("description_text", true), do: false
    defp description_sync_toggle(_, current_toggle), do: current_toggle

    def validate(details_data, changeset, _params, socket) do
      # Validate URLs on change, but required fields only on submit
      image_url = details_data.image_url
      image_size = image_url |> get_image_size()

      changeset =
        changeset
        |> validate_url(get_field(changeset, :url))
        |> validate_image_fields(image_size, image_url)

      if socket.assigns.submitted? do
        changeset
        |> Validation.always_validate_required(@required_fields)
      else
        changeset
      end
    end

    def assigns(_details_data, socket, _params) do
      form = socket.assigns.form
      form_data = Map.merge(form.source.data, form.source.changes)

      cause_options =
        formatted_causes(
          form_data.route_type,
          form_data.combination
        )

      image_url = form_data.image_url
      image_size = get_image_size(image_url)
      image_path = get_image_path(image_url)

      assign(socket, %{
        cause_options: cause_options,
        severity_options: @severity_options,
        image_size: image_size,
        image_path: image_path
      })
    end

    defp remove_invalid_cause_detail(
           %{combination: combination, route_type: route_type, cause_detail: cause_detail} =
             details_data
         ) do
      # remove an existing cause detail if it's not
      # currently valid
      mode = if combination == :ACCESS, do: :ACCESS, else: route_type

      valid_causes =
        mode
        |> Cause.cause_map_by_mode()
        |> Map.keys()

      new_cause_detail =
        if cause_detail in valid_causes, do: cause_detail, else: nil

      Map.put(details_data, :cause_detail, new_cause_detail)
    end

    defp get_severity(%{severity: nil, route_type: route_type}, effect_name) do
      GetKeyForModeEffect.get_value_of_key(
        :default_severity,
        route_type,
        effect_name
      )
    end

    defp get_severity(%{severity: severity}, _effect_name), do: severity

    defp get_cause_detail(%{cause_detail: nil, route_type: route_type}, effect_name) do
      GetKeyForModeEffect.get_value_of_key(
        :default_cause,
        route_type,
        effect_name
      )
    end

    defp get_cause_detail(%{cause_detail: cause_detail}, _effect_name), do: cause_detail

    defp formatted_causes(route_type, combination) do
      mode = if combination == :ACCESS, do: :ACCESS, else: route_type

      options_list =
        mode
        |> Cause.cause_map_by_mode()
        |> Map.keys()
        |> Enum.map(fn cause_detail ->
          display_name =
            cause_detail
            |> String.replace("_", " ")
            |> String.downcase()
            |> String.replace("amtrak", "Amtrak")
            |> String.replace("coast guard", "Coast Guard")

          {display_name, cause_detail}
        end)

      [{"<none>", ""} | options_list]
    end

    defp validate_url(changeset, url_field) when url_field in [nil, ""] do
      changeset
    end

    defp validate_url(changeset, _url_field) do
      changeset
      |> validate_change(:url, fn :url, url ->
        with {:ok, parsed_url} <- URI.new(url),
             true <- url_valid?(parsed_url) do
          []
        else
          _ -> [url: "Enter a correctly formatted URL (e.g. http://www.example.com) "]
        end
      end)
    end

    defp validate_image_fields(changeset, _image_size, image_url) when image_url in [nil, ""] do
      changeset
    end

    defp validate_image_fields(changeset, image_size, _image_url) do
      changeset
      |> Ecto.Changeset.validate_change(:image_url, fn :image_url, image_url ->
        if image_url !== "" and is_number(image_size),
          do: [],
          else: [image_url: "Enter a valid image URL"]
      end)
      |> validate_alt_text(Map.get(changeset.changes, :image_url))
    end

    defp validate_alt_text(changeset, image_url) when image_url in [nil, ""] do
      changeset
    end

    defp validate_alt_text(changeset, _image_url) do
      Ecto.Changeset.validate_required(changeset, :image_alternative_text,
        message: "Enter alt text"
      )
    end

    defp url_valid?(uri) do
      uri.scheme in ["http", "https"] && !is_nil(uri.host) && uri.host =~ "."
    end

    defp image_from_correct_host?(host), do: host == @cdn_host

    defp get_image_size(nil), do: nil

    defp get_image_size(url) do
      with {:ok, parsed_url} <- URI.new(url),
           true <- url_valid?(parsed_url),
           true <- image_from_correct_host?(parsed_url.host),
           {:ok,
            %{headers: %{"content-type" => content_type, "content-length" => [content_length]}}} <-
             Req.head(url),
           true <- content_type |> Enum.all?(&String.starts_with?(&1, "image/")),
           {integer, _} <- Integer.parse(content_length) do
        (integer / 1_000_000) |> Float.round(2)
      else
        _ -> nil
      end
    end

    defp get_image_path(nil), do: nil
    defp get_image_path(""), do: nil

    defp get_image_path(url) when is_binary(url),
      do: url |> Path.split() |> List.last() |> String.split("?") |> hd
  end

  defp get_direction("0"), do: [0]
  defp get_direction("1"), do: [1]
  defp get_direction("default"), do: [0, 1]
  defp get_direction(direction), do: direction

  defp translated_details(details_data) do
    Map.merge(details_data, %{
      effect_name: EffectHelper.effect_from_url_name(details_data.effect_name || ""),
      direction: get_direction(Map.get(details_data, :direction)),
      start_specifier: details_data.active_period_start_specifier,
      end_specifier: details_data.active_period_end_specifier,
      start_time_specifier: details_data.active_period_start_time_specifier,
      end_time_specifier: details_data.active_period_end_time_specifier,
      start_datetime: details_data.active_period_start,
      end_datetime: details_data.active_period_end,
      start_date: details_data.active_period_start_date,
      end_date: details_data.active_period_end_date,
      start_time: details_data.active_period_start_time,
      end_time: details_data.active_period_end_time
    })
  end

  defp selected_objects(selections, _form) when selections in [%{}, nil], do: %{}

  defp selected_objects(
         %AccessAffectedServiceSlice.Selections{} = selections,
         data
       ) do
    facility_ids = Map.get(data, :facility_ids) || []

    all_facilities =
      if is_map(selections.available_facilities) do
        Map.get(selections.available_facilities, :facilities, [])
      else
        []
      end

    facilities = Enum.filter(all_facilities, &(&1.id in facility_ids))
    %{facilities: facilities}
  end

  defp selected_objects(selections, data) do
    route_ids = Map.get(data, :route_ids) || []
    stop_ids = Map.get(data, :stop_ids) || []
    trip_ids = Map.get(data, :trip_ids) || []

    routes = Enum.filter(selections.available_routes || [], &(&1.id in route_ids))

    stops_from_original =
      (Map.get(data, :stop_names_and_ids) || [])
      |> Alert.get_original_names_and_ids()
      |> Enum.map(fn {name, id} -> %Stop{name: name, id: id} end)
      |> Enum.filter(&(&1.id in stop_ids))

    original_ids = MapSet.new(stops_from_original, & &1.id)

    # we need selected stop names
    stops_from_available =
      Enum.filter(
        selections.available_stops || [],
        &(&1.id in stop_ids and &1.id not in original_ids)
      )

    stops = stops_from_original ++ stops_from_available

    schedules =
      Enum.filter(Map.get(selections, :available_schedules) || [], &(&1.trip.id in trip_ids))

    %{routes: routes, stops: stops, schedules: schedules}
  end

  defp unwrap_selections(assigns) do
    case Map.get(assigns, :selections) do
      %AsyncResult{ok?: true} = async_result -> async_result.result
      selections -> selections
    end
  end

  defp unwrap_detours(assigns) do
    case Map.get(assigns, :skate_detours) do
      %AsyncResult{ok?: true} = async_result -> async_result.result
      _ -> []
    end
  end

  defp get_connection_points(%{connection_points: [_ | _] = connection_points}, [_ | _] = stops) do
    stops
    |> Enum.filter(fn stop -> stop.id in connection_points end)
    |> Enum.uniq_by(& &1.id)
    |> Enum.map(
      &(&1.name
        |> String.replace(" (inbound)", "")
        |> String.replace(" (outbound)", ""))
    )
  end

  defp get_connection_points(%{connection_points: []}, _), do: []

  defp get_connection_points(_, _), do: nil

  def autotext_map(alert_data, assigns) do
    selections = assigns |> unwrap_selections()

    selected =
      selections |> selected_objects(alert_data)

    detour =
      assigns
      |> unwrap_detours
      |> Enum.find(%{}, &(&1.id == Map.get(alert_data, :skate_detour_id)))

    # You need to give this all the stops in selections
    # instead of stop names and ids
    connection_points = get_connection_points(detour, Map.get(selections, :available_stops))

    autotext_data =
      alert_data
      |> translated_details()
      |> Map.merge(selected)
      |> Map.merge(%{
        missed_stops: Map.get(detour, :missed_stops),
        connection_points: connection_points,
        service_types: alert_data.service_types,
        current_time: DateTimeHelpers.current_time()
      })
      |> AlertDataToAutoText.build_autotext_data()

    header_text =
      if alert_data.header_sync_toggle == false do
        alert_data.header_text
      else
        Templates.build_auto_text(autotext_data, :header_template)
      end

    description_text =
      if alert_data.description_sync_toggle == false do
        alert_data.description_text
      else
        Templates.build_auto_text(autotext_data, :description_template)
      end

    service_effect_text = Templates.build_auto_text(autotext_data, :service_effect_template)

    %{
      header_text: header_text,
      description_text: description_text,
      service_effect_text: service_effect_text
    }
  end

  def render(assigns) do
    alert_data = Map.merge(assigns.form.source.data, assigns.form.source.changes)

    assigns = assign(assigns, autotext_map(alert_data, assigns))

    ~H"""
    <div class="min-w-full flex flex-col mt-4" id="details_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Alert details
      </.h5>
      <div class="flex flex-col gap-4">
        <div class="flex flex-col md:flex-row md:w-[50%]">
          <.select
            label="Cause"
            field={@form[:cause_detail]}
            options={@cause_options}
            class="shrink min-w-0 md:mr-8"
            id="cause_input"
          />
          <.select
            label="Severity"
            field={@form[:severity]}
            options={@severity_options}
            class="shrink grow min-w-0"
            id="severity_input"
          />
        </div>
        <div class="flex flex-col md:flex-row">
          <div class="flex flex-col md:w-[50%]">
            <.textarea
              field={@form[:header_text]}
              label="Main message"
              phx-debounce={120}
              maxlength="255"
              id="header_input"
              class={
                [
                  "w-[100%] min-h-[10rem] z-20 mt-3",
                  if(String.length(@form[:header_text].value || "") >= 255,
                    do: "!border-error border-b-1",
                    else: "border-b-0"
                  )
                ]
                |> Enum.join(" ")
              }
              value={@header_text}
            />
            <.textarea_footer
              character_limit={255}
              copy_id="#alert_data_header_text"
              copy_title="Copy main message to Clipboard"
              field={@form[:header_text]}
            />
          </div>
          <.form_checkbox
            class="mt-2 md:ml-4 md:mt-8"
            field={@form[:header_sync_toggle]}
            label="Auto refresh"
          />
        </div>
        <div class="flex flex-col md:flex-row">
          <div class="flex flex-col md:w-[50%]">
            <.textarea
              field={@form[:description_text]}
              label="Supporting information"
              phx-debounce={120}
              id="description_input"
              class={
                [
                  "w-[100%] min-h-[10rem] z-20 mt-3",
                  if(String.length(@form[:description_text].value || "") >= 3000,
                    do: "!border-error border-b-1",
                    else: "border-b-0"
                  )
                ]
                |> Enum.join(" ")
              }
              maxlength="3000"
              value={@description_text}
            />
            <.textarea_footer
              character_limit={3000}
              copy_id="#alert_data_description_text"
              copy_title="Copy supporting information to Clipboard"
              field={@form[:description_text]}
            />
          </div>
          <.form_checkbox
            class="mt-2 md:ml-4 md:mt-8"
            field={@form[:description_sync_toggle]}
            label="Auto refresh"
          />
        </div>
        <.text_input
          field={@form[:url]}
          label="URL"
          phx-debounce={500}
          id="url_input"
          class="md:min-w-[50%]"
        />
        <div id="image-preview-div">
          <.text_input
            field={@form[:image_url]}
            label="Image URL"
            phx-debounce={500}
            id="image_url_input"
            class={[
              "md:min-w-[50%]",
              if(@form[:image_url].value not in ["", nil] && is_number(@image_size),
                do: "border-b-0 rounded-none rounded-t"
              )
            ]}
          />
          <div
            :if={@form[:image_url].value not in ["", nil] && @image_size != nil}
            id="image-information"
            class="flex flex-col md:flex-row md:w-[50%] text-sm text-text-secondary bg-bg-elevation-3 p-4 rounded-b border border-bg-elevation-6 border-t-0"
          >
            <img
              src={@form[:image_url].value}
              class={["md:max-h-[8rem] mt-4", if(@form[:image_url].value in ["", nil], do: "hidden")]}
            />
            <div class="flex flex-col justify-center mt-4 md:mt-0 md:ml-4">
              <p :if={@image_path} class="break-all">{@image_path}</p>
              <p :if={@image_size}>{"#{@image_size} mB"}</p>
            </div>
          </div>
        </div>
        <.text_input
          field={@form[:image_alternative_text]}
          label="Image alt text"
          phx-debounce={120}
          id="image_alt_text_input"
          class="md:min-w-[50%]"
          spellcheck="true"
        />
      </div>
      <hr class="mt-8" />
    </div>
    """
  end
end
