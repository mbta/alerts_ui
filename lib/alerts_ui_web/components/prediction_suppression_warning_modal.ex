defmodule AlertsUIWeb.PredictionSuppressionWarningModal do
  @moduledoc """
  Component and helper functions for warning about unintentional
  prediction suppression
  """

  use Phoenix.Component
  use AlertsUIWeb, :verified_routes

  import AlertsUIWeb.SharedComponents
  import AlertsUIWeb.IconComponents

  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertLive.Helpers.GetKeyForModeEffect
  alias AlertsUIWeb.Formatting

  @doc """
  Renders the warning modal

  ## Examples
    <.prediction_suppression_warning_modal
      cancel_event_name="dismiss_prediction_warning"
      accept_event_name="review"
      target_id="#submit_view"
    />
  """
  attr :id, :string,
    default: "prediction_suppression_warning_modal",
    doc: "the optional id of flash container"

  attr :alert_data, :map, default: %{}, doc: "The user selections that make up alert_data"

  attr :rest, :global, include: ~w(cancel_event_name accept_event_name target_id)

  attr :selected_routes, :list, default: []

  def prediction_suppression_warning_modal(assigns) do
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
        Warning: Predictions will be suppressed
      </:header>
      {warning_message(@alert_data, @selected_routes)}
    </.modal>
    """
  end

  @doc """
  Returns whether the modal should be displayed or not
  """
  def show_warning?(%{} = alert_data) do
    route_selected?(alert_data) && predictable_alert?(alert_data) &&
      missing_information?(alert_data)
  end

  defp route_selected?(alert_data) do
    alert_data
    |> Map.get(:route_ids)
    # Can't default as this is explicitly nil sometimes
    |> Kernel.||([])
    |> Enum.any?()
  end

  def predictable_alert?(%{route_type: route_type, effect_name: effect_name}) do
    mode_name = InformedEntity.route_code_mapping(route_type)
    GetKeyForModeEffect.get_value_of_key(:prediction_suppression_warning, mode_name, effect_name)
  end

  defp missing_information?(%{combination: :RDTS} = alert_data) do
    trip_ids = Map.get(alert_data, :trip_ids, [])
    stop_ids = Map.get(alert_data, :stop_ids, [])
    trip_ids == [] || stop_ids == []
  end

  defp missing_information?(%{combination: :RDT} = alert_data) do
    Map.get(alert_data, :trip_ids, [])
    |> Enum.empty?()
  end

  defp missing_information?(%{combination: :RDS} = alert_data) do
    Map.get(alert_data, :stop_ids, [])
    |> Enum.empty?()
  end

  defp missing_information?(_), do: false

  @doc """
  Builds the message that is displayed to illustrate the problem
  """
  def warning_message(%{} = alert_data, selected_routes) do
    {selection_problem, suppression_target} = descriptions(alert_data)
    affected_route = route_name(selected_routes)

    "There are no #{selection_problem} selected. This will suppress predictions #{suppression_target} on the #{affected_route}. Do you still want to continue?"
  end

  @doc """
  Generate the dynamic part of the warning message
  """
  def descriptions(%{combination: combination} = alert_data) do
    trip_count = length(Map.get(alert_data, :trip_ids, []))
    stop_count = length(Map.get(alert_data, :stop_ids, []))

    combination_description(combination, trip_count, stop_count)
  end

  def descriptions(_), do: {"", ""}

  defp combination_description(combination, trip_count, stop_count)

  defp combination_description(:RDTS, 0, 0), do: {"trips or stops", "for all trips and stops"}

  defp combination_description(:RDTS, 0, 1), do: {"trips", "at this stop for all trips"}

  defp combination_description(:RDTS, 0, stop_count) when stop_count > 1,
    do: {"trips", "at these stops for all trips"}

  defp combination_description(:RDTS, 1, 0), do: {"stops", "for this trip at all stops"}

  defp combination_description(:RDTS, trip_count, 0) when trip_count > 1,
    do: {"stops", "for these trips at all stops"}

  defp combination_description(:RDT, 0, _), do: {"trips", "for all trips"}

  defp combination_description(:RDS, _, 0), do: {"stops", "at all stops"}

  defp combination_description(_, _, _), do: {"", ""}

  @doc """
  Obtain the name of the route in question
  """
  def route_name(selected_routes) when is_list(selected_routes) do
    selected_routes
    |> Enum.sort_by(& &1.sort_order)
    |> Enum.map(& &1.name)
    |> Formatting.word_list()
  end

  def route_name(_) do
    ""
  end
end
