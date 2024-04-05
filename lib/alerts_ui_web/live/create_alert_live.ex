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
  alias AlertsUI.Models.Alert
  alias AlertsUI.Routes

  alias AlertsUIWeb.FormComponents.{
    AffectedService,
    AlertDetails,
    RouteTypeAndEffect,
    StopRouteAffectedService,
    SuccessfulSubmission,
    Timeline
  }

  alias AlertsUIWeb.FormComponents.Helpers.{AlertData, ServiceEffectCombinations}
  alias AlertsUIWeb.Step
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
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
  def mount(params, _session, socket) do
    alert_id = Map.get(params, "alert_id")

    alert_data =
      if is_nil(alert_id),
        do: %{},
        else: AlertData.build_alert_data(alert_id)

    [first_step, second_step | _] = @steps
    editing = socket.assigns.live_action == :edit

    socket =
      assign(socket, %{
        page_title: "Create an Alert",
        progress: if(editing, do: second_step, else: first_step),
        steps: @steps,
        alert_data: alert_data,
        combination: Map.get(alert_data, :combination),
        available_routes: [],
        available_schedules: [],
        available_stops: [],
        alert_uuid: nil,
        alert_id: alert_id,
        editing: editing
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
    available_routes =
      route_types
      |> RoutesRepo.by_type()
      |> maybe_include_virtual_green_line()

    {:noreply, assign(socket, available_routes: available_routes)}
  end

  def handle_info({:fetch_routes_by_stop, stop_ids, route_type}, socket) do
    available_routes =
      if route_type == 3,
        do: Enum.flat_map(stop_ids, &RoutesRepo.by_stop(&1, type: 3)),
        else: Enum.flat_map(stop_ids, &RoutesRepo.by_stop(&1))

    available_routes = maybe_include_virtual_green_line(available_routes)

    {:noreply, assign(socket, available_routes: available_routes)}
  end

  def handle_info({:fetch_available_schedules, route_ids, direction}, socket) do
    directions = directions_from_selection(direction)
    opts = direction_option([stop_sequences: :first], directions)

    available_schedules = SchedulesRepo.by_route_ids(route_ids, opts)

    {:noreply, assign(socket, available_schedules: available_schedules)}
  end

  def handle_info({:fetch_available_stops, direction, route_ids}, socket) do
    route_ids = Routes.expanding_green_line(route_ids)

    available_stops =
      direction
      |> directions_from_selection()
      |> available_stops(route_ids)

    {:noreply, assign(socket, available_stops: available_stops)}
  end

  def handle_info({:fetch_stops_by_route_type, route_type}, socket) do
    available_stops = StopsRepo.by_route_type(route_type) |> Enum.sort_by(& &1.name)
    {:noreply, assign(socket, available_stops: available_stops)}
  end

  def handle_info({:save_as_draft, changeset}, socket) do
    socket.assigns.alert_data
    |> Map.merge(changeset |> Map.from_struct())
    |> AlertBuilder.build_alert(Map.get(socket.assigns, :combination))
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
    alert_data = Map.merge(socket.assigns.alert_data, changeset |> Map.from_struct())
    route_type = Map.get(alert_data, :route_type)
    effect_name = Map.get(alert_data, :effect_name)

    combination =
      socket.assigns.combination ||
        ServiceEffectCombinations.get_combination(route_type, effect_name)

    assigns = %{
      progress: get_step_by_name(socket.assigns.progress.next),
      alert_data: alert_data,
      combination: combination
    }

    {:noreply, assign(socket, assigns)}
  end

  def handle_info({:create_alert, changeset}, socket) do
    alert_map =
      socket.assigns.alert_data
      |> Map.merge(changeset |> Map.from_struct())
      |> AlertBuilder.build_alert(socket.assigns.combination)

    existing_alert =
      if is_nil(socket.assigns.alert_id) do
        %Alert{}
      else
        Alerts.get_by_alert_id(socket.assigns.alert_id)
      end

    alert_map
    |> Alerts.create_or_update_alert(existing_alert)
    |> case do
      {:ok, result} ->
        assigns = %{
          progress: get_step_by_name(socket.assigns.progress.next),
          alert_data: %{},
          alert_uuid: result.id
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
  defp directions_from_selection("default"), do: [0, 1]
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

  @spec maybe_include_virtual_green_line([Route.t()]) :: [Route.t()]
  defp maybe_include_virtual_green_line(routes) do
    if Enum.any?(routes, &green_line_route?/1) do
      [RoutesRepo.green_line() | routes]
    else
      routes
    end
  end

  @spec green_line_route?(Route.t()) :: boolean()
  def green_line_route?(%Route{id: "Green"}), do: true
  def green_line_route?(%Route{id: "Green-B"}), do: true
  def green_line_route?(%Route{id: "Green-C"}), do: true
  def green_line_route?(%Route{id: "Green-D"}), do: true
  def green_line_route?(%Route{id: "Green-E"}), do: true
  def green_line_route?(_), do: false

  @spec available_stops([String.t()], [String.t()]) :: [Stop.t()]
  defp available_stops([], _route_ids), do: []

  defp available_stops(direction_array, route_ids) do
    route_ids
    |> Enum.flat_map(fn route ->
      Enum.flat_map(direction_array, &StopsRepo.by_route(route, &1))
    end)
  end

  defp compare_feed,
    do: Application.get_env(:alerts_ui, :compare_feed) == "true"
end
