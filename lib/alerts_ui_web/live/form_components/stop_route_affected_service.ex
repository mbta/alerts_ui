defmodule AlertsUIWeb.FormComponents.StopRouteAffectedService do
  @moduledoc """
    Live Component for affected service section of form with stop-route combination
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUIWeb.FormComponents.Helpers.SelectFormatter

  @primary_key false
  embedded_schema do
    field :route_ids, {:array, :string}
    field :stop_ids, {:array, :string}
    field :route_types_by_id, {:map, :integer}
  end

  @fields ~w[route_ids stop_ids route_types_by_id]a
  @required_fields ~w[route_ids stop_ids route_types_by_id]a

  @impl true
  def mount(socket) do
    form = %__MODULE__{} |> changeset(%{}) |> to_form()

    socket = socket |> assign(%{form: form})

    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    route_type = Map.get(alert_data, :route_type)
    get_stops_by_route_type(route_type)

    assigns =
      case Map.get(alert_data, :route_ids) do
        nil -> assigns
        _ -> update_for_edit(alert_data, assigns)
      end

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("validate", %{"stop_route_affected_service" => affected_service}, socket) do
    get_routes_by_stop_ids(
      Map.get(affected_service, "stop_ids", []),
      socket.assigns.alert_data.route_type
    )

    route_ids = Map.get(affected_service, "route_ids", [])

    routes_with_types =
      socket.assigns.available_routes
      |> Stream.filter(fn route -> route.id in route_ids end)
      |> Enum.reduce(%{}, fn route, acc ->
        Map.put(acc, route.id, route.type)
      end)

    affected_service = Map.put(affected_service, "route_types_by_id", routes_with_types)

    changeset =
      %__MODULE__{}
      |> changeset(affected_service)

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

  def update_for_edit(alert_data, assigns) do
    edit_alert_data =
      %{
        route_ids: Map.get(alert_data, :route_ids) || [],
        stop_ids: Map.get(alert_data, :stop_ids) || []
      }

    routes_with_types = routes_with_types(assigns.available_routes, edit_alert_data.route_ids)

    edit_alert_data = Map.put(edit_alert_data, :route_types_by_id, routes_with_types)

    changeset =
      %__MODULE__{}
      |> changeset(edit_alert_data)

    form = to_form(changeset |> Map.put(:action, :validate))

    edit_alert_data |> Map.put(:form, form) |> Map.merge(assigns)
  end

  def changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end

  def get_stops_by_route_type(route_type) do
    send(
      self(),
      {:fetch_stops_by_route_type, route_type}
    )
  end

  #TODO
  def routes_with_types(available_routes, route_ids) do
    routes_with_types =
      available_routes
      |> Stream.filter(fn route -> route.id in route_ids end)
      |> Enum.reduce(%{}, fn route, acc ->
        Map.put(acc, route.id, route.type)
      end)
  end

  def get_routes_by_stop_ids(nil, _route_type), do: nil

  def get_routes_by_stop_ids(stop_ids, route_type) do
    send(
      self(),
      {:fetch_routes_by_stop, stop_ids, route_type}
    )
  end

  @impl true
  def render(assigns) do
    route_id_options =
      SelectFormatter.formatted_select_options(assigns.available_routes)

    stop_id_options = SelectFormatter.formatted_select_options(assigns.available_stops)

    assigns =
      assign(assigns,
        route_id_options: route_id_options,
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
        phx-click-alway="validate"
        phx-blur="validate"
        class="form-control gap-4"
        id="service_form"
      >
        <fieldset class="flex flex-row gap-4">
          <.input
            type="select"
            label="Stop(s)"
            field={@form[:stop_ids]}
            options={@stop_id_options}
            multiple={true}
          />

          <%= if show_routes_input?(assigns) do %>
            <.input
              type="select"
              label="Route(s)"
              field={@form[:route_ids]}
              options={@route_id_options}
              multiple={true}
              id="stop_route_routes"
            />
          <% end %>
        </fieldset>
      </.form>
      <hr />
    </div>
    """
  end

  @spec show_routes_input?(map()) :: boolean()
  defp show_routes_input?(%{form: form}) do
    !is_nil(form[:stop_ids].value)
  end
end
