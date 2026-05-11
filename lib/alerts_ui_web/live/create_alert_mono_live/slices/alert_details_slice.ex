defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.AlertDetailsSlice do
  alias AlertsUI.Models.Alert
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.FormComponents.Helpers.AutoText.{AlertDataToAutoText, Templates}
  alias AlertsUI.Models.{Cause, EnhancedSchedule, SeverityLevel}
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias Ecto.Changeset
  use AlertsUIWeb, :html

  defstruct [
    # general
    :combination,
    :route_type,
    :effect_name,
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
    direction: [],
    route_ids: [],
    stop_ids: [],
    trip_ids: [],
    facility_ids: [],
    service_types: [],
    # selected_facilities: [],
    # selected_routes: [],
    # selected_stops: [],
    # selected_schedules: [],

    header_text: "",
    header_sync_toggle: true,
    description_text: "",
    description_sync_toggle: true,
    cause_detail: "",
    severity: 4,
    image_url: "",
    url: ""
  ]

  defimpl Slice, for: __MODULE__ do
    import Ecto.Changeset

    @severity_options SeverityLevel.severity_tuples()
                      |> Enum.map(fn {desc, severity, _level} -> {desc, severity} end)

    @required_fields ~w[header_text]a

    @cdn_host "cdn.mbta.com"

    def extract(details_data, %Alert{} = _alert, _params) do
      details_data
      |> struct()
    end

    def transform(details_data, changeset, params) do
      [_, target] = Map.get(params, "_target", [nil, nil])

      autotext_data = AlertDataToAutoText.build_autotext_data(translated_details(details_data))

      header_sync_toggle =
        if target == "header_text" and details_data.header_sync_toggle == true do
          false
        else
          details_data.header_sync_toggle
        end

      description_sync_toggle =
        if target == "description_text" and details_data.description_sync_toggle == true do
          false
        else
          details_data.description_sync_toggle
        end

      header_text = update_header_text(header_sync_toggle, details_data, autotext_data)

      description_text =
        update_description_text(description_sync_toggle, details_data, autotext_data)

      changeset
      |> change(%{
        header_sync_toggle: header_sync_toggle,
        header_text: header_text,
        description_sync_toggle: description_sync_toggle,
        description_text: description_text
      })
    end

    def validate(details_data, changeset, _params) do
      image_size = details_data.image_url |> get_image_size()

      changeset
      |> validate_required(@required_fields)
      |> validate_url()
      |> validate_image_fields(image_size)
    end

    def assigns(details_data, socket, _params) do
      cause_options =
        formatted_causes(
          Map.get(details_data, :route_type),
          Map.get(details_data, :combination)
        )

      image_size = details_data.image_url |> get_image_size()
      image_path = details_data.image_url |> get_image_path()

      Phoenix.Component.assign(socket,
        cause_options: cause_options,
        severity_options: @severity_options,
        image_size: image_size,
        image_path: image_path
      )
    end

    defp update_header_text(header_sync_toggle, details_data, autotext_data) do
      if header_sync_toggle == true do
        Templates.build_auto_text(autotext_data, :header_template)
      else
        Map.get(details_data, :header_text)
      end
    end

    defp update_description_text(description_sync_toggle, details_data, autotext_data) do
      if description_sync_toggle == true do
        Templates.build_auto_text(autotext_data, :description_template)
      else
        Map.get(details_data, :description_text)
      end
    end

    defp translated_details(details_data) do
      Map.merge(details_data, %{
        effect_name: effect_from_url_name(details_data.effect_name),
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

    defp effect_from_url_name(url_name) do
      url_name
      |> String.replace("_", " ")
      |> String.split(" ")
      |> Enum.map_join(" ", &String.capitalize(&1))
      |> String.replace("-route", "-Route")
    end

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

    defp validate_url(changeset) do
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

    defp validate_image_fields(changeset, image_size) do
      changeset
      |> Ecto.Changeset.validate_change(:image_url, fn :image_url, image_url ->
        if image_url !== "" and is_number(image_size),
          do: [],
          else: [image_url: "Enter a valid image URL"]
      end)
      |> then(fn changeset ->
        if Map.get(changeset.changes, :image_url) in [nil, ""] do
          changeset
        else
          Ecto.Changeset.validate_required(changeset, :image_alternative_text,
            message: "Enter alt text"
          )
        end
      end)
    end

    defp url_valid?(uri) do
      uri.scheme in ["http", "https"] && !is_nil(uri.host) && uri.host =~ "."
    end

    defp image_from_correct_host?(host), do: host == @cdn_host

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

    @spec maybe_include_virtual_green_line([Route.t()], [String.t()]) :: [Route.t()]
    defp maybe_include_virtual_green_line(routes, route_ids) do
      if "Green" in route_ids do
        [RoutesRepo.green_line() | routes]
      else
        routes
      end
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-w-full flex flex-col mt-4" id="details_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Alert details
      </.h5>
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
            value={@form[:header_text].value}
          />
          <.textarea_footer
            character_limit={255}
            copy_id="#alert_details_header_text"
            copy_title="Copy main message to Clipboard"
            field={@form[:header_text]}
          />
        </div>
        <.checkbox
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
            value={@form[:description_text].value}
          />
          <.textarea_footer
            character_limit={3000}
            copy_id="#alert_details_description_text"
            copy_title="Copy supporting information to Clipboard"
            field={@form[:description_text]}
          />
        </div>
        <.checkbox
          class="mt-2 md:ml-4 md:mt-8"
          field={@form[:description_sync_toggle]}
          label="Auto refresh"
        />
      </div>
      <.text_input
        field={@form[:url]}
        label="URL"
        phx-debounce={120}
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
          :if={@form[:image_url].value not in ["", nil] && is_number(@image_size)}
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
      <hr class="mt-8" />
    </div>
    """
  end
end
