defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.SystemwideServiceSlice do
  alias AlertsUI.Models.Alert
  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertMonoLive.Slice

  use AlertsUIWeb, :html

  defstruct [
    :direction,
    :facility_ids,
    :original_direction_selections,
    :original_facility_selections,
    :original_route_selections,
    :original_stop_selections,
    :original_trip_selections,
    :route_ids,
    :service_types
  ]

  defimpl Slice, for: __MODULE__ do
    def extract(service_data, %Alert{} = alert) do
      struct(service_data, Map.from_struct(alert))
    end

    def transform(_service_data, changeset, _params) do
      changeset
    end

    def validate(_service_data, changeset, _params) do
      changeset
    end

    def assigns(_service_data, socket, _params) do
      socket
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-w-full flex flex-col" id="systemwide_service_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Affected service
      </.h5>
      <fieldset class="mb-8 min-h-36 max-w-[15%]">
        <.toggle_checkgroup
          label="Service types impacted"
          field={@form[:service_types]}
          options={service_type_options()}
          show_icons={true}
          class="flex-col"
          button_class="min-w-full"
        />
      </fieldset>
      <hr />
    </div>
    """
  end

  defp service_type_options do
    Enum.map([:bus, :commuter_rail, :ferry, :subway], fn name ->
      [
        key: name,
        value: InformedEntity.route_type_mapping(name) |> Integer.to_string(),
        id: "service-type-#{name}"
      ]
    end)
  end

  defp integer_service_types(%{"service_types" => service_types} = systemwide_affected_service)
       when is_list(service_types) do
    service_types =
      service_types
      |> Enum.map(&integer_service_type/1)
      |> Enum.reject(&is_nil/1)

    %{systemwide_affected_service | "service_types" => service_types}
  end

  defp integer_service_type("1"), do: 1
  defp integer_service_type("2"), do: 2
  defp integer_service_type("3"), do: 3
  defp integer_service_type("4"), do: 4
  defp integer_service_type(service_type_int) when service_type_int in 0..4, do: service_type_int

  defp integer_service_type(unknown_service_type) do
    Logger.error("Unknown service type: #{inspect(unknown_service_type)}")
    nil
  end
end
