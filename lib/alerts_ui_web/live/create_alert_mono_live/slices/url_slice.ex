defmodule AlertsUIWeb.CreateAlertMonoLive.AlertData.UrlSlice do
  alias AlertsUI.Models.Alert
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData.Slice

  use AlertsUIWeb, :html

  import AlertsUIWeb.FormComponents.Helpers.EffectsForRouteTypes, only: [list_effects: 1]
  import AlertsUIWeb.FormComponents.Helpers.ContentFormatter, only: [route_atom_to_string: 1]

  defstruct [
    :alert_id,
    :effect_name,
    :form_type,
    :route_type,
    review: false
  ]

  defimpl Slice, for: __MODULE__ do
    @doc """
    """
    def extract(url_data, %Alert{} = alert) do
      alert_id = alert.alert_id
      effect_name = alert.effect
      route_type = Alert.get_route_type(alert)

      %{
        url_data |
        alert_id: alert_id,
        effect_name: effect_name,
        route_type: route_type
      }
    end

    def transform(_url_data, changeset), do: changeset
    def validate(_url_data, changeset), do: changeset

    @route_types [
      :bus,
      :subway,
      :commuter_rail,
      :ferry,
      :facility,
      :systemwide
    ]

    def render(_slice, assigns) do
      if assigns.form_state in [:select_route_type, :select_effect_name] do
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
              <div :for={route_type <- @route_types}>
                {route_type_buttons(assigns, route_type)}
              </div>
            </div>
          </div>

          <div :if={@form_state == :select_effect_name} class="w-4 mr-4 w-full text-center md:text-left">
            <.body>
              Effect
            </.body>
          </div>
          <div id="effect_buttons">
            <p class="text-bg-elevation-6 mb-[18rem]" hidden={!is_nil(@selected_route_type)}>
              Select a service type to see possible effects.
            </p>
            <div class="flex flex-wrap justify-center md:justify-normal gap-2">
              <div
                :for={effect <- list_effects(@selected_route_type)}
                class={if is_nil(@selected_route_type), do: "hidden"}
              >
                {effect_buttons(assigns, effect)}
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

    def route_type_buttons(assigns, route_type) do
      active_route = route_type == (assigns.selected_route_type || "") |> String.to_existing_atom()

      assigns = assign(assigns, %{route_type: route_type, active_route: active_route})

      ~H"""
      <.button_toggle
        id={"route-type-#{@route_type}-button"}
        active={@active_route}
        phx-click="route_type"
        class="self-center min-w-[16rem]"
        value={@route_type}
        icon={@route_type}
      >
        {route_atom_to_string(@route_type)}
      </.button_toggle>
      """
    end

    def effect_buttons(assigns, effect) do
      active_effect = effect == assigns.selected_effect

      assigns =
        assign(assigns, %{
          effect: effect,
          active_effect: active_effect
        })

      ~H"""
      <.button_toggle
        phx-click="effect"
        class="self-cente min-w-[16rem]"
        value={@effect}
        active={@active_effect}
      >
        {@effect |> String.replace("_", " ") |> String.capitalize()}
      </.button_toggle>
      """
    end
  end
end
