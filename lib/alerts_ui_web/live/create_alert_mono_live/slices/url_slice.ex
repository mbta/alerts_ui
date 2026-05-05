defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.UrlSlice do
  alias AlertsUI.Models.Alert
  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertMonoLive.Slice

  use AlertsUIWeb, :html

  import Ecto.Changeset, only: [cast: 3]

  import AlertsUIWeb.FormComponents.Helpers.ContentFormatter,
    only: [route_atom_to_string: 1]

  import AlertsUIWeb.FormComponents.Helpers.GetKeyForModeEffect,
    only: [get_value_of_key: 3]

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertData,
    only: [humanize_effect_name: 2, list_effect_path_names: 1, get_route_type_int: 1]

  defstruct [
    :alert_id,
    :combination,
    :effect_name,
    :route_type,
    review: false
  ]

  defimpl Slice, for: __MODULE__ do
    def extract(url_data, %Alert{} = alert) do
      # on extract, convert the alert's primary service type into
      # route type, route type int
      alert_id = alert.alert_id
      effect_name = alert.effect
      route_type = Alert.get_route_type(alert)

      slice =
        %{
          url_data
          | alert_id: alert.alert_id,
            effect_name: effect_name,
            route_type: route_type,
            combination: "foo"
        }

      slice
    end

    @url_fields [:combination, :effect_name, :route_type, :route_type_int]

    def transform(_url_data, changeset, params) do
      cast(changeset, get_url_params(params), @url_fields)
    end

    def validate(_url_data, changeset, _params), do: changeset

    def assigns(_url_data, socket, _params), do: socket

    defp get_url_params(params) do
      # These params are read out of the base params object rather than the
      # alert data form. Also we don't look for alert id here because it can't
      # be reassigned.
      route_type_int =
        case Map.get(params, "route_type") do
          nil -> nil
          route_type -> InformedEntity.route_type_mapping(route_type)
        end

      combination = get_value_of_key(
          :combination,
          route_type_int,
          Map.get(params, "effect_name")
        )

      params
      |> Map.take(["route_type", "effect_name"])
      |> Map.put("route_type_int", route_type_int)
      |> Map.put("combination", combination)
    end

    defp route_type
  end

  def route_types do
    [
      :bus,
      :subway,
      :commuter_rail,
      :ferry,
      :facility,
      :systemwide
    ]
  end

  def render(
        %{
          alert_id: alert_id,
          route_type: route_type,
          effect_name: effect_name
        } = assigns
      ) do
    if is_nil(route_type) || is_nil(effect_name) do
      ~H"""
      <div class="min-w-full flex flex-col mb-8" id="route_view">
        <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
          Alert type
        </.h5>
        <div class="w-4 mr-4 w-full text-center md:text-left">
          <.body>Service Type</.body>
        </div>
        <div id="service_type_buttons" class="mb-8">
          <div class="flex flex-wrap justify-center md:justify-normal gap-2">
            <div :for={this_route_type <- route_types()}>
              <.route_type_button this_route_type={this_route_type} selected_route_type={@route_type} />
            </div>
          </div>
        </div>

        <div :if={is_nil(@effect_name)} class="w-4 mr-4 w-full text-center md:text-left">
          <.body>
            Effect
          </.body>
        </div>
        <div id="effect_buttons">
          <p class="text-bg-elevation-6 mb-[18rem]" hidden={!is_nil(@route_type)}>
            Select a service type to see possible effects.
          </p>
          <div class="flex flex-wrap justify-center md:justify-normal gap-2">
            <div
              :for={this_effect_name <- list_effect_path_names(@route_type)}
              class={if is_nil(@route_type), do: "hidden"}
            >
              <.effect_name_button
                this_effect_name={this_effect_name}
                selected_effect_name={@effect_name}
                selected_route_type={@route_type}
              />
            </div>
          </div>
        </div>
      </div>
      """
    else
      ~H"""
      """
    end
  end

  def route_type_button(
        %{
          this_route_type: this_route_type,
          selected_route_type: selected_route_type
        } = assigns
      ) do
    ~H"""
    <.button_toggle
      id={"route-type-#{@this_route_type}-button"}
      active={@this_route_type == @selected_route_type}
      phx-click="push_route_type"
      class="self-center min-w-[16rem]"
      value={@this_route_type}
      icon={@this_route_type}
    >
      {route_atom_to_string(@this_route_type)}
    </.button_toggle>
    """
  end

  def effect_name_button(
        %{
          this_effect_name: this_effect_name,
          selected_effect_name: selected_effect_name,
          selected_route_type: selected_route_type
        } = assigns
      ) do
    ~H"""
    <.button_toggle
      phx-click="push_effect_name"
      class="self-cente min-w-[16rem]"
      value={@this_effect_name}
      active={@this_effect_name == @selected_effect_name}
    >
      {humanize_effect_name(@selected_route_type, @this_effect_name)}
    </.button_toggle>
    """
  end
end
