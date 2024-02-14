defmodule AlertsUIWeb.FormComponents.AffectedService do
  @moduledoc """
    Live Component for affected service section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUIWeb.DateTimeHelpers
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.{Schedule, Trip}
  alias MBTAV3API.Stops.Stop

  @primary_key false
  embedded_schema do
    field :route_ids, {:array, :string}
    field :direction, :string
    field :trip_ids, {:array, :string}
    field :stop_ids, {:array, :string}
  end

  @fields ~w[route_ids direction trip_ids stop_ids]a

  @impl true
  def mount(socket) do
    form = %__MODULE__{} |> changeset() |> to_form()

    socket = socket |> assign(%{form: form})

    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    route_type = Map.get(alert_data, :route_type)

    if route_type do
      route_types = all_route_types(route_type)
      send(self(), {:fetch_available_routes, route_types})
    end

    {:ok, assign(socket, assigns)}
  end

  def handle_event("validate", %{"affected_service" => affected_service}, socket) do
    affected_service =
      affected_service
      |> populate_default_direction()
      |> populate_default_stops(socket)

    if show_trips_input?(socket.assigns),
      do:
        send(
          self(),
          {:fetch_available_schedules, Map.get(affected_service, "route_ids", []),
           affected_service["direction"]}
        )

    send(
      self(),
      {:fetch_available_stops, affected_service["direction"],
       Map.get(affected_service, "route_ids", [])}
    )

    changeset =
      %__MODULE__{}
      |> changeset(affected_service)
      |> Map.put(:action, :validate)

    changeset
    |> apply_action(:insert)
    |> case do
      {:ok, changeset} ->
        send(self(), {:section_completed, changeset})
    end

    {:noreply, assign(socket, %{form: to_form(changeset)})}
  end

  @impl true
  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  def changeset(changeset, params \\ %{}) do
    changeset
    |> cast(params, @fields)
  end

  @impl true
  def render(assigns) do
    route_id_options = formatted_select_options(assigns.available_routes)
    direction_options = formatted_direction_options(assigns.form[:route_ids].value)

    trip_id_options =
      assigns.available_schedules
      |> Enum.group_by(&name_for_option(&1.route))
      |> formatted_trip_options()

    stop_id_options = formatted_select_options(assigns.available_stops)

    assigns =
      assign(assigns,
        route_id_options: route_id_options,
        direction_options: direction_options,
        trip_id_options: trip_id_options,
        stop_id_options: stop_id_options
      )

    ~H"""
    <div
      class={unless @progress.name == "details", do: "hidden", else: "min-w-full flex flex-col"}
      id="service_view"
    >
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control gap-4"
        id="service_form"
      >
        <fieldset class="flex flex-row gap-4">
          <.input
            type="select"
            label="Route(s)"
            field={@form[:route_ids]}
            options={@route_id_options}
            multiple={true}
          />

          <.input
            type="select"
            label="Direction"
            field={@form[:direction]}
            options={@direction_options}
          />

          <%= if show_trips_input?(assigns) do %>
            <.input
              type="select"
              label="Trip(s)"
              field={@form[:trip_ids]}
              options={@trip_id_options}
              prompt={if Map.has_key?(assigns.form.params, "route_ids"), do: "All Trips", else: nil}
              multiple={true}
            />
          <% end %>

          <.input
            type="select"
            label="Stop(s)"
            field={@form[:stop_ids]}
            options={@stop_id_options}
            prompt={if Map.has_key?(assigns.form.params, "route_ids"), do: "All Stops", else: nil}
            multiple={true}
          />
        </fieldset>
      </.form>
      <hr />
    </div>
    """
  end

  # We lump subway together in the interface, so when asked for either light or
  # heavy rail include both.
  @spec all_route_types(0..4 | nil) :: [Route.type_int()]
  defp all_route_types(0), do: [0, 1]
  defp all_route_types(1), do: [0, 1]
  defp all_route_types(2), do: [2]
  defp all_route_types(3), do: [3]
  defp all_route_types(4), do: [4]
  defp all_route_types(_), do: []

  @spec populate_default_direction(map()) :: map()
  defp populate_default_direction(%{"route_ids" => [_ | _]} = affected_service),
    do: Map.put_new(affected_service, "direction", "")

  defp populate_default_direction(affected_service), do: affected_service

  # Show trips input for Commuter Rail or Ferry
  @spec show_trips_input?(map()) :: boolean()
  defp show_trips_input?(%{route_type: route_type}), do: Enum.member?([2, 4], route_type)

  @spec formatted_select_options([Route.t() | Stop.t()]) :: keyword(String.t())
  defp formatted_select_options(objects) do
    objects
    |> Enum.sort_by(&sort_order/1)
    |> Enum.map(fn object -> {name_for_option(object), id_for_option(object)} end)
  end

  @spec sort_order(Stop.t() | Route.t() | Schedule.t()) :: non_neg_integer() | nil
  # keep original order from API
  defp sort_order(%Stop{}), do: nil
  defp sort_order(%Schedule{}), do: nil
  defp sort_order(%Route{sort_order: sort_order}), do: sort_order

  @spec name_for_option(Stop.t() | Route.t() | Schedule.t()) :: String.t()
  defp name_for_option(%Stop{name: name}), do: name

  defp name_for_option(%Route{name: empty_name, long_name: long_name})
       when is_nil(empty_name) or empty_name == "",
       do: long_name

  defp name_for_option(%Route{name: name}), do: name

  defp name_for_option(%Schedule{
         trip: %Trip{name: trip_name},
         stop: %Stop{name: stop_name},
         departure_time: departure_time
       }) do
    "#{trip_name} (#{DateTimeHelpers.friendly_time(departure_time)} from #{stop_name})"
  end

  @spec id_for_option(Stop.t() | Route.t() | Schedule.t()) :: String.t()
  def id_for_option(%Stop{id: id}), do: id
  def id_for_option(%Route{id: id}), do: id
  def id_for_option(%Schedule{trip: %Trip{id: id}}), do: id

  @spec formatted_trip_options(%{String.t() => [Schedule.t()]}) :: keyword(String.t())
  defp formatted_trip_options(schedules_by_route_name) do
    if schedules_by_route_name |> Map.keys() |> length() <= 1 do
      schedules_by_route_name
      |> Map.values()
      |> List.flatten()
      |> formatted_select_options()
    else
      Enum.reduce(schedules_by_route_name, [], fn {route_name, schedules}, acc ->
        acc ++ [{route_name, formatted_select_options(schedules)}]
      end)
    end
  end

  @spec formatted_direction_options([String.t()] | nil) :: keyword(String.t())
  defp formatted_direction_options([_ | _]) do
    [
      "Both Directions": "",
      Outbound: "0",
      Inbound: "1"
    ]
  end

  defp formatted_direction_options(_), do: []

  defp populate_default_stops(affected_service, socket) do
    with true <- Map.get(affected_service, "stop_ids", nil) in [[""], []],
         false <- Enum.empty?(Map.get(affected_service, "route_ids", [])) do
      Map.put(
        affected_service,
        "stop_ids",
        Enum.map(socket.assigns.available_stops, &id_for_option(&1))
      )
    else
      _ -> affected_service
    end
  end
end
