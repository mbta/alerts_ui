defmodule AlertsUIWeb.FormComponents.Submit do
  @moduledoc """
    Live Component for submission section of form.
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema

  import AlertsUIWeb.ReviewModal

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/alerts")}
  end

  @impl true
  def handle_event("save", _params, socket) do
    send(self(), :create_alert)
    {:noreply, socket}
  end

  @impl true
  def handle_event("review", _params, socket) do
    # Validating the form is handled in `create_alert_live`
    send(self(), :show_errors)
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_review", _params, socket) do
    # Need to pass `show:false` to unmount the modal
    {:noreply, socket |> assign(show: false)}
  end

  @impl true
  def handle_event("image-size", %{"id" => "size-of-image", "image_size" => image_size}, socket) do
    {:noreply,
     assign(socket, alert_data: Map.put(socket.assigns.alert_data, :image_size, image_size))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-w-full flex mt-4 mb-12 border-t border-border-primary" id="submit_view">
      <.review_modal
        :if={Map.get(assigns, :show, nil)}
        editing={@editing}
        alert_data={Map.merge(@alert_data, %{selected_schedules: @selected_schedules})}
        cancel_event_name="cancel_review"
        accept_event_name="save"
        target_id="#submit_view"
      />
      <.button_secondary
        class="mt-8 mr-auto self-center border-none py-2 px-3"
        name="back"
        phx-click="move_progress"
        value="route_type_and_effect"
        type="button"
        id="back"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" /> Back
      </.button_secondary>
      <.button_secondary
        class="mt-8 self-center border-none"
        phx-target={@myself}
        name="cancel"
        phx-click="cancel"
        type="button"
        id="cancel"
      >
        Cancel
      </.button_secondary>
      <.button_primary
        class="mt-8 ml-2 self-center"
        phx-target={@myself}
        name="review"
        phx-click="review"
        type="button"
        id="review"
      >
        Review and submit
      </.button_primary>
    </div>
    """
  end
end
