defmodule AlertsUIWeb.ReviewModal do
  @moduledoc """
  Component for the review modal with alert details and delivery preview
  """
  use Phoenix.Component

  import AlertsUIWeb.SharedComponents

  @doc """
  Renders the review modal. The fields passed as props are determined by its 
  parent com

  ## Examples
    <.review_modal
      cancel_event_name="cancel_review"
      accept_event_name="save"
      target_id="#submit_view"
    />
  """
  attr :rest, :global, include: ~w(cancel_event_name accept_event_name target_id)

  def review_modal(assigns) do
    ~H"""
    <.modal
      id="review-modal"
      show={true}
      class="w-[800px]"
      header_text="Create new alert"
      cancel_button_text="Keep editing"
      accept_button_text="Submit"
      {@rest}
    >
      <div>Hello world</div>
    </.modal>
    """
  end
end
