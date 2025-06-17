defmodule AlertsUIWeb.FormComponents.StopRouteAffectedService do
  @moduledoc """
    Live Component for affected service section of form with stop-route combination
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertLive

  alias AlertsUIWeb.FormComponents.Helpers.{
    ContentFormatter,
    ErrorFormatter,
    Helpers,
    SelectFormatter
  }

  alias Phoenix.LiveView.AsyncResult

  @primary_key false
  embedded_schema do
    field :route_ids, {:array, :string}
    field :route_search_term, :string
    field :modal_route_id, :string
    field :modal_route_search_term, :string
    field :stop_ids, {:array, :string}
    field :stop_search_term, :string
    field :route_types_by_id, {:map, :integer}
  end

  @fields ~w[route_ids stop_ids route_types_by_id route_search_term stop_search_term modal_route_id modal_route_search_term]a
  @required_fields ~w[route_ids stop_ids]a

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
        available_filter_routes: %{},
        filter_title_value: "All routes",
        selected_route_id: nil
      })

    {:ok, socket}
  end

  # Occurs when alert is being edited
  @impl true
  def update(
        %{alert_data: alert_data, editing: true, route_type: route_type} = assigns,
        socket
      ) do
    changeset = build_changeset(%__MODULE__{}, alert_data)
    changes = apply_action!(changeset, :validate)

    send(self(), {:add_errors, [], __MODULE__})
    send(self(), {:section_completed, changes})

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    socket =
      socket
      |> assign(assigns)
      |> assign(form: form)
      |> assign(route_type: route_type)
      |> assign_stops(route_type)
      |> assign_async([:available_routes, :available_filter_routes], fn ->
        {:ok,
         %{
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

  # The form was submitted but submission had an error, so the same component rerenders
  @impl true
  def update(%{submitted: true}, socket) do
    changeset =
      %__MODULE__{}
      |> build_changeset(socket.assigns.form.params)
      # The only instance where the changeset itself contains the validation, so that
      # inline errors appear after submit
      |> validate_required(@required_fields)

    errors =
      case apply_action(changeset, :validate) do
        {:ok, _changeset} -> []
        {:error, changeset} -> ErrorFormatter.parse_field_errors(changeset)
      end

    form =
      changeset
      |> Map.put(:errors, errors)
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
      |> assign_stops(route_type)
      |> assign_async([:available_filter_routes], fn ->
        {:ok,
         %{
           available_filter_routes: CreateAlertLive.get_routes(route_type)
         }}
      end)

    {:ok, socket}
  end

  defp assign_stops(socket, route_type, route_id \\ nil)

  defp assign_stops(%{assigns: %{available_stops: %{}}} = socket, route_type, route_id) do
    assign_async(socket, :available_stops, fn ->
      route_ids = if route_id, do: List.wrap(route_id), else: nil
      {:ok, %{available_stops: CreateAlertLive.get_stops(route_ids, route_type, nil)}}
    end)
  end

  defp assign_stops(socket, _route_type, _route_id), do: socket

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
    affected_service = add_routes_with_types(affected_service, available_routes(socket))

    changeset = build_changeset(%__MODULE__{}, affected_service)

    validate_changeset(changeset, affected_service, socket.assigns.available_stops)

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
  def handle_event("accepted_routes_modal", _params, socket) do
    route_type = socket.assigns.route_type

    routes =
      if Helpers.async_available?(socket.assigns, :available_filter_routes) do
        socket.assigns.available_filter_routes.result
      else
        []
      end

    selected_route_id = socket.assigns.form.params["modal_route_id"]
    selected_route_id = if selected_route_id in ["", "default"], do: nil, else: selected_route_id

    filter_title_value =
      if is_nil(selected_route_id) do
        "All routes"
      else
        Enum.find(routes, &(&1.id === selected_route_id)).name
      end

    socket =
      socket
      |> assign(
        filter_title_value: filter_title_value,
        selected_route_id: selected_route_id
      )
      |> assign_async(:available_stops, fn ->
        {:ok,
         %{
           available_stops: CreateAlertLive.get_stops([selected_route_id], route_type)
         }}
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancelled_modal", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filter", %{"filter-id" => "routes-filter-modal"}, socket) do
    route_type = socket.assigns.route_type

    affected_service =
      socket.assigns.form.params
      |> Map.merge(%{"modal_route_id" => ""})
      |> add_routes_with_types(available_routes(socket))

    changeset = build_changeset(%__MODULE__{}, affected_service)

    # Don't need to validate because the filter field is not required

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    socket =
      socket
      |> assign(form: form, filter_title_value: "All routes", selected_route_id: nil)
      |> assign_async(:available_stops, fn ->
        {:ok,
         %{
           available_stops: CreateAlertLive.get_stops(nil, route_type)
         }}
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_async(:get_available_routes, {:ok, fetched_routes}, socket) do
    %{available_stops: available_stops, available_routes: available_routes} = socket.assigns

    affected_service =
      socket.assigns.form.params
      |> Map.merge(%{"route_ids" => Enum.map(fetched_routes, & &1.id)})
      |> add_routes_with_types(fetched_routes)

    changeset = build_changeset(%__MODULE__{}, affected_service)
    validate_changeset(changeset, affected_service, available_stops)

    form =
      changeset
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

  def add_routes_with_types(affected_service, available_routes) do
    routes =
      available_routes
      |> Stream.filter(fn route ->
        !is_nil(affected_service["route_ids"]) && route.id in affected_service["route_ids"]
      end)
      |> Enum.reduce(%{}, fn route, acc ->
        Map.put(acc, route.id, route)
      end)

    affected_service
    |> Map.put("routes_by_id", routes)
    |> Map.put("route_types_by_id", routes |> Enum.map(fn {k, v} -> {k, v.type} end) |> Map.new())
  end

  def available_routes(socket), do: Map.get(socket.assigns.available_routes, :result, [])

  def build_changeset(changeset, params), do: cast(changeset, params, @fields)

  def validate_changeset(changeset, affected_service, available_stops) do
    case apply_action(changeset |> validate_required(@required_fields), :validate) do
      {:ok, changeset} ->
        available_stops =
          Map.get(available_stops, :result)

        selected_stops =
          if available_stops do
            available_stops
            |> Enum.filter(&(&1.id in affected_service["stop_ids"]))
          else
            nil
          end

        #########

        available_routes =
          Map.get(affected_service, "routes_by_id")

        selected_routes =
          if available_routes do
            available_routes
            |> Enum.reduce([], fn {route_id, route}, acc ->
              if route_id in affected_service["route_ids"] do
                acc ++ List.wrap(route)
              else
                acc
              end
            end)
            |> List.flatten()
          else
            nil
          end

        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changeset})
        send(self(), {:selected_routes, selected_routes})
        send(self(), {:selected_stops, selected_stops})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
    end
  end

  @impl true
  def render(assigns) do
    # Route filter
    modal_route_search_term = assigns.form[:modal_route_search_term].value
    modal_route_id = assigns.form[:modal_route_id].value || ""

    modal_route_id_options =
      SelectFormatter.formatted_select_options(%SelectFormatter{
        options: Map.get(assigns.available_filter_routes, :result) || [],
        search_term: modal_route_search_term,
        route_type: assigns.route_type,
        values_to_keep: modal_route_id |> List.wrap()
      })

    # Stop selector
    stop_search_term = assigns.form[:stop_search_term].value
    stop_ids = assigns.form[:stop_ids].value || []

    stop_id_options =
      if Helpers.async_available?(assigns, :available_stops) do
        options = assigns.available_stops.result

        SelectFormatter.formatted_select_options(%SelectFormatter{
          options: options,
          search_term: stop_search_term,
          route_type: assigns.route_type,
          values_to_keep: stop_ids
        })
        |> Enum.map(fn {name, id} -> {String.slice(name, 0..80), id} end)
      else
        []
      end

    # Impacted routes selector
    route_search_term = assigns.form[:route_search_term].value
    route_ids = assigns.form[:route_ids].value || []

    route_id_options =
      SelectFormatter.formatted_select_options(%SelectFormatter{
        options: Map.get(assigns.available_routes, :result, []) || [],
        search_term: route_search_term,
        route_type: assigns.route_type,
        values_to_keep: route_ids
      })

    assigns =
      assign(assigns,
        route_id_options: route_id_options,
        stop_id_options: stop_id_options,
        modal_route_id_options: modal_route_id_options
      )

    ~H"""
    <div class="min-w-full flex flex-col" id="stop_route_service_view">
      <.h1 class="!mb-0">Create new alert</.h1>
      <.p>
        {ContentFormatter.service_type_string(@route_type)} • {@effect_name}
      </.p>
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
            filter_field={@form[:modal_route_search_term]}
            options={@modal_route_id_options}
            loading={@available_filter_routes.loading}
            no_results={Enum.empty?(@modal_route_id_options)}
            class="h-[32rem]"
            prompt="All routes"
            multiple={false}
          />
        </.modal>

        <.filtered_select
          label="Stops"
          field={@form[:stop_ids]}
          loading={Map.get(@available_stops, :loading, true)}
          no_results={Enum.empty?(@stop_id_options)}
          filter_field={@form[:stop_search_term]}
          modal_filter_id="routes-filter-modal"
          modal_filter_title={"Filter: #{@filter_title_value}"}
          modal_filter_active={@selected_route_id}
          options={@stop_id_options}
          class="w-[25%]"
          target_id="#service_form"
        />

        <.filtered_select
          label="Impacted routes"
          field={@form[:route_ids]}
          filter_field={@form[:routes_search_term]}
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
