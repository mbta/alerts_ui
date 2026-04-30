defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.AlertDetailsSlice do
  alias AlertsUI.Models.Alert
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUI.Models.{Cause, EnhancedSchedule, SeverityLevel}
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias Ecto.Changeset
  use AlertsUIWeb, :html

  defstruct [
    :combination,
    :route_type,
    :direction,
    :facility_ids,
    :original_direction_selections,
    :original_facility_selections,
    :original_route_selections,
    :original_stop_selections,
    :original_trip_selections,
    :route_ids,
    :service_types,
    :description_text,
    :service_effect_text,
    :image_alternative_text,
    header_text: "",
    header_sync_toggle: true,
    description_sync_toggle: true,
    cause_detail: "",
    severity: 4,
    image_size: %{},
    image_url: "",
    url: ""
  ]

  @cdn_host "cdn.mbta.com"

  defimpl Slice, for: __MODULE__ do
    import Ecto.Changeset

    @severity_options SeverityLevel.severity_tuples()
                      |> Enum.map(fn {desc, severity, _level} -> {desc, severity} end)

    @required_fields ~w[header_text]a

    def extract(details_data, %Alert{} = alert) do
      struct(details_data)
      # struct(service_data, Map.from_struct(alert))
    end

    def transform(details_data, changeset, params) do
      # IO.inspect(params, label: :transform_params)
      # IO.inspect(details_data, label: :details_data)
      # IO.inspect(params, labeL: :transform)
      image_size = details_data.image_url |> get_image_size()
      image_path = details_data.image_url |> get_image_path()
      changeset
      # |> IO.inspect
      # |> cast(Map.from_struct(details_data), @fields)
    end

    def validate(details_data, changeset, _params) do
      IO.inspect("VALIDATE")
      changeset
      |> validate_required(@required_fields)
      |> validate_url()
      |> validate_image_fields(details_data.image_size)
    end

    def assigns(details_data, socket, _params) do
      IO.inspect("ASSIGN")

      cause_options =
        formatted_causes(
          Map.get(details_data, :route_type),
          Map.get(details_data, :combination)
        )

      Phoenix.Component.assign(socket,
        severity_options: @severity_options,
        cause_options: cause_options
      )
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
