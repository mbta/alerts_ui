defmodule AlertsUIWeb.FormComponents.StopRouteAffectedService do
  @moduledoc """
    Live Component for affected service section of form with stop-route combination
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUIWeb.FormComponents.Helpers.SelectFormatter
  alias MBTAV3API.Routes.Route

  @primary_key false
  embedded_schema do
    field :route_ids, {:array, :string}
    field :stop_ids, {:array, :string}
  end

  @fields ~w[route_ids stop_ids]a
  @required_fields ~w[route_ids stop_ids]a

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

    {:ok, assign(socket, assigns)}
  end

  def handle_event("validate", %{"stop_route_affected_service" => affected_service}, socket) do
    get_routes_by_stop_ids(
      Map.get(affected_service, "stop_ids", []),
      socket.assigns.alert_data.route_type
    )

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
      formatted_stop_route_select_options(assigns.available_routes)

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
              prompt={
                if Map.has_key?(@form.params, "stop_ids"),
                  do: "All Routes",
                  else: nil
              }
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

  @spec formatted_stop_route_select_options([Route.t()]) :: keyword(String.t())
  def formatted_stop_route_select_options(objects) do
    objects
    |> Enum.sort_by(&SelectFormatter.sort_order/1)
    |> Enum.map(fn object ->
      {SelectFormatter.name_for_option(object), id_for_route_with_route_type(object)}
    end)
  end

  @spec id_for_route_with_route_type(Route.t()) :: String.t()
  def id_for_route_with_route_type(%Route{id: id, type: type}), do: "#{id},#{type}"
end
