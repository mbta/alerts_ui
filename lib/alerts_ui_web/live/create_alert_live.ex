defmodule AlertsUIWeb.Step do
  @moduledoc "Describe a step in the multi-step form and where it can go."

  @doc """
  Returns list of atoms allowed in alert lifecycle field of alert

  ## Examples
      iex> %AlertsUIWeb.Step{name: "example", previous: "cool", next: "bean", label: "hi"}
      %AlertsUIWeb.Step{name: "example", previous: "cool", next: "bean", label: "hi"}
  """
  defstruct [:name, :previous, :next, :label]

  @type t :: %__MODULE__{
          name: String.t(),
          previous: String.t() | nil,
          next: String.t() | nil,
          label: String.t()
        }
end

defmodule AlertsUIWeb.CreateAlertLive do
  use AlertsUIWeb, :live_view
  alias AlertsUI.AlertBuilder
  alias AlertsUI.Alerts
  alias AlertsUIWeb.Step

  alias AlertsUIWeb.FormComponents.{
    AffectedService,
    AlertDetails,
    RouteTypeAndEffect,
    SuccessfulSubmission,
    Timeline
  }

  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @steps [
    %Step{
      name: "route_type_and_effect",
      previous: nil,
      next: "details",
      label: "Select Alert Type"
    },
    %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    %Step{name: "success", previous: nil, next: nil, label: "Success"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    first_step = List.first(@steps)

    socket =
      assign(socket, %{
        progress: first_step,
        steps: @steps,
        alert_data: %{},
        available_routes: [],
        available_schedules: [],
        available_stops: []
      })

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("move_progress", %{"value" => name}, socket) do
    {:noreply, assign(socket, :progress, get_step_by_name(name))}
  end

  def handle_info({:fetch_available_routes, route_types}, socket) do
    available_routes = RoutesRepo.by_type(route_types)
    {:noreply, assign(socket, available_routes: available_routes)}
  end

  def handle_info({:fetch_available_schedules, route_ids, direction}, socket) do
    directions = directions_from_selection(direction)
    opts = direction_option([stop_sequences: :first], directions)

    available_schedules = SchedulesRepo.by_route_ids(route_ids, opts)

    {:noreply, assign(socket, available_schedules: available_schedules)}
  end

  def handle_info({:fetch_available_stops, direction, route_ids}, socket) do
    available_stops = available_stops(direction, route_ids)
    {:noreply, assign(socket, available_stops: available_stops)}
  end

  def handle_info({:save_as_draft, changeset}, socket) do
    socket.assigns.alert_data
    |> Map.merge(changeset |> Map.from_struct())
    |> AlertBuilder.build_alert()
    |> Alerts.create_draft_alert()
    |> case do
      {:ok, _result} ->
        socket = put_flash(socket, :info, "Draft Saved Successfully")
        {:noreply, redirect(socket, to: "/alerts/new")}

      {:error, result} ->
        errors =
          result
          |> Alerts.parse_changeset_errors()
          |> format_errors

        socket = put_flash(socket, :error, errors)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:section_completed, changeset}, socket) do
    assigns = %{
      alert_data: Map.merge(socket.assigns.alert_data, changeset |> Map.from_struct())
    }

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_info({:step_completed, changeset}, socket) do
    assigns = %{
      progress: get_step_by_name(socket.assigns.progress.next),
      alert_data: Map.merge(socket.assigns.alert_data, changeset |> Map.from_struct())
    }

    {:noreply, assign(socket, assigns)}
  end

  def handle_info({:create_alert, changeset}, socket) do
    socket.assigns.alert_data
    |> Map.merge(changeset |> Map.from_struct())
    |> AlertBuilder.build_alert()
    |> Alerts.create_alert()
    |> case do
      {:ok, _result} ->
        assigns = %{
          progress: get_step_by_name(socket.assigns.progress.next),
          alert_data: %{}
        }

        {:noreply, assign(socket, assigns)}

      {:error, result} ->
        errors =
          result
          |> Alerts.parse_changeset_errors()
          |> format_errors

        socket = put_flash(socket, :error, errors)
        {:noreply, socket}
    end
  end

  @spec directions_from_selection(String.t() | nil) :: [Trip.direction_id_t()]
  # Both directions
  defp directions_from_selection(""), do: [0, 1]
  defp directions_from_selection("0"), do: [0]
  defp directions_from_selection("1"), do: [1]
  defp directions_from_selection(_), do: []

  @spec direction_option(keyword(), [Trip.direction_id_t()]) :: keyword()
  defp direction_option(opts, [single_direction_id | []]),
    do: put_in(opts[:direction_id], single_direction_id)

  defp direction_option(opts, _both_directions), do: opts

  defp format_errors(errors) do
    Enum.map_join(errors, "; ", fn {title, values} ->
      values =
        values
        |> Enum.map_join(", ", &parse_inner_value(&1))

      "#{title}: #{values}"
    end)
  end

  defp parse_inner_value(value) do
    case is_map(value) do
      true -> format_errors(value)
      false -> value
    end
  end

  defp get_step_by_name(name) do
    Enum.find(@steps, &(&1.name == name))
  end

  @spec route_type(map()) :: 0..4 | nil
  defp route_type(alert_data), do: Map.get(alert_data, :route_type)

  @spec available_stops(String.t(), [String.t()]) :: [Stop.t()]
  defp available_stops([], _route_ids), do: []

  defp available_stops("", route_ids) do
    route_ids
    |> Enum.flat_map(fn route ->
      Enum.flat_map([0, 1], &StopsRepo.by_route(route, &1))
    end)
  end

  defp available_stops(direction, route_ids) do
    route_ids
    |> Enum.flat_map(fn route ->
      StopsRepo.by_route(route, direction)
    end)
  end

  defp compare_feed,
    do: Application.get_env(:alerts_ui, :compare_feed) == "true"
end
