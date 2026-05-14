defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.UrlSlice do
  require Logger
  alias Ecto.Changeset
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

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.Path,
    only: [path_route_type_from_socket: 1, path_effect_name_from_socket: 1, path_route_type: 2]

  defstruct [
    :alert_id,
    :combination,
    :effect_name,
    :route_type,
    review: false
  ]

  defimpl Slice, for: __MODULE__ do
    import Ecto.Changeset, only: [get_field: 2, cast: 3]
    alias AlertsUI.Models.Alert
    alias AlertsUIWeb.CreateAlertMonoLive.Slices.UrlSlice

    def mount(_url_data, socket, _base_params), do: socket

    def extract(url_data, %Alert{} = alert, params) do
      raise alert.id
      new_url_params(alert, params)
    end

    @url_fields [:alert_id, :combination, :effect_name, :route_type]

    def transform(_url_data, changeset, params) do
      cast(changeset, new_url_params(changeset, params) |> Map.from_struct(), @url_fields)
    end

    def validate(_url_data, changeset, _params), do: changeset

    def assigns(_url_data, socket, params) do
      path_route_type =
        case Map.fetch(params, "route_type") do
          {:ok, value} -> value
          :error -> socket.assigns[:path_route_type]
        end

      path_effect_name =
        case Map.fetch(params, "effect_name") do
          {:ok, value} -> value
          :error -> socket.assigns[:path_effect_name]
        end

      assign(
        socket,
        %{
          path_route_type: path_route_type,
          path_effect_name: path_effect_name
        }
      )
    end

    defp new_url_params(alert_or_changeset, params) do
      {base_route_type_int, base_effect_name} =
        case alert_or_changeset do
          %Changeset{} = changeset ->
            {
              get_field(changeset, :route_type),
              get_field(changeset, :effect_name)
            }

          %Alert{} = alert ->
            {
              Alert.get_route_type(alert),
              alert.effect
            }
        end

      path_route_type = params["route_type"]
      path_effect_name = params["effect_name"]

      path_route_type_int =
        case path_route_type do
          nil -> nil
          route_type -> InformedEntity.route_type_mapping(route_type)
        end

      route_type_int = path_route_type_int || base_route_type_int
      effect_name = path_effect_name || base_effect_name

      combination =
        get_value_of_key(
          :combination,
          route_type_int,
          humanize_effect_name(
            route_type_int,
            effect_name
          )
        )

      %UrlSlice{
        route_type: route_type_int,
        effect_name: effect_name,
        combination: combination
      }
    end
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
          path_route_type: path_route_type,
          path_effect_name: path_effect_name
        } = assigns
      ) do
    if is_nil(path_route_type) || is_nil(path_effect_name) do
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
            <div :for={this_route_type_name <- route_types()}>
              <.route_type_button
                this_route_type={this_route_type_name}
                selected_route_type={@path_route_type}
              />
            </div>
          </div>
        </div>

        <div :if={is_nil(@path_effect_name)} class="w-4 mr-4 w-full text-center md:text-left">
          <.body>
            Effect
          </.body>
          <div id="effect_buttons">
            <p class="text-bg-elevation-6 mb-[18rem]" hidden={!is_nil(@path_route_type)}>
              Select a service type to see possible effects.
            </p>
            <div class="flex flex-wrap justify-center md:justify-normal gap-2">
              <div
                :for={this_effect_name <- list_effect_path_names(@path_route_type)}
                class={if is_nil(@path_route_type), do: "hidden"}
              >
                <.effect_name_button
                  this_effect_name={this_effect_name}
                  selected_effect_name={@path_effect_name}
                  selected_route_type={@path_route_type}
                />
              </div>
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
      active={"#{@this_route_type}" == @selected_route_type}
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
      id={"effect-name-#{@this_effect_name}-button"}
      phx-click="push_effect_name"
      class="self-cente min-w-[16rem]"
      value={@this_effect_name}
      active={"#{@this_effect_name}" == @selected_effect_name}
    >
      {@this_effect_name |> String.replace("_", " ") |> String.capitalize()}
    </.button_toggle>
    """
  end
end
