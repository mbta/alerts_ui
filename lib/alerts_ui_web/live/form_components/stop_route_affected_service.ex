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
    field :route_ids_filter, :string
    field :stop_ids, {:array, :string}
    field :stop_ids_filter, :string
    field :route_types_by_id, {:map, :integer}
  end

  @fields ~w[route_ids stop_ids route_types_by_id route_ids_filter stop_ids_filter]a
  @required_fields ~w[route_ids stop_ids route_types_by_id]a

  @impl true
  def mount(socket) do
    form = %__MODULE__{} |> changeset(%{}) |> to_form()

    socket = socket |> assign(%{form: form})

    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data, editing: editing} = assigns, socket) do
    route_type = Map.get(alert_data, :route_type)
    get_stops_by_route_type(route_type)

    assigns =
      case editing do
        true -> update_for_edit(alert_data, assigns)
        false -> assigns
      end

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("validate", %{"stop_route_affected_service" => affected_service}, socket) do
    affected_service = populate_default_routes(affected_service)
    Map.get(affected_service, "stop_ids", [])

    get_routes_by_stop_ids(
      Map.get(affected_service, "stop_ids", []),
      socket.assigns.alert_data.route_type
    )

    changeset = validate(affected_service, socket.assigns)

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

    get_routes_by_stop_ids(
      edit_alert_data.stop_ids,
      assigns.alert_data.route_type
    )

    changeset =
      validate(edit_alert_data |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end), assigns)

    form = to_form(changeset |> Map.put(:action, :validate))

    edit_alert_data |> Map.put(:form, form) |> Map.merge(assigns)
  end

  def validate(affected_service, assigns) do
    routes_with_types = routes_with_types(assigns.available_routes, affected_service["route_ids"])
    affected_service = Map.put(affected_service, "route_types_by_id", routes_with_types)

    %__MODULE__{}
    |> changeset(affected_service)
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

  def routes_with_types(available_routes, route_ids) do
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
      class={unless @progress.name == "details", do: "hidden", else: "min-w-full mb-8 min-h-[32rem]"}
      id="stop_route_service_view"
    >
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control gap-4 mb-16 min-h-[30rem]"
        id="service_form"
      >
        <fieldset class="flex flex-row gap-x-12 min-h-[30rem]">
          <.multiselect
            label="Stop(s)"
            field={@form[:stop_ids]}
            filter_field={@form[:stop_ids_filter]}
            options={@stop_id_options}
            class="min-w-[24rem]"
          />

          <%= if show_routes_input?(assigns) do %>
            <.multiselect
              label="Route(s)"
              field={@form[:route_ids]}
              filter_field={@form[:route_ids_filter]}
              id="stop_route_routes"
              options={@route_id_options}
              class="min-w-[18rem]"
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

  @spec populate_default_routes(map()) :: map()
  defp populate_default_routes(affected_service) do
    if Map.get(affected_service, "route_ids") in [nil, "default", ["default"]] do
      Map.put(affected_service, "route_ids", [])
    else
      affected_service
    end
  end
end
