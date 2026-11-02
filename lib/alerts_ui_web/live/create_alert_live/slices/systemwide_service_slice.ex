defmodule AlertsUIWeb.CreateAlertLive.Slices.SystemwideServiceSlice do
  @moduledoc """
  Slice that handles affected-service selection for systemwide alerts. Validates
  that at least one service type (bus, commuter rail, ferry, subway) is chosen
  and renders the corresponding checkgroup.
  """

  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertLive.AlertData
  alias AlertsUIWeb.CreateAlertLive.Slice

  import AlertsUIWeb.CreateAlertLive.Helpers.Validation,
    only: [always_validate_required: 3]

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
    def mount(_service_data, socket, _base_params), do: socket

    def extract(service_data, %AlertData{} = _alert_data, _params) do
      service_data
    end

    def transform(_service_data, changeset, _params, _socket) do
      changeset
    end

    def validate(_service_data, changeset, _params, socket) do
      if socket.assigns.submitted? do
        always_validate_required(changeset, :service_types, "Select a service type")
      else
        changeset
      end
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
end
