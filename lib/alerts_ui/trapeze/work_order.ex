defmodule AlertsUI.Trapeze.WorkOrder do
  @moduledoc """
  One escalator/elevator work order
  """

  alias AlertsUI.AlertBuilder
  alias AlertsUI.Trapeze.WorkOrder
  alias AlertsUIWeb.FormComponents.Helpers.AutoText.AlertDataToAutoText
  alias AlertsUIWeb.FormComponents.Helpers.AutoText.Templates
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  defstruct [
    :file_process_datetime,
    :equipment_id,
    :facility_id,
    :effect,
    :asset_id,
    :description,
    :lines,
    :work_order_id,
    :create_datetime,
    :update_datetime,
    :start_datetime,
    :end_datetime,
    :status
  ]

  @type t :: %__MODULE__{
          file_process_datetime: NaiveDateTime.t() | nil,
          equipment_id: String.t(),
          asset_id: String.t(),
          description: String.t(),
          lines: String.t(),
          work_order_id: String.t(),
          create_datetime: NaiveDateTime.t() | nil,
          update_datetime: NaiveDateTime.t() | nil,
          start_datetime: NaiveDateTime.t() | nil,
          end_datetime: NaiveDateTime.t() | nil,
          status: :open | :closed | :pending | :work_finished
        }

  @spec from_trapeze_line(String.t()) :: WorkOrder.t() | {atom(), String.t(), String.t()}
  def from_trapeze_line(input_line) do
    [
      file_process_datetime,
      equipment_id,
      asset_id,
      description,
      lines,
      work_order_id,
      create_datetime,
      update_datetime,
      start_datetime,
      end_datetime,
      status
    ] = String.split(input_line, "|")

    [fp, _location, effect, facility_id] = String.split(equipment_id, "-")

    if fp == "FP" do
      %__MODULE__{
        file_process_datetime: get_datetime(file_process_datetime),
        equipment_id: equipment_id,
        effect: effect(effect),
        facility_id: facility_id,
        asset_id: asset_id,
        description: description,
        lines: lines,
        work_order_id: work_order_id,
        create_datetime: get_datetime(create_datetime),
        update_datetime: get_datetime(update_datetime),
        start_datetime: get_datetime(start_datetime),
        end_datetime: get_datetime(end_datetime),
        status: convert_status(status)
      }
    else
      {:skip, work_order_id, "not public"}
    end
  end

  defp effect("ESCL"), do: :escalator
  defp effect("ELEV"), do: :elevator

  @spec to_params(WorkOrder.t() | {atom(), String.t(), String.t()}) ::
          AlertBuilder.alert_data_t() | {atom(), String.t(), String.t()}
  def to_params({:skip, work_order_id, reason}), do: {:skip, work_order_id, reason}

  def to_params(%__MODULE__{} = work_order) do
    %{
      active_period_end_specifier: :until_further_notice,
      active_period_end: end_datetime(work_order),
      active_period_start_specifier: :custom,
      active_period_start: work_order.start_datetime |> DateTime.to_naive(),
      alert_timing: :one_time,
      cause_detail: "MAINTENANCE",
      cause: :MAINTENANCE,
      child_stops_with_context: [],
      closed_timestamp: end_datetime(work_order),
      combination: :ACCESS,
      description_text: autotext(work_order) |> description_for(),
      direction: "default",
      effect_detail: effect_detail(work_order.effect),
      effect_name: effect_name(work_order.effect),
      effect: "ACCESSIBILITY_ISSUE",
      facility_id: work_order.facility_id,
      header_text: autotext(work_order) |> header_for(),
      notification_period_end: end_datetime(work_order),
      notification_period_start: work_order.start_datetime |> DateTime.to_naive(),
      notification_specifier: :now,
      reminder_times: [],
      route_ids: [],
      route_type: nil,
      route_types_by_id: %{},
      service_types: [],
      severity: 3,
      source: :TRAPEZE,
      status: work_order.status,
      stop_ids: [],
      stop_names_and_ids: [],
      trip_ids: [],
      trip_information_by_id: [],
      work_order_id: work_order.work_order_id
    }
  end

  defp autotext(work_order) do
    facility = FacilitiesRepo.get(work_order.facility_id)
    stops = if facility, do: [Map.get(facility, :stop)], else: []

    AlertDataToAutoText.build_autotext_data(%{
      route_type: nil,
      effect_name: effect_name(work_order.effect),
      cause_detail: "maintenance",
      start_datetime: work_order.start_datetime,
      end_specifier: :until_further_notice,
      facility: facility,
      stops: stops |> Enum.map(fn stop -> StopsRepo.get(stop.id) end)
    })
  end

  defp header_for(autotext),
    do: Templates.build_auto_text(autotext, :header_template)

  defp description_for(autotext),
    do: Templates.build_auto_text(autotext, :description_template)

  def service_effect_text_for(autotext),
    do: Templates.build_auto_text(autotext, :service_effect_template)

  defp end_datetime(%{end_datetime: datetime, status: :closed}),
    do: datetime |> DateTime.to_naive()

  defp end_datetime(_), do: nil

  defp effect_detail(:escalator), do: "ESCALATOR_CLOSURE"
  defp effect_detail(:elevator), do: "ELEVATOR_CLOSURE"

  defp effect_name(:escalator), do: "Escalator Closure"
  defp effect_name(:elevator), do: "Elevator Closure"

  defp get_datetime(iso8601_string) do
    case DateTime.from_iso8601(iso8601_string) do
      {:ok, datetime, _offset} -> datetime |> DateTime.shift_zone!("Etc/UTC")
      {:error, _} -> nil
    end
  end

  defp convert_status(status_text) do
    case status_text do
      "OPEN" -> :open
      "CLOSED" -> :closed
      "PENDING" -> :pending
      "WORK FINISHED" -> :work_finished
    end
  end
end
