defmodule AlertsUIWeb.FormComponents.AffectedService do
  @moduledoc """
    Live Component for affected service section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUIWeb.FormComponents.Helpers.{SelectFormatter, ServiceEffectCombinations}
  alias MBTAV3API.Routes.Route

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

    socket = socket |> assign(%{form: form})

    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    route_type = Map.get(alert_data, :route_type)
    route_types = all_route_types(route_type)
    send(self(), {:fetch_available_routes, route_types})
    verify(Map.get(socket.assigns, :affected_service), assign(socket, assigns))
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("validate", %{"affected_service" => affected_service}, socket) do
    verify(affected_service, socket)
  end

  def verify(nil, socket) do
    {:noreply, socket}
  end

  def verify(affected_service, %{assigns: %{combination: _combination}} = socket) do
    affected_service =
      affected_service
      |> Map.put_new("direction", "default")
      |> populate_default_stops(Map.get(socket.assigns, :available_stops, []))

    get_stops_by_route_ids(affected_service)

    if show_trips_input?(socket.assigns),
      do:
        get_schedules_by_route_ids(
          Map.get(affected_service, "route_ids", []),
          affected_service["direction"]
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

    {:noreply,
     assign(socket, %{
       form: to_form(changeset |> Map.put(:action, :validate)),
       affected_service: affected_service
     })}
  end

  def verify(_, socket) do
    {:noreply, socket}
  end

  def changeset(changeset, params, combination \\ nil) do
    changeset
    |> cast(params, @fields)
    |> validate_required(ServiceEffectCombinations.required_fields(combination))

    # TODO
  end

  @impl true
  def render(assigns) do
    route_id_options = SelectFormatter.formatted_select_options(assigns.available_routes)

    direction_options =
      SelectFormatter.formatted_direction_options(assigns.form[:route_ids].value)

    trip_id_options =
      assigns.available_schedules
      |> Enum.group_by(&SelectFormatter.name_for_option(&1.route))
      |> SelectFormatter.formatted_trip_options()

    stop_id_options = SelectFormatter.formatted_select_options(assigns.available_stops)

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
                if Map.has_key?(@form.params, "route_ids"),
                  do: "All Stops",
                  else: nil
              }
              multiple={true}
              disabled={disable_input?(@form[:route_ids].value)}
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

  def get_schedules_by_route_ids(route_ids, direction) do
    send(
      self(),
      {:fetch_available_schedules, route_ids, direction}
    )
  end

  @spec show_trips_input?(map()) :: boolean()
  defp show_trips_input?(%{combination: combination}) do
    combination in [:RDT, :RDTS]
  end

  @spec show_stops_input?(map()) :: boolean()
  defp show_stops_input?(%{combination: combination}) do
    combination in [:RDS, :RDTS]
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

  defp populate_default_stops(affected_service, available_stops) do
    if Map.get(affected_service, "stop_ids") in [nil, [], ["default"]] do
      Map.put(
        affected_service,
        "stop_ids",
        Enum.map(available_stops, &SelectFormatter.id_for_option(&1))
      )
    else
      affected_service
    end
  end
end
