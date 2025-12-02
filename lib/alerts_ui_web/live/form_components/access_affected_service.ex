defmodule AlertsUIWeb.FormComponents.AccessAffectedService do
  @moduledoc """
    Live Component for access affected service section
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema

  require Logger

  import Ecto.Changeset

  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertLive
  alias AlertsUIWeb.FormComponents.Helpers.{ErrorFormatter, Helpers, SelectFormatter}

  @primary_key false
  embedded_schema do
    field :stop_id, :string
    field :stop_search_term, :binary
    field :facility_types, {:array, :string}
    field :facility_types_filter, :string
    field :facility_id, :string
    field :facility_search_term, :string
  end

  @fields ~w[stop_id stop_search_term facility_types facility_types_filter facility_id facility_search_term]a
  @required_fields ~w[facility_id]a

  @impl true
  def mount(socket) do
    changeset = build_changeset(%__MODULE__{}, %{})

    {:ok,
     assign(socket, %{
       form: to_form(changeset),
       facility_types: [],
       available_facilities: %{},
       stop_id_filter_value: "default",
       filter_title_value: "All stops",
       alert_data: %{
         facility_id: ""
       }
     })}
  end

  @impl true
  def update(%{alert_data: alert_data, form_type: form_type} = assigns, socket)
      when form_type in [:editing, :duplicating] do
    effect_name = Map.get(alert_data, :effect_name) || socket.assigns.effect_name

    facility_types =
      effect_name
      |> string_to_formatted_atom
      |> InformedEntity.facility_effect_to_types()

    send(self(), {:add_errors, [], __MODULE__})

    alert_data =
      if is_struct(alert_data) do
        Map.from_struct(alert_data)
      else
        alert_data
      end
      |> Map.put_new(:facility_id, "")

    form =
      %__MODULE__{}
      |> build_changeset(alert_data)
      |> to_form()

    socket =
      socket
      |> assign(assigns)
      |> assign(
        form: form,
        alert_data: alert_data,
        facility_types: facility_types,
        effect_name: effect_name
      )
      |> assign_facilities(facility_types)

    {:ok, socket}
  end

  @impl true
  def update(%{submitted: true}, socket) do
    changeset =
      %__MODULE__{}
      |> build_changeset(socket.assigns.form.params)
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
  def update(%{alert_data: alert_data} = assigns, socket) do
    effect_name = Map.get(alert_data, :effect_name) || socket.assigns.effect_name

    facility_types =
      effect_name
      |> string_to_formatted_atom
      |> InformedEntity.facility_effect_to_types()

    socket =
      socket
      |> assign(assigns)
      |> assign(effect_name: effect_name, facility_types: facility_types)
      |> assign_facilities(facility_types)

    {:ok, socket}
  end

  # Only assign facilities if that map is empty! Otherwise, we've already assigned them
  defp assign_facilities(
         %{assigns: %{available_facilities: available_facilities}} = socket,
         facility_types
       )
       when available_facilities == %{} do
    assign_async(socket, :available_facilities, fn ->
      {:ok, %{available_facilities: CreateAlertLive.get_facilities(facility_types)}}
    end)
  end

  defp assign_facilities(socket, _facility_types), do: socket

  @impl true
  def handle_event(
        "validate",
        %{"access_affected_service" => access_affected_service},
        socket
      ) do
    changeset = build_changeset(%__MODULE__{}, access_affected_service)

    case apply_action(changeset |> validate_required(@required_fields), :validate) do
      {:ok, changeset} ->
        %{facilities: available_facilities} =
          Map.get(socket.assigns.available_facilities, :result, %{facilities: []}) ||
            %{facilities: []}

        selected_facility =
          Enum.find(available_facilities, &(&1.id == access_affected_service["facility_id"]))

        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changeset})
        send(self(), {:selected_facility, selected_facility})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
        send(self(), {:section_completed, changeset})
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
  def handle_event("accepted_stops_modal", _params, socket) do
    stops =
      if Helpers.async_available?(socket.assigns, :available_facilities) do
        socket.assigns.available_facilities.result.stops
      else
        []
      end

    selected_stop_id = socket.assigns.form.params["stop_id"]

    filter_title_value =
      if selected_stop_id in [nil, "", "default"] or Enum.empty?(stops) do
        "All stops"
      else
        Enum.filter(stops, &(&1.id === selected_stop_id)) |> Enum.map(& &1.name) |> hd
      end

    {:noreply,
     assign(socket,
       stop_id_filter_value: selected_stop_id,
       filter_title_value: filter_title_value
     )}
  end

  @impl true
  def handle_event("cancelled_modal", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filter", %{"filter-id" => "stops-filter-modal"}, socket) do
    access_affected_service =
      socket.assigns.form.params
      |> Map.merge(%{"stop_id" => ""})

    changeset = build_changeset(%__MODULE__{}, access_affected_service)

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     assign(socket, form: form, stop_id_filter_value: "default", filter_title_value: "All stops")}
  end

  def build_changeset(changeset, params), do: cast(changeset, params, @fields)

  @impl true
  def render(assigns) do
    # Stop filter
    stop_search_term = assigns.form[:stop_search_term].value
    stop_id = assigns.form[:stop_id].value || ""

    stops = Map.get(assigns.available_facilities, :result) || %{}

    modal_stop_id_options =
      SelectFormatter.formatted_select_options(%SelectFormatter{
        options: Map.get(stops, :stops) || [],
        search_term: stop_search_term,
        values_to_keep: stop_id |> List.wrap()
      })

    # Facility selector
    facility_search_term = assigns.form[:facility_search_term].value
    facility_id = assigns.form[:facility_id].value || ""

    facility_id_options =
      if Helpers.async_available?(assigns, :available_facilities) do
        options =
          assigns.available_facilities.result.facilities
          |> Enum.filter(
            &filter_facility_by_stop_ids(
              &1,
              assigns.stop_id_filter_value,
              facility_id
            )
          )

        SelectFormatter.formatted_select_options(%SelectFormatter{
          options: options,
          search_term: facility_search_term,
          values_to_keep: List.wrap(facility_id)
        })
      else
        []
      end

    assigns =
      assign(assigns,
        modal_stop_id_options: modal_stop_id_options,
        facility_id_options: facility_id_options
      )

    ~H"""
    <div class="min-w-full flex flex-col" id="access_service_view">
      <.h1>Facility • {@effect_name}</.h1>
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Affected service
      </.h5>
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control"
        id="service_form"
      >
        <fieldset class="flex flex-row">
          <.modal
            id="stops-filter-modal"
            header_text="Filter by stop"
            cancel_event_name="cancelled_modal"
            accept_event_name="accepted_stops_modal"
            accept_button_text="Apply"
            target_id="#service_form"
          >
            <.filtered_select
              label="Stops"
              field={@form[:stop_id]}
              filter_field={@form[:stop_search_term]}
              options={@modal_stop_id_options}
              loading={@available_facilities.loading}
              no_results={Enum.empty?(@modal_stop_id_options)}
              prompt="All Stops"
              multiple={false}
              class="h-[32rem]"
            />
          </.modal>
          <.filtered_select
            class="w-[25%] h-[32rem]"
            field={@form[:facility_id]}
            filter_field={@form[:facility_search_term]}
            label="Facilities"
            loading={Map.get(@available_facilities, :loading, true)}
            modal_filter_active={filter_active?(@stop_id_filter_value)}
            modal_filter_id="stops-filter-modal"
            modal_filter_title={"Filter: #{@filter_title_value}"}
            multiple={false}
            no_results={Enum.empty?(@facility_id_options)}
            options={@facility_id_options}
            target_id="#service_form"
          />
        </fieldset>
      </.form>
      <hr class="mt-8" />
    </div>
    """
  end

  defp filter_active?(filter_value) when filter_value in ["", nil, "default"], do: false
  defp filter_active?(_), do: true

  defp filter_facility_by_stop_ids(facility, stop_id_filter_value, selected_facility_id) do
    # returns true if facility in list if it belongs to a selected stop or has already been selected by the user.
    equals_stop_id =
      if stop_id_filter_value === "default" do
        true
      else
        facility.stop.id === stop_id_filter_value
      end

    equals_stop_id or facility.id == selected_facility_id
  end

  defp string_to_formatted_atom(string) do
    string
    |> String.upcase()
    |> String.replace(" ", "_")
    |> String.to_existing_atom()
  end
end
