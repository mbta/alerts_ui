defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.DeliverySlice do
  alias AlertsUI.Models.Alert
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias Phoenix.HTML.Form

  use AlertsUIWeb, :html

  defstruct [
    :accept_banner,
    :banner_sync_toggle,
    :banner_text,
    :notification_toggle,
    :view_banner
  ]

  defimpl Slice, for: __MODULE__ do
    def extract(delivery_data, %Alert{} = alert, params) do
      struct(delivery_data, Map.from_struct(alert))
    end

    def transform(_delivery_data, changeset, _params) do
      changeset
    end

    def validate(_delivery_data, changeset, _params) do
      changeset
    end

    def assigns(_delivery_data, socket, _params) do
      socket
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-w-full flex flex-col mt-8" id="delivery_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Delivery
      </.h5>
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
        <div :if={@form[:view_banner].value} class="flex flex-col md:flex-row">
          <div class="flex flex-col md:w-[50%]" id="banner-container">
            <.textarea
              field={@form[:banner_text]}
              label="Website banner text"
              class="w-[100%] min-h-[10rem] border-b-0"
              maxlength="4000"
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
          <.checkbox field={@form[:accept_banner]} />
          <span class={if @form[:accept_banner].errors |> length > 0, do: "-ml-[14rem]", else: "ml-4"}>
            I understand this will post a high priority alert banner on every page of MBTA.com.
          </span>
        </div>
      </div>
      <hr class="mt-8" />
    </div>
    """
  end
end
