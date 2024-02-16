defmodule AlertsUIWeb.FormComponents.AffectedService do
  @moduledoc """
    Live Component for affected service section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUIWeb.DateTimeHelpers
  alias AlertsUIWeb.FormComponents.DataHelpers.ServiceEffectCombinations
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
    form = %__MODULE__{} |> changeset(%{}) |> to_form()

    socket = socket |> assign(%{form: form, combination: nil})

    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    route_type = Map.get(alert_data, :route_type)
    effect_name = Map.get(alert_data, :effect_name)
    combination = ServiceEffectCombinations.get_combination(route_type, effect_name)

    # |> IO.inspect(label: :stops)
    if combination === :SR, do: get_stops_by_route_type(route_type)

    if combination !== :SR and route_type do
      route_types = all_route_types(route_type)
      send(self(), {:fetch_available_routes, route_types})
    end

    assigns = Map.put(assigns, :combination, combination)
    {:ok, assign(socket, assigns)}
  end

  def handle_event("validate", %{"affected_service" => affected_service}, socket) do
    affected_service =
      if socket.assigns.combination !== :SR do
        affected_service
        |> Map.put_new("direction", "default")
        |> populate_default_stops(socket)
      else
        affected_service
      end

    if show_trips_input?(socket.assigns),
      do:
        send(
          self(),
          {:fetch_available_schedules, Map.get(affected_service, "route_ids", []),
           affected_service["direction"]}
        )

    if socket.assigns.combination !== :SR, do: get_stops_by_route_ids(affected_service)

    if socket.assigns.combination === :SR,
      do:
        get_routes_by_stop_ids(
          Map.get(affected_service, "stop_ids", []),
          socket.assigns.alert_data.route_type
        )

    changeset =
      %__MODULE__{}
      |> changeset(affected_service, socket.assigns.combination)

    changeset
    |> apply_action(:insert)
    |> case do
      {:ok, changeset} ->
        send(self(), {:section_completed, changeset})
        changeset

      {:error, changeset} ->
        changeset
    end

    {:noreply, assign(socket, %{form: to_form(changeset |> Map.put(:action, :validate))})}
  end

  @impl true
  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  def changeset(changeset, params, combination \\ nil) do
    changeset
    |> cast(params, @fields)
    |> validate_required(ServiceEffectCombinations.required_fields(combination))
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
          <%= if show_routes_input?(assigns) do %>
            <.input
              type="select"
              label="Route(s)"
              field={@form[:route_ids]}
              options={@route_id_options}
              multiple={true}
              prompt={
                if Map.has_key?(@form.params, "stop_ids") and assigns.combination == :SR,
                  do: "All Routes",
                  else: nil
              }
            />
          <% end %>

          <%= if show_directions_input?(assigns) do %>
            <.input
              type="select"
              label="Direction"
              field={@form[:direction]}
              options={@direction_options}
              disabled={disable_input?(@form[:route_ids].value)}
              prompt={if Map.has_key?(@form.params, "route_ids"), do: "Both Directions", else: nil}
            />
          <% end %>

          <%= if show_trips_input?(assigns) do %>
            <.input
              type="select"
              label="Trip(s)"
              field={@form[:trip_ids]}
              options={@trip_id_options}
              prompt={if Map.has_key?(@form.params, "route_ids"), do: "All Trips", else: nil}
            />
          <% end %>

          <%= if show_stops_input?(assigns) do %>
            <.input
              type="select"
              label="Stop(s)"
              field={@form[:stop_ids]}
              options={@stop_id_options}
              prompt={
                if Map.has_key?(@form.params, "route_ids") and assigns.combination !== :SR,
                  do: "All Stops",
                  else: nil
              }
              multiple={true}
              disabled={disable_input?(@form[:route_ids].value)}
              class={if assigns.combination == :SR, do: "order-first", else: ""}
            />
          <% end %>
        </fieldset>
      </.form>
      <hr />
    </div>
    """
  end

  def get_stops_by_route_type(route_type) do
    send(
      self(),
      {:fetch_stops_by_route_type, route_type}
    )
  end

  def get_stops_by_route_ids(affected_service) do
    send(
      self(),
      {:fetch_available_stops, affected_service["direction"],
       Map.get(affected_service, "route_ids", [])}
    )
  end

  def get_routes_by_stop_ids(nil, _route_type), do: nil

  def get_routes_by_stop_ids(stop_ids, route_type) do
    send(
      self(),
      {:fetch_routes_by_stop, stop_ids, route_type}
    )
  end

  @spec show_routes_input?(map()) :: boolean()
  defp show_routes_input?(%{combination: combination, form: form}) do
    !(combination in [:SR] and is_nil(form[:stop_ids].value))
  end

  @spec show_trips_input?(map()) :: boolean()
  defp show_trips_input?(%{combination: combination}) do
    combination in [:RDT, :RDTS]
  end

  @spec show_stops_input?(map()) :: boolean()
  defp show_stops_input?(%{combination: combination} = _assigns) do
    combination in [:RDS, :RDTS, :SR]
  end

  @spec show_directions_input?(map()) :: boolean()
  defp show_directions_input?(%{combination: combination}) do
    combination in [:RDS, :RDTS, :RDS, :RDT]
  end

  @spec disable_input?(list() | nil) :: boolean()
  defp disable_input?(route_ids), do: !is_nil(route_ids) and length(route_ids) > 1

  # We lump subway together in the interface, so when asked for either light or
  # heavy rail include both.
  @spec all_route_types(0..4 | nil) :: [Route.type_int()]
  defp all_route_types(0), do: [0, 1]
  defp all_route_types(1), do: [0, 1]
  defp all_route_types(2), do: [2]
  defp all_route_types(3), do: [3]
  defp all_route_types(4), do: [4]
  defp all_route_types(_), do: []

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
      Outbound: "0",
      Inbound: "1"
    ]
  end

  defp formatted_direction_options(_), do: []

  defp populate_default_stops(affected_service, socket) do
    if length(Map.get(affected_service, "route_ids", [])) > 0 do
      Map.put(
        affected_service,
        "stop_ids",
        Enum.map(socket.assigns.available_stops, &id_for_option(&1))
      )
    else
      affected_service
    end
  end
end
