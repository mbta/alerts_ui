defmodule AlertsUIWeb.FormComponents.StopRouteAffectedService do
  @moduledoc """
    Live Component for affected service section of form with stop-route combination
  """
  alias AlertsUIWeb.FormComponents.AffectedService
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertLive

  alias AlertsUIWeb.FormComponents.Helpers.{
    ContentFormatter,
    EntityValidator,
    ErrorFormatter,
    Helpers,
    ObsoleteEntities,
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
    field :stop_names_and_ids, {:array, :string}
    field :stop_search_term, :string
  end

  @fields ~w[route_ids stop_ids stop_names_and_ids route_search_term stop_search_term modal_route_id modal_route_search_term]a
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
        available_routes: AsyncResult.loading(),
        available_stops: AsyncResult.loading(),
        selected_stops: [],
        available_filter_routes: %{},
        filter_title_value: "All routes",
        selected_route_id: nil,
        obsolete_ids: %{}
      })

    {:ok, socket}
  end

  # Occurs when alert is being edited
  @impl true
  def update(
        %{alert_data: alert_data, form_type: form_type, route_type: route_type} = assigns,
        socket
      )
      when form_type in [:editing, :duplicating] do
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
      |> start_async(:available_routes, fn ->
        CreateAlertLive.get_routes_by_stop(
          Map.get(alert_data, :stop_ids, []),
          route_type
        )
      end)
      |> assign_async(:available_filter_routes, fn ->
        {:ok,
         %{
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

  defp assign_stops(
         %{assigns: %{available_stops: %AsyncResult{loading: true}}} = socket,
         route_type,
         route_id
       ) do
    start_async(socket, :available_stops, fn ->
      route_ids = if route_id, do: List.wrap(route_id), else: nil
      CreateAlertLive.get_stops_for_stop_route(route_ids, route_type)
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
    # Get the currently selected stop ids
    stop_ids =
      affected_service["stop_ids"] || []

    # Then get the full stop data. That could be in available_stops OR be previously saved in selected_stops
    # (in the case that the list has been filtered, the stop details won't be in available_stops)
    selected_stops =
      Enum.filter(
        socket.assigns.available_stops.result ++ socket.assigns.selected_stops,
        fn stop -> stop.id in stop_ids end
      )
      |> Enum.uniq_by(& &1.id)

    # Generate stop_names_and_ids
    stop_names_and_ids =
      selected_stops
      |> Enum.map(&"#{&1.name}|#{&1.id}")

    affected_service =
      affected_service
      |> Map.merge(%{"stop_names_and_ids" => stop_names_and_ids})

    changeset = build_changeset(%__MODULE__{}, affected_service)

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    route_type = socket.assigns.route_type

    socket =
      socket
      |> assign(:selected_stops, selected_stops)
      |> assign(:available_routes, AsyncResult.loading())
      |> start_async(:get_available_routes_on_validate, fn ->
        CreateAlertLive.get_routes_by_stop(stop_ids, route_type)
      end)
      |> assign(form: form)

    {:noreply, socket}
  end

  # On route select, don't need to do anything but save the change
  @impl true
  def handle_event("validate", %{"stop_route_affected_service" => affected_service}, socket) do
    # Get the currently selected stop ids
    stop_ids = Map.get(affected_service, "stop_ids", [])

    # Then get the full stop data. That could be in available_stops OR be previously saved in selected_stops
    # (in the case that the list has been filtered, the stop details won't be in available_stops)
    selected_stops =
      (socket.assigns.available_stops.result || []) ++ (socket.assigns.selected_stops || [])

    selected_stops =
      selected_stops
      |> Enum.filter(&(Map.get(&1, :id, nil) in stop_ids))

    # Generate stop_names_and_ids
    stop_names_and_ids =
      selected_stops
      |> Enum.map(&"#{&1.name}|#{&1.id}")

    affected_service =
      affected_service
      |> Map.merge(%{"stop_names_and_ids" => stop_names_and_ids})
      |> add_routes_with_types(available_routes(socket))

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
  def handle_event("reset_search_filter", %{"name" => name}, socket) do
    # The name will come back as i.e. "affected_service[route_search_term]" but we only want "route_search_term"
    search_filter_name = hd(Regex.run(~r/\[(.*?)\]/, name, capture: :all_but_first))

    affected_service =
      socket.assigns.form.params
      |> Map.merge(%{search_filter_name => ""})

    changeset = build_changeset(%__MODULE__{}, affected_service)

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    socket =
      socket
      |> assign(form: form)

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
           available_stops:
             CreateAlertLive.get_stops_for_stop_route([selected_route_id], route_type)
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
           available_stops: CreateAlertLive.get_stops_for_stop_route(nil, route_type)
         }}
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_async(:get_available_routes_on_validate, {:ok, fetched_routes}, socket) do
    %{available_stops: available_stops, available_routes: available_routes} = socket.assigns
    # called when a stop is selected

    affected_service =
      socket.assigns.form.params
      |> Map.merge(%{"route_ids" => fetched_routes |> Enum.uniq() |> Enum.map(& &1.id)})
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
  def handle_async(async_key, {:ok, result}, %{assigns: %{form_type: :creating}} = socket) do
    # called on initial form entry when creating
    socket = assign(socket, async_key, AsyncResult.ok(socket.assigns[async_key], result))
    {:noreply, socket}
  end

  @impl true
  def handle_async(async_key, {:ok, result}, socket) do
    # called on initial form entry when editing/duplicating and checks for invalid stops/routes

    # assign result to socket first
    socket = assign(socket, async_key, AsyncResult.ok(socket.assigns[async_key], result))

    mapping = %{
      available_routes: :route_ids,
      available_stops: :stop_ids
    }

    obsolete_ids_for_field =
      EntityValidator.get_obsolete_ids(
        socket.assigns.alert_data[mapping[async_key]],
        socket.assigns[async_key]
      )

    obsolete_ids =
      socket.assigns.obsolete_ids |> Map.put_new(mapping[async_key], obsolete_ids_for_field)

    # check that we got results and contains all required field

    send_obsolete_ids? = ObsoleteEntities.send_obsolete_ids?(obsolete_ids, @required_fields)

    # if all our fields have been returned and there are obsolete ids
    # send result to parent
    previous_assigns = Enum.sort(Map.keys(socket.assigns.obsolete_ids))

    if send_obsolete_ids? && previous_assigns !== @required_fields do
      alert_data = socket.assigns.alert_data

      ids_with_obsolete_entities_removed =
        ObsoleteEntities.ids_with_obsolete_entities_removed(
          alert_data,
          obsolete_ids,
          @required_fields
        )

      new_alert_data = Map.merge(alert_data, ids_with_obsolete_entities_removed)

      changeset =
        %__MODULE__{}
        |> build_changeset(new_alert_data)
        |> validate_required(@required_fields)

      case changeset |> apply_action(:validate) do
        {:ok, _changeset} ->
          send(self(), {:section_completed, changeset})

        {:error, changeset} ->
          send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
      end

      send(self(), {:got_obsolete_ids, obsolete_ids})
    end

    {:noreply, assign(socket, :obsolete_ids, obsolete_ids)}
  end

  @impl true
  def handle_async(async_key, {:exit, reason}, socket) do
    {:noreply,
     assign(socket, async_key, AsyncResult.failed(socket.assigns[async_key], {:exit, reason}))}
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

    Map.put(affected_service, "routes_by_id", routes)
  end

  def available_routes(socket), do: Map.get(socket.assigns.available_routes, :result, []) || []

  def build_changeset(changeset, params), do: cast(changeset, params, @fields)

  def validate_changeset(changeset, affected_service, available_stops) do
    case apply_action(changeset |> validate_required(@required_fields), :validate) do
      {:ok, changeset} ->
        # stops and routes here are used in autotext
        available_stops = Map.get(available_stops, :result)
        selected_stops = get_selected_stops(available_stops, affected_service["stop_ids"])
        available_routes = Map.get(affected_service, "routes_by_id")
        selected_routes = get_selected_routes(available_routes, affected_service["route_ids"])

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
        values_to_keep: modal_route_id |> List.wrap(),
        option_prefix: "route-filter"
      })

    # Stop selector
    stop_search_term = assigns.form[:stop_search_term].value
    stop_ids = assigns.form[:stop_ids].value || []

    # Yeah this is weird. Basically, available_stops might be filtered down by route and sorted by stop order,
    # so we have to carefully preserve already selected stops.
    stop_id_options =
      if Helpers.async_available?(assigns, :available_stops) do
        # Available stops will only include the stops visible with the given route filter
        available_stops = assigns.available_stops.result

        # And now just a list of stop ids
        available_stop_ids = Enum.map(available_stops, fn stop -> stop.id end)

        # Get all the stops that were selected but are no longer included in `available_stops`
        # Then append them to the top of the list
        previously_selected_stops =
          Enum.filter(assigns.selected_stops, fn stop -> stop.id not in available_stop_ids end)

        options = previously_selected_stops ++ available_stops

        SelectFormatter.formatted_select_options(%SelectFormatter{
          options: options,
          search_term: stop_search_term,
          route_type: assigns.route_type,
          values_to_keep: stop_ids,
          option_prefix: "stop-selector"
        })
      else
        []
      end

    stop_selections = AffectedService.extract_selections(assigns.form, stop_id_options)

    # Impacted routes selector
    route_search_term = assigns.form[:route_search_term].value
    route_ids = assigns.form[:route_ids].value || []

    route_id_options =
      SelectFormatter.formatted_select_options(%SelectFormatter{
        options: Map.get(assigns.available_routes, :result, []) || [],
        search_term: route_search_term,
        route_type: assigns.route_type,
        values_to_keep: route_ids,
        option_prefix: "route-selector"
      })

    assigns =
      assign(assigns,
        route_id_options: route_id_options,
        stop_id_options: stop_id_options,
        modal_route_id_options: modal_route_id_options,
        stop_selections: stop_selections
      )

    ~H"""
    <div class="min-w-full flex flex-col" id="stop_route_service_view">
      <.h1>
        {ContentFormatter.service_type_string(@route_type)} • {@effect_name}
      </.h1>
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Affected service
      </.h5>
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control md:flex md:flex-row gap-x-8 mb-4 h-[32rem]"
        id="service_form"
      >
        <.modal
          id="routes-filter-modal"
          header_text="Filter by route"
          cancel_event_name="cancelled_modal"
          accept_event_name="accepted_routes_modal"
          accept_button_text="Apply"
          target_id="#service_form"
          container_class="md:!w-[25rem]"
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
            target_id={@myself}
          />
        </.modal>

        <.filtered_select
          class="md:w-[25%]"
          field={@form[:stop_ids]}
          filter_field={@form[:stop_search_term]}
          selected={@stop_selections}
          label="Stops"
          loading={Map.get(@available_stops, :loading, true)}
          modal_filter_active={@selected_route_id}
          modal_filter_id="routes-filter-modal"
          modal_filter_title={"Filter: #{@filter_title_value}"}
          no_results={Enum.empty?(@stop_id_options)}
          options={@stop_id_options}
          target_id={@myself}
        />

        <.filtered_select
          label="Impacted routes"
          field={@form[:route_ids]}
          filter_field={@form[:route_search_term]}
          loading={Map.get(@available_routes, :loading, true)}
          no_results={Enum.empty?(@route_id_options) && !disable_routes_input?(assigns)}
          disabled={disable_routes_input?(assigns)}
          options={@route_id_options}
          class="md:w-[25%]"
        />
      </.form>
      <p :if={@show_stop_ids}>
        Selected stop ids: {(@form[:stop_ids].value || []) |> Enum.join(", ")}
      </p>
      <hr class="mt-4" />
    </div>
    """
  end

  @spec disable_routes_input?(map()) :: boolean()
  defp disable_routes_input?(%{form: form}) do
    form[:stop_ids].value in [nil, []]
  end

  defp get_selected_stops(nil, _), do: nil
  defp get_selected_stops(_, nil), do: nil

  defp get_selected_stops(available_stops, stop_ids) do
    Enum.filter(available_stops, &(&1.id in stop_ids))
  end

  defp get_selected_routes(nil, _), do: nil
  defp get_selected_routes(_, nil), do: nil

  defp get_selected_routes(available_routes, route_ids) do
    available_routes
    |> Enum.reduce([], fn {route_id, route}, acc ->
      if route_id in route_ids do
        acc ++ List.wrap(route)
      else
        acc
      end
    end)
    |> List.flatten()
  end
end
