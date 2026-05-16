defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.SubmitSlice do
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.PredictionSuppressionWarningModal
  alias AlertsUIWeb.ReviewModal
  use AlertsUIWeb, :html

  defstruct [
    header_text: ""
  ]

  defimpl Slice, for: __MODULE__ do
    def mount(_slice_data, socket, _base_params), do: socket

    def extract(submit_data, _alert_data, _params) do
      submit_data
      |> struct()
    end

    def transform(_data, changeset, _params, _socket) do
      changeset
    end

    def validate(_data, changeset, _params, _socket) do
      changeset
    end

    def assigns(_slice_data, socket, params) do
      reviewing = Map.get(params, "review", false)

      assign(socket,
        back: socket.assigns.form_type == :creating,
        show: reviewing in ["true", true]
      )
    end
  end

  def render(assigns) do
    assigns = assign(assigns, :alert_data, Map.merge(assigns.form.source.data, assigns.form.source.changes))

    # form changeset source has instance of alert data for review modal
    # default selected schedules?
    ~H"""
    <div class="min-w-full flex mt-4 mb-12 border-t border-border-primary" id="submit_view">
      <PredictionSuppressionWarningModal.prediction_suppression_warning_modal
        :if={Map.get(assigns, :check_predictions, nil)}
        id="check_predictions_modal"
        alert_data={@alert_data}
        cancel_event_name="dismiss_prediction_warning"
        accept_event_name="review"
        target_id="#submit_view"
        selected_routes={@selections.selected_routes}
      />
      <ReviewModal.review_modal
        :if={Map.get(assigns, :show, false)}
        form_type={@form_type}
        alert_data={
          @alert_data
          |> Map.merge(%{selected_schedules: []})
          |> Map.merge(AlertsUI.AlertBuilder.original_selections(@alert_data))
        }
        cancel_event_name="cancel_review"
        accept_event_name="save"
        target_id="#submit_view"
        alert_id={@alert_data.alert_id}
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
        :if={@progress.name == "details"}
        class="mt-8 self-center border-none"
        name="cancel"
        phx-click="cancel"
        type="button"
        id="cancel"
      >
        Cancel
      </.button_secondary>
      <.button_primary
        :if={@progress.name == "details"}
        class="mt-8 ml-2 self-center"
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
