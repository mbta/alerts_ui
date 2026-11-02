defmodule AlertsUIWeb.CreateAlertLive.Slices.UrlSlice do
  @moduledoc """
  Slice that manages URL-derived parameters: route type, effect name, and their
  combined `combination` key. Renders the route-type and effect-name picker shown
  on the first step of the alert creation form.
  """

  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertLive.AlertData
  alias AlertsUIWeb.CreateAlertLive.Slice
  alias Ecto.Changeset

  use AlertsUIWeb, :html

  import Ecto.Changeset, only: [cast: 3]

  import AlertsUIWeb.Helpers.ContentFormatter,
    only: [route_atom_to_string: 1]

  import AlertsUIWeb.CreateAlertLive.Helpers.GetKeyForModeEffect,
    only: [get_value_of_key: 3]

  import AlertsUIWeb.CreateAlertLive.Helpers.AlertDataHelpers,
    only: [humanize_effect_name: 2, list_effect_path_names: 1]

  defstruct [
    :alert_id,
    :combination,
    :effect_name,
    :route_type,
    review: false
  ]

  defimpl Slice, for: __MODULE__ do
    import Ecto.Changeset, only: [get_field: 2, cast: 3]
    alias AlertsUIWeb.CreateAlertLive
    alias AlertsUIWeb.CreateAlertLive.AlertData
    alias AlertsUIWeb.CreateAlertLive.Slices.UrlSlice

    def mount(_url_data, socket, _base_params), do: socket

    def extract(_url_data, %AlertData{} = alert_data, params) do
      new_url_params(alert_data, params)
    end

    @url_fields [:alert_id, :combination, :effect_name, :route_type]

    def transform(_url_data, changeset, params, _socket) do
      cast(changeset, new_url_params(changeset, params) |> Map.from_struct(), @url_fields)
    end

    def validate(_url_data, changeset, _params, _socket), do: changeset

    def assigns(_, %{assigns: %{halt_flushing: true}} = socket, _) do
      assign(socket, :halt_flushing, false)
    end

    def assigns(_url_data, socket, params) do
      alert_id = get_alert_id(socket, params)
      path_route_type = get_path_route_type(socket, params)

      path_effect_name = get_path_effect_name(socket, params)

      socket =
        if alert_id == nil && (path_route_type == nil || path_effect_name == nil) do
          socket
          |> assign(:halt_flushing, true)
          |> CreateAlertLive.start_socket(params)
        else
          socket
        end
        |> scroll_down_on_mobile(params)

      assign(
        socket,
        %{
          alert_id: alert_id,
          path_route_type: path_route_type,
          path_effect_name: path_effect_name,
          change_type: socket.assigns.change_type
        }
      )
    end

    defp scroll_down_on_mobile(socket, %{"route_type" => _}) do
      Phoenix.LiveView.push_event(socket, "scrollToItemOnMobile", %{item_id: "effect_buttons"})
    end

    defp scroll_down_on_mobile(socket, _), do: socket

    defp get_alert_id(socket, params) do
      case Map.fetch(params, "alert_id") do
        {:ok, value} -> value
        :error -> socket.assigns[:alert_id]
      end
    end

    defp get_path_route_type(socket, params) do
      case Map.fetch(params, "route_type") do
        {:ok, value} -> value
        :error -> socket.assigns[:path_route_type]
      end
    end

    defp get_path_effect_name(socket, params) do
      case Map.fetch(params, "effect_name") do
        {:ok, value} -> value
        :error -> socket.assigns[:path_effect_name]
      end
    end

    defp new_url_params(alert_or_changeset, params) do
      {alert_id, base_route_type_int, base_effect_name} =
        case alert_or_changeset do
          %Changeset{} = changeset ->
            {
              get_field(changeset, :alert_id),
              get_field(changeset, :route_type),
              get_field(changeset, :effect_name)
            }

          %AlertData{} = alert_data ->
            {
              alert_data.alert_id,
              alert_data.route_type,
              alert_data.effect_name
            }
        end

      path_route_type = params["route_type"]
      path_effect_name = params["effect_name"]

      path_route_type_int = path_type_int(path_route_type)

      route_type_int = path_route_type_int || base_route_type_int
      effect_name = path_effect_name || base_effect_name

      # nil route_type is valid for facility/systemwide; use path_route_type atom for effect lookups
      effective_route_type =
        case {route_type_int, path_route_type} do
          {nil, pt} when not is_nil(pt) -> String.to_existing_atom(pt)
          _ -> route_type_int
        end

      combination =
        combination(effective_route_type, path_route_type, effect_name, alert_or_changeset)

      %UrlSlice{
        alert_id: alert_id,
        route_type: route_type_int,
        effect_name: effect_name,
        combination: combination
      }
    end

    defp combination(nil, nil, effect_name, alert_or_changeset) do
      # During form field changes or direct edit for facility/systemwide alerts,
      # path_route_type is absent. Preserve the existing combination rather than
      # resetting to nil, since route_type is intentionally nil for these alert types.
      case alert_or_changeset do
        %Changeset{} = cs ->
          get_field(cs, :combination) ||
            get_value_of_key(
              :combination,
              nil,
              humanize_effect_name(nil, effect_name)
            )

        %AlertData{} = ad ->
          ad.combination ||
            get_value_of_key(
              :combination,
              nil,
              humanize_effect_name(nil, effect_name)
            )
      end
    end

    defp combination(effective_route_type, _path_route_type, effect_name, _alert_or_changeset) do
      get_value_of_key(
        :combination,
        effective_route_type,
        humanize_effect_name(
          effective_route_type,
          effect_name
        )
      )
    end

    defp path_type_int(nil), do: nil

    defp path_type_int(route_type) do
      InformedEntity.route_type_mapping(route_type)
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
          path_route_type: path_route_type,
          path_effect_name: path_effect_name,
          change_type: change_type
        } = assigns
      ) do
    if is_nil(path_route_type) || is_nil(path_effect_name) || change_type do
      ~H"""
      <div class="min-w-full flex flex-col mb-8" id="route_view" phx-hook="AutoScroll">
        <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
          Alert type
        </.h5>
        <div class="form-control gap-4 min-w-full">
          <div class="w-4 mr-4 w-full text-center md:text-left">
            Service Type
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

          <div
            :if={is_nil(@path_effect_name) || @change_type}
            class="w-4 mr-4 w-full text-center md:text-left gap-4 flex flex-col"
          >
            Effect
            <div id="effect_buttons">
              <p class="text-text-secondary mb-[18rem]" hidden={!is_nil(@path_route_type)}>
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
      </div>
      """
    else
      ~H"""
      """
    end
  end

  def route_type_button(assigns) do
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

  def effect_name_button(assigns) do
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
