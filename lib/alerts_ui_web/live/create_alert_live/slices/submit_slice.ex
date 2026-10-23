defmodule AlertsUIWeb.CreateAlertLive.Slices.SubmitSlice do
  @moduledoc """
  Slice that renders the bottom action bar with Select Alert Type, Cancel, and Review/Submit
  buttons, and conditionally shows the review modal and prediction-suppression
  warning modal before saving an alert.
  """

  alias AlertsUIWeb.CreateAlertLive.Helpers.Path, as: PathHelper
  alias AlertsUIWeb.CreateAlertLive.Slice
  alias AlertsUIWeb.PredictionSuppressionWarningModal
  alias AlertsUIWeb.ReviewModal
  alias AlertsUIWeb.TripEndWarningModal
  use AlertsUIWeb, :html

  defstruct [
    :created_timestamp,
    :created_by,
    :last_edited_at,
    :last_edited_by,
    :last_push_notification_timestamp
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

      assign(socket, show: reviewing in ["true", true])
    end
  end

  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    alert_data = Map.merge(assigns.form.source.data, assigns.form.source.changes)

    selected_routes =
      case assigns.selections do
        nil ->
          []

        selections ->
          Enum.filter(
            Map.get(selections, :available_routes, []) || [],
            &(&1.id in (alert_data.route_ids || []))
          )
      end

    loading = Map.get(assigns.selections, :loading, false) or assigns.persisting_alert

    assigns =
      assign(
        assigns,
        %{alert_data: alert_data, selected_routes: selected_routes, loading: loading}
      )

    ~H"""
    <div class="min-w-full flex mt-4 mb-12 border-t border-border-primary" id="submit_view">
      <PredictionSuppressionWarningModal.prediction_suppression_warning_modal
        :if={@check_predictions}
        id="check_predictions_modal"
        alert_data={@alert_data}
        cancel_event_name="dismiss_prediction_warning"
        accept_event_name="check_for_trip_warnings"
        target_id="#submit_view"
        selected_routes={@selected_routes}
      />
      <TripEndWarningModal.trip_end_warning_modal
        :if={@check_trip_end}
        cancel_event_name="dismiss_trip_end_warning"
        accept_event_name="open_review_modal"
        target_id="#submit_view"
      />
      <ReviewModal.review_modal
        :if={Map.get(assigns, :show, false)}
        form_type={@form_type}
        alert_data={
          @alert_data
          |> Map.merge(%{selected_schedules: []})
          |> Map.merge(%{image_preview_size: @image_preview_size})
          |> Map.merge(
            AlertsUI.AlertBuilder.original_selections(
              @alert_data
              |> Map.merge(%{
                effect_name: PathHelper.effect_from_url_name(@alert_data.effect_name)
              }),
              @alert_data.combination
            )
          )
        }
        cancel_event_name="cancel_review"
        accept_event_name="save"
        target_id="#submit_view"
        alert_id={@alert_data.alert_id}
        current_user={@current_user}
      />
      <.button_secondary
        class="mt-8 self-center border-none py-2 px-3"
        name="select-alert-type"
        phx-click="move_progress"
        value="route_type_and_effect"
        type="button"
        id="select-alert-type"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3 mr-2" /> Select Alert Type
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
        class="mt-8 ml-2 self-center min-w-[10.5rem] justify-center"
        name="review"
        phx-click="review"
        type="button"
        id="review"
        disabled={@loading}
      >
        <.loading loading={@loading}>
          Review and submit
        </.loading>
      </.button_primary>
    </div>
    """
  end
end
