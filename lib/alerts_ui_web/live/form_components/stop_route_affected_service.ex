defmodule AlertsUIWeb.FormComponents.StopRouteAffectedService do
  @moduledoc """
    Live Component for affected service section of form with stop-route combination
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertLive
  alias AlertsUIWeb.FormComponents.Helpers.{ContentFormatter, ErrorFormatter, SelectFormatter}
  alias Phoenix.LiveView.AsyncResult

  @primary_key false
  embedded_schema do
    field :route_ids, {:array, :string}
    field :route_ids_filter, :string
    field :stop_ids, {:array, :string}
    field :stop_ids_filter, :string
    field :route_types_by_id, {:map, :integer}
  end

  @fields ~w[route_ids stop_ids route_types_by_id route_ids_filter stop_ids_filter]a
  @required_fields ~w[route_ids stop_ids]a

  # The "form" value on line 42 does NOT include the validation on line 33
  @impl true
  def mount(socket) do
    changeset = build_changeset(%__MODULE__{}, %{})

    {_result, error_changeset} =
      apply_action(
        changeset
        |> validate_required(@required_fields),
        :validate
      )

    send(self(), {:add_errors, ErrorFormatter.parse_field_errors(error_changeset), __MODULE__})

    socket =
      socket
      |> assign(%{
        form: to_form(changeset),
        available_routes: %{},
        available_stops: %{},
        edited: false
      })

    {:ok, socket}
  end

  # The "form" never goes through the `validate_required` logic and doesn't need to (because this is edit only)
  # Occurs when alert is being edited
  @impl true
  def update(
        %{alert_data: alert_data, editing: true, route_type: route_type} = assigns,
        socket
      ) do
    changeset = build_changeset(%__MODULE__{}, alert_data)
    # No need to use single pipe if not a chain
    changes = apply_action!(changeset, :validate)

    send(self(), {:add_errors, [], __MODULE__})
    send(self(), {:section_completed, changes})

    # Reformatted to make this look like the other instances of this same logic
    form =
      changeset
      # needed?
      |> Map.put(:action, :validate)
      |> to_form()

    # Other functions put the assigns inline with the socket logic
    socket =
      socket
      |> assign(assigns)
      |> assign(service_type_name: route_type |> InformedEntity.route_code_mapping() || nil)
      |> assign(form: form)
      |> assign(route_type: route_type)
      |> assign_async([:available_stops, :available_routes], fn ->
        {:ok,
         %{
           available_stops: CreateAlertLive.get_stops_by_route_type(route_type),
           available_routes:
             CreateAlertLive.get_routes_by_stop(
               Map.get(alert_data, :stop_ids, []),
               route_type
             )
         }}
      end)

    {:ok, socket}
  end

  # The "form" value on line 108 DOES include the validation from line 100
  # The form was submitted but submission had an error, so the same component rerenders
  @impl true
  def update(%{submitted: true}, socket) do
    changeset =
      %__MODULE__{}
      |> build_changeset(socket.assigns.form.params)
      |> validate_required(@required_fields)

    errors =
      case apply_action(changeset, :validate) do
        {:ok, _changeset} -> []
        {:error, changeset} -> ErrorFormatter.parse_field_errors(changeset)
      end

    form =
      changeset
      |> Map.put(:errors, errors)
      # needed?
      |> Map.put(:action, :validate)
      |> to_form()

    {:ok, assign(socket, form: form)}
  end

  @impl true
  def update(
        %{route_type: route_type} = assigns,
        socket
      ) do
    socket =
      socket
      |> assign(assigns)
      |> assign(service_type_name: route_type |> InformedEntity.route_code_mapping() || nil)
      |> assign_async([:available_stops], fn ->
        {:ok, %{available_stops: CreateAlertLive.get_stops_by_route_type(route_type)}}
      end)

    {:ok, socket}
  end

  # On stop select, need to populate and select all of the route_ids
  @impl true
  def handle_event(
        "validate",
        %{
          "_target" => ["stop_route_affected_service", "stop_ids"],
          "stop_route_affected_service" => affected_service
        },
        socket
      ) do
    available_routes = Map.get(socket.assigns.available_routes, :result, [])
    affected_service = add_routes_with_types(affected_service, available_routes)

    changeset = build_changeset(%__MODULE__{}, affected_service)

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    route_type = socket.assigns.route_type

    socket =
      socket
      |> assign(:available_routes, AsyncResult.loading())
      |> start_async(:get_available_routes, fn ->
        CreateAlertLive.get_routes_by_stop(
          Map.get(affected_service, "stop_ids", []),
          route_type
        )
      end)
      |> assign(form: form)

    {:noreply, socket}
  end

  # On route select, don't need to do anything but save the change
  @impl true
  def handle_event("validate", %{"stop_route_affected_service" => affected_service}, socket) do
    available_routes = Map.get(socket.assigns.available_routes, :result, [])
    affected_service = add_routes_with_types(affected_service, available_routes)

    changeset = build_changeset(%__MODULE__{}, affected_service)

    case apply_action(changeset |> validate_required(@required_fields), :validate) do
      {:ok, changeset} ->
        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changeset})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
    end

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_async(:get_available_routes, {:ok, fetched_routes}, socket) do
    %{available_routes: available_routes} = socket.assigns
    # "Validate" was misleading because it was only adding routes to the affected_service object
    affected_service =
      add_routes_with_types(
        Map.merge(socket.assigns.form.params, %{"route_ids" => Enum.map(fetched_routes, & &1.id)}),
        fetched_routes
      )

    changeset = build_changeset(%__MODULE__{}, affected_service)

    case apply_action(changeset |> validate_required(@required_fields), :validate) do
      {:ok, changeset} ->
        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changeset})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
    end

    form =
      changeset
      # Why this here, when apply_action also happened?
      |> Map.put(:action, :validate)
      |> to_form()

    socket =
      socket
      |> assign(:available_routes, AsyncResult.ok(available_routes, fetched_routes))
      |> assign(form: form)

    {:noreply, socket}
  end

  @impl true
  def handle_async(:get_available_routes, {:exit, reason}, socket) do
    %{available_routes: available_routes} = socket.assigns

    {:noreply,
     assign(socket, :available_routes, AsyncResult.failed(available_routes, {:exit, reason}))}
  end

  # Seemed like validate was just putting available_routes on "affected_service"
  # so refactored and combined with "routes_with_types"
  def add_routes_with_types(affected_service, available_routes) do
    routes_with_types =
      available_routes
      |> Stream.filter(fn route -> route.id in affected_service["route_ids"] end)
      |> Enum.reduce(%{}, fn route, acc ->
        Map.put(acc, route.id, route.type)
      end)

    Map.put(affected_service, "route_types_by_id", routes_with_types)
  end

  # renamed to make it clear that this is the function that DOES the casting
  def build_changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
  end

  @impl true
  def render(assigns) do
    route_filter_value = assigns.form[:route_ids_filter].value

    route_ids = assigns.form[:route_ids].value || []

    route_id_options =
      SelectFormatter.formatted_select_options(%SelectFormatter{
        options: Map.get(assigns.available_routes, :result, []) || [],
        filter_value: route_filter_value,
        route_type: assigns.route_type,
        values_to_keep: route_ids
      })

    stop_filter_value = assigns.form[:stop_ids_filter].value
    stop_ids = assigns.form[:stop_ids].value || []

    stop_id_options =
      SelectFormatter.formatted_select_options(%SelectFormatter{
        options: Map.get(assigns.available_stops, :result) || [],
        filter_value: stop_filter_value,
        route_type: assigns.route_type,
        values_to_keep: stop_ids
      })

    assigns =
      assign(assigns,
        route_id_options: route_id_options,
        stop_id_options: stop_id_options
      )

    ~H"""
    <div class="min-w-full flex flex-col" id="stop_route_service_view">
      <.h1 class="mb-8">
        Create new {ContentFormatter.route_atom_to_string(@service_type_name)} {@effect_name
        |> String.downcase()} alert
      </.h1>
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Affected service
      </.h5>
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control flex flex-row gap-x-8 mb-4 h-[32rem]"
        id="service_form"
      >
        <.filtered_select
          label="Stops"
          field={@form[:stop_ids]}
          loading={Map.get(@available_stops, :loading, true)}
          no_results={Enum.empty?(@stop_id_options)}
          filter_field={@form[:stop_ids_filter]}
          options={@stop_id_options}
          class="w-[25%]"
        />

        <.filtered_select
          label="Routes"
          field={@form[:route_ids]}
          filter_field={@form[:route_ids_filter]}
          loading={Map.get(@available_routes, :loading, true)}
          no_results={Enum.empty?(@route_id_options) && !disable_routes_input?(assigns)}
          disabled={disable_routes_input?(assigns)}
          options={@route_id_options}
          class="w-[25%]"
        />
      </.form>
      <hr class="mt-4" />
    </div>
    """
  end

  @spec disable_routes_input?(map()) :: boolean()
  defp disable_routes_input?(%{form: form}) do
    form[:stop_ids].value in [nil, []]
  end
end
