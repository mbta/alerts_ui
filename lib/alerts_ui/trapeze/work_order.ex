defmodule AlertsUI.Trapeze.WorkOrder do
  @moduledoc """
  One escalator/elevator work order
  """

  alias AlertsUI.Trapeze.WorkOrder
  alias AlertsUIWeb.CreateAlertLive.Helpers.AutoText.AlertDataToAutoText
  alias AlertsUIWeb.CreateAlertLive.Helpers.AutoText.Templates
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
          file_process_datetime: DateTime.t() | nil,
          equipment_id: String.t(),
          asset_id: String.t(),
          description: String.t(),
          lines: String.t(),
          work_order_id: String.t(),
          create_datetime: DateTime.t() | nil,
          update_datetime: DateTime.t() | nil,
          start_datetime: DateTime.t() | nil,
          end_datetime: DateTime.t() | nil,
          status: :open | :closed | :pending | :work_finished
        }

  @spec from_trapeze_line(String.t()) :: {:ok, WorkOrder.t()} | {:skip, String.t()}
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
      {:ok,
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
       }}
    else
      {:skip, "equipment_id (column B) marked #{fp}"}
    end
  end

  defp effect("ESCL"), do: :escalator
  defp effect("ELEV"), do: :elevator

  @spec to_params(WorkOrder.t()) :: {:ok, map()}
  def to_params(%__MODULE__{} = work_order) do
    {:ok,
     %{
       active_period_end_specifier: end_datetime_specifier(work_order),
       active_period_end: end_datetime(work_order),
       active_period_start_specifier: :custom,
       active_period_start: DateTime.utc_now() |> to_naive_eastern(),
       alert_timing: :one_time,
       cause_detail: "MAINTENANCE",
       cause: :MAINTENANCE,
       stops_with_context: [],
       closed_timestamp: end_datetime(work_order),
       combination: :ACCESS,
       description_text: autotext(work_order) |> description_for(),
       direction: "",
       effect_detail: effect_detail(work_order.effect),
       effect_name: effect_name(work_order.effect),
       effect: "ACCESSIBILITY_ISSUE",
       facility_ids: [work_order.facility_id],
       header_text: autotext(work_order) |> header_for(),
       notification_period_end: end_datetime(work_order),
       notification_period_start: work_order.start_datetime |> to_naive_eastern(),
       notification_specifier: :now,
       reminder_times: [],
       route_ids: [],
       route_type: nil,
       route_types_by_id: %{},
       service_effect_text: autotext(work_order) |> service_effect_text_for(),
       service_types: [],
       severity: 3,
       source: :TRAPEZE,
       status: work_order.status,
       stop_ids: [],
       stop_names_and_ids: [],
       trip_ids: [],
       trip_information_by_id: [],
       work_order_id: work_order.work_order_id
     }}
  end

  def autotext(work_order) do
    facility = FacilitiesRepo.get(work_order.facility_id)
    stops = if facility, do: [Map.get(facility, :stop)], else: []

    AlertDataToAutoText.build_autotext_data(%{
      route_type: nil,
      effect_name: effect_name(work_order.effect),
      cause_detail: "maintenance",
      start_datetime: work_order.start_datetime |> to_naive_eastern(),
      end_specifier: :until_further_notice,
      facilities: [facility],
      stops: stops |> Enum.map(fn stop -> StopsRepo.get(stop.id) end)
    })
  end

  defp header_for(autotext),
    do: Templates.build_auto_text(autotext, :header_template)

  defp description_for(autotext) do
    case Templates.build_auto_text(autotext, :description_template) do
      "" -> nil
      description -> description
    end
  end

  def service_effect_text_for(autotext),
    do: Templates.build_auto_text(autotext, :service_effect_template)

  defp end_datetime(%{end_datetime: datetime, status: :closed}),
    do: datetime |> to_naive_eastern()

  defp end_datetime(_), do: nil

  defp end_datetime_specifier(%{end_datetime: datetime, status: :closed})
       when not is_nil(datetime),
       do: :custom

  defp end_datetime_specifier(_), do: :until_further_notice

  defp effect_detail(:escalator), do: "ESCALATOR_CLOSURE"
  defp effect_detail(:elevator), do: "ELEVATOR_CLOSURE"

  defp effect_name(:escalator), do: "Escalator Closure"
  defp effect_name(:elevator), do: "Elevator Closure"

  defp get_datetime(iso8601_string) do
    case DateTime.from_iso8601(iso8601_string) do
      {:ok, datetime, _offset} -> datetime
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

  defp to_naive_eastern(%DateTime{} = datetime),
    do:
      datetime
      |> DateTime.shift_zone!("America/New_York")
      |> DateTime.to_naive()
end
