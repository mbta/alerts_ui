defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.DeliverySlice do
  alias AlertsUIWeb.CreateAlertMonoLive.Helpers.Path
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.FormComponents.Helpers.GetKeyForModeEffect
  alias Phoenix.HTML.Form

  use AlertsUIWeb, :html

  defstruct [
    :effect_name,
    :route_type,
    :header_text,
    :accept_banner,
    :banner_sync_toggle,
    :banner_text,
    :notification_toggle,
    :view_banner
  ]

  defimpl Slice, for: __MODULE__ do
    import Ecto.Changeset

    def mount(_delivery_data, socket, _base_params), do: socket

    def extract(delivery_data, %AlertData{} = _alert_data, _params) do
      struct(delivery_data)
    end

    def transform(delivery_data, changeset, params, socket) do
      effect_name = Path.effect_from_url_name(delivery_data.effect_name || "")

      notification_toggle =
        get_notification_toggle_default(delivery_data, effect_name, socket.assigns.form_type)

      [_, target | _] = Map.get(params, "_target", [nil, nil])

      banner_sync_toggle =
        if target == "banner_text" and delivery_data.banner_sync_toggle == true do
          false
        else
          delivery_data.banner_sync_toggle
        end

      # todo check this, intended for edit
      view_banner =
        if delivery_data.banner_text not in [nil, ""] do
          true
        else
          delivery_data.view_banner
        end

      banner_text =
        if banner_sync_toggle and view_banner do
          delivery_data.header_text
        else
          delivery_data.banner_text || ""
        end

      change(changeset, %{
        view_banner: view_banner,
        banner_sync_toggle: banner_sync_toggle,
        banner_text: banner_text,
        notification_toggle: notification_toggle,
        accept_banner: delivery_data.accept_banner
      })
    end

    def validate(delivery_data, changeset, _params, _socket) do
      if delivery_data.view_banner do
        changeset
        |> validate_acceptance(:accept_banner,
          message: "Check box to show you understand"
        )
      else
        changeset
      end
    end

    def assigns(_delivery_data, socket, _params) do
      socket
    end

    defp get_notification_toggle_default(
           %{notification_toggle: nil, route_type: route_type},
           effect_name,
           :creating
         ) do
      GetKeyForModeEffect.get_value_of_key(
        :send_push_notification_on_create,
        route_type,
        effect_name
      )
    end

    defp get_notification_toggle_default(
           %{notification_toggle: nil, route_type: route_type},
           effect_name,
           :editing
         ) do
      GetKeyForModeEffect.get_value_of_key(
        :send_push_notification_on_edit,
        route_type,
        effect_name
      )
    end

    defp get_notification_toggle_default(%{notification_toggle: notification_toggle}, _, _) do
      notification_toggle
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-w-full flex flex-col mt-8" id="delivery_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Delivery
      </.h5>
      <div class="flex flex-col gap-4">
        <div class="flex flex-row">
          <.checkbox field={@form[:notification_toggle]} id="notification-toggle" />

          <span class="ml-4">
            Send notification to alert subscribers
          </span>
        </div>
        <div id="banner_div" class="flex flex-col">
          <div class="flex flex-row mb-2">
            <.checkbox field={@form[:view_banner]} />
            <span class="ml-4">Banner on all MBTA.com pages</span>
          </div>
          <div
            :if={Form.normalize_value("checkbox", @form[:view_banner].value)}
            class="flex flex-col md:flex-row"
          >
            <div class="flex flex-col md:w-[50%]" id="banner-container">
              <.textarea
                field={@form[:banner_text]}
                label="Website banner text"
                phx-debounce={120}
                maxlength="255"
                id="header_input"
                class={
                  [
                    "w-[100%] min-h-[10rem] z-20 mt-3",
                    if(String.length(@form[:header_text].value || "") >= 4000,
                      do: "!border-error border-b-1",
                      else: "border-b-0"
                    )
                  ]
                  |> Enum.join(" ")
                }
                value={@form[:banner_text].value}
              />
              <.textarea_footer
                character_limit={4000}
                copy_id="#delivery_banner_text"
                copy_title="Copy banner text to Clipboard"
                field={@form[:banner_text]}
              />
            </div>
            <.checkbox
              class="mt-2 md:ml-4 md:mt-8"
              field={@form[:banner_sync_toggle]}
              label="Auto refresh"
            />
          </div>
          <div
            :if={Form.normalize_value("checkbox", @form[:view_banner].value)}
            class="flex flex-row mt-4"
          >
            <.checkbox
              field={@form[:accept_banner]}
              label="I understand this will post a high priority alert banner on every page of MBTA.com."
            />
          </div>
        </div>
      </div>
      <hr class="mt-8" />
    </div>
    """
  end
end
