defmodule AlertsUIWeb.TripEndWarningModal do
  @moduledoc """
  Component and helper functions for warning about a trip ending before the
  selected start time
  """

  use Phoenix.Component

  import AlertsUIWeb.SharedComponents
  import AlertsUIWeb.IconComponents

  alias AlertsUIWeb.Formatting
  # alias AlertsUIWeb.FormComponents.Helpers.GetKeyForModeEffect

  @doc """
  Renders the warning modal

  ## Examples
    <.trip_end_warning_modal
      cancel_event_name="dismiss_trip_end_warning"
      accept_event_name="review"
      target_id="#submit_view"
    />
  """
  attr :id, :string,
    default: "trip_end_warning_modal",
    doc: "the optional id of flash container"

  attr :rest, :global, include: ~w(cancel_event_name accept_event_name target_id)

  def trip_end_warning_modal(assigns) do
    ~H"""
    <.modal
      id={@id}
      show={true}
      cancel_button_text="No, keep editing"
      accept_button_text="Yes, continue"
      class="flex flex-col h-full justify-center w-[600px]"
      outer_class="!h-full"
      inner_class="shrink grow overflow-auto"
      {@rest}
    >
      <:header>
        <.warning_icon class="inline text-warning" stroke="#2b3741" fill="currentColor" />
        Warning: Alert starts after end of trip(s)
      </:header>
      The effect period starts after the selected trip(s) end. Do you still want to continue?
    </.modal>
    """
  end

  def show_warning?(
        %NaiveDateTime{} = trip_arrival_time,
        %NaiveDateTime{} = active_period_start,
        modal_date
      )
      when is_binary(modal_date) do
    NaiveDateTime.compare(trip_arrival_time, active_period_start) == :lt
  end

  def show_warning?(_, _, _) do
    false
  end
end
