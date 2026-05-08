defmodule AlertsUIWeb.FormComponents.Submit do
  @moduledoc """
    Live Component for submission section of form.
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema

  alias AlertsUIWeb.PredictionSuppressionWarningModal
  alias AlertsUIWeb.ReviewModal

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply,
     push_navigate(socket,
       to: AlertsUIWeb.CreateAlertLive.return_to(socket.assigns[:return_to] || "/alerts")
     )}
  end

  @impl true
  def handle_event("save", _params, socket) do
    send(self(), :create_alert)
    {:noreply, socket}
  end

  @impl true
  def handle_event("check_predictions", params, socket) do
    %{assigns: %{alert_data: alert_data}} = socket

    if PredictionSuppressionWarningModal.show_warning?(alert_data) do
      {:noreply, socket |> assign(check_predictions: true)}
    else
      handle_event("review", params, socket)
    end
  end

  @impl true
  def handle_event("dismiss_prediction_warning", _params, socket) do
    {:noreply, socket |> assign(check_predictions: false)}
  end

  @impl true
  def handle_event("review", _params, socket) do
    # Validating the form is handled in `create_alert_live`
    send(self(), :show_errors)
    {:noreply, socket |> assign(check_predictions: false)}
  end

  @impl true
  def handle_event("cancel_review", _params, socket) do
    # Need to pass `show:false` to unmount the modal
    {:noreply, socket |> assign(show: false)}
  end

  @impl true
  def handle_event(
        "image-preview-size",
        %{"id" => "size-of-image", "image_preview_size" => image_preview_size},
        socket
      ) do
    {:noreply,
     assign(socket,
       alert_data: Map.put(socket.assigns.alert_data, :image_preview_size, image_preview_size)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-w-full flex mt-4 mb-12 border-t border-border-primary" id="submit_view">
      <PredictionSuppressionWarningModal.prediction_suppression_warning_modal
        :if={Map.get(assigns, :check_predictions, nil)}
        id="check_predictions_modal"
        alert_data={@alert_data}
        cancel_event_name="dismiss_prediction_warning"
        accept_event_name="review"
        target_id="#submit_view"
        selected_routes={@selected_routes}
      />
      <ReviewModal.review_modal
        :if={Map.get(assigns, :show, nil)}
        form_type={@form_type}
        alert_data={
          @alert_data
          |> Map.merge(%{selected_schedules: @selected_schedules})
          |> Map.merge(AlertsUI.AlertBuilder.original_selections(@alert_data, @combination))
        }
        cancel_event_name="cancel_review"
        accept_event_name="save"
        target_id="#submit_view"
        alert_id={@alert_id}
        current_user={@current_user}
      />
      <.button_secondary
        :if={Map.get(assigns, :back, true)}
        class="mt-8 self-center border-none py-2 px-3"
        name="back"
        phx-click="move_progress"
        value="route_type_and_effect"
        type="button"
        id="back"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3 mr-2" /> Back
      </.button_secondary>
      <div class="flex flex-1">&nbsp;</div>
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
        phx-click="check_predictions"
        type="button"
        id="review"
      >
        Review and submit
      </.button_primary>
    </div>
    """
  end
end
