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

  @primary_key false
  embedded_schema do
    field :route_ids, {:array, :string}
    field :route_ids_filter, :string
    field :modal_route_id, :string
    field :modal_route_id_filter, :string
    field :stop_ids, {:array, :string}
    field :stop_ids_filter, :string
    field :route_types_by_id, {:map, :integer}
  end

  @fields ~w[route_ids stop_ids route_types_by_id route_ids_filter stop_ids_filter modal_route_id modal_route_id_filter]a
  @required_fields ~w[route_ids stop_ids]a

  @impl true
  def mount(socket) do
    changeset = changeset(%__MODULE__{}, %{})

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
        available_filter_routes: %{},
        edited: false,
        filter_title_value: "All routes",
        stop_id_filter_value: []
      })

    {:ok, socket}
  end

  @impl true
  def update(
        %{alert_data: alert_data, editing: true, route_type: route_type} = assigns,
        socket
      ) do
    changeset =
      %__MODULE__{}
      |> changeset(alert_data)

    changes =
      changeset
      |> apply_action!(:validate)

    send(self(), {:add_errors, [], __MODULE__})
    send(self(), {:section_completed, changes})

    form = to_form(changeset |> Map.put(:action, :validate))

    assigns =
      assigns
      |> Map.put(
        :service_type_name,
        route_type |> InformedEntity.route_code_mapping() || nil
      )
      |> Map.put(:form, form)
      |> Map.put(:route_type, route_type)

    socket =
      socket
      |> assign(assigns)
      |> assign_async([:available_stops, :available_routes, :available_filter_routes], fn ->
        {:ok,
         %{
           available_stops: CreateAlertLive.get_stops_by_route_type(route_type),
           available_routes:
             CreateAlertLive.get_routes_by_stop(
               Map.get(alert_data, :stop_ids, []),
               route_type
             ),
           available_filter_routes: CreateAlertLive.get_routes(route_type)
         }}
      end)

    {:ok, socket}
  end

  @impl true
  def update(%{submitted: true}, socket) do
    changeset =
      %__MODULE__{}
      |> changeset(socket.assigns.form.params)
      |> validate_required(@required_fields)

    errors =
      case changeset |> apply_action(:validate) do
        {:ok, _changeset} -> []
        {:error, changeset} -> ErrorFormatter.parse_field_errors(changeset)
      end

    form =
      changeset
      |> to_form()
      |> Map.put(:errors, errors)
      |> Map.put(:action, :validate)

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
      |> assign_async([:available_stops, :available_filter_routes], fn ->
        {:ok,
         %{
           available_stops: CreateAlertLive.get_stops_by_route_type(route_type),
           available_filter_routes: CreateAlertLive.get_routes(route_type)
         }}
      end)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"stop_route_affected_service" => affected_service}, socket) do
    affected_service = populate_default_routes(affected_service)
    changeset = validate(affected_service, socket.assigns)

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

    route_type = socket.assigns.route_type

    socket =
      socket
      |> assign(%{form: form})
      |> assign_async([:available_routes], fn ->
        {:ok,
         %{
           available_routes:
             CreateAlertLive.get_routes_by_stop(
               Map.get(affected_service, "stop_ids", []),
               route_type
             )
         }}
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("accepted_routes_modal", _params, socket) do
    routes =
      if async_available?(socket.assigns, :available_filter_routes) do
        socket.assigns.available_filter_routes.result
      else
        []
      end

    selected_route_id = socket.assigns.form.params["modal_route_id"]

    filter_title_value =
      if selected_route_id in [nil, "", "default"] do
        "All routes"
      else
        Enum.filter(routes, &(&1.id === selected_route_id)) |> Enum.map(& &1.name) |> hd
      end

    stop_id_filter_value =
      CreateAlertLive.get_stops(
        [selected_route_id],
        "default"
      )
      |> Enum.map(& &1.id)

    {:noreply,
     assign(socket,
       stop_id_filter_value: stop_id_filter_value,
       filter_title_value: filter_title_value
     )}
  end

  @impl true
  def handle_event("cancelled_modal", _params, socket) do
    {:noreply, socket}
  end

  def validate(affected_service, assigns) do
    routes_with_types =
      routes_with_types(
        Map.get(assigns.available_routes, :result) || [],
        affected_service["route_ids"]
      )

    affected_service = Map.put(affected_service, "route_types_by_id", routes_with_types)

    %__MODULE__{}
    |> changeset(affected_service)
  end

  def changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
  end

  def routes_with_types(available_routes, route_ids) do
    available_routes
    |> Stream.filter(fn route -> route.id in route_ids end)
    |> Enum.reduce(%{}, fn route, acc ->
      Map.put(acc, route.id, route.type)
    end)
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

    # options = (Map.get(assigns.available_stops, :result) || []) |> filter_stops_by_stop_ids(stop, stop_id_filter_value, selected_stop_id)
    # stop_id_options =
    #   SelectFormatter.formatted_select_options(%SelectFormatter{
    #     options: options,
    #     filter_value: stop_filter_value,
    #     route_type: assigns.route_type,
    #     values_to_keep: stop_ids
    #   })

    stop_id_options =
      if async_available?(assigns, :available_stops) do
        options =
          assigns.available_stops.result
          |> Enum.filter(
            &filter_stops_by_stop_ids(
              &1,
              assigns.stop_id_filter_value,
              assigns.form.params["stop_ids"]
            )
          )

        SelectFormatter.formatted_select_options(%SelectFormatter{
          options: options,
          filter_value: stop_filter_value,
          route_type: assigns.route_type,
          values_to_keep: stop_ids
        })
        |> Enum.map(fn {name, id} -> {String.slice(name, 0..80), id} end)
      else
        []
      end

    modal_route_id = assigns.form[:modal_route_id].value || ""

    modal_route_id_options =
      SelectFormatter.formatted_select_options(%SelectFormatter{
        options: Map.get(assigns.available_filter_routes, :result) || [],
        filter_value: assigns.form[:modal_route_id_filter].value,
        route_type: assigns.route_type,
        values_to_keep: modal_route_id |> List.wrap()
      })

    assigns =
      assign(assigns,
        route_id_options: route_id_options,
        stop_id_options: stop_id_options,
        modal_route_id_options: modal_route_id_options
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
        <.modal
          id="routes-filter-modal"
          header_text="Filter by route"
          cancel_event_name="cancelled_modal"
          accept_event_name="accepted_routes_modal"
          accept_button_text="Apply"
          target_id="#service_form"
        >
          <.filtered_select
            label="Routes"
            field={@form[:modal_route_id]}
            filter_field={@form[:modal_route_id_filter]}
            options={@modal_route_id_options}
            loading={@available_filter_routes.loading}
            no_results={Enum.empty?(@modal_route_id_options)}
            class="min-h-[90%] h-[30rem]"
            select_class="h-[30rem]"
            prompt="All routes"
            multiple={false}
          />
        </.modal>

        <.filtered_select
          label="Stops"
          field={@form[:stop_ids]}
          loading={Map.get(@available_stops, :loading, true)}
          no_results={Enum.empty?(@stop_id_options)}
          filter_field={@form[:stop_ids_filter]}
          modal_filter_id="routes-filter-modal"
          modal_filter_title={"Filter: #{@filter_title_value}"}
          options={@stop_id_options}
          class="w-[25%]"
        />

        <.filtered_select
          label="Impacted routes"
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

  @spec populate_default_routes(map()) :: map()
  defp populate_default_routes(affected_service) do
    if affected_service |> Map.get("route_ids") |> is_nil do
      Map.put(affected_service, "route_ids", [])
    else
      affected_service
    end
  end

  defp async_available?(assigns, key) do
    Map.get(assigns, key) && Map.get(assigns[key], :result) && assigns[key].ok? &&
      assigns[key].result
  end

  defp filter_stops_by_stop_ids(stop, stop_id_filter_value, selected_stop_ids) do
    # returns true if stop in list is in list from modal filter or has already been selected by the user.
    equals_stop_id =
      if stop_id_filter_value === [] do
        true
      else
        stop.id in stop_id_filter_value
      end

    equals_stop_id or stop.id in selected_stop_ids
  end
end
