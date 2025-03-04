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
  alias AlertsUIWeb.FormComponents.Helpers.{ErrorFormatter, SelectFormatter}

  @primary_key false
  embedded_schema do
    field :stop_id, :string
    field :stop_id_filter, :binary
    field :facility_types, {:array, :string}
    field :facility_types_filter, :string
    field :facility_id, :string
    field :facility_id_filter, :string
  end

  @fields ~w[stop_id stop_id_filter facility_types facility_types_filter facility_id facility_id_filter]a
  @required_fields ~w[facility_id]a

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
  def update(%{alert_data: alert_data, editing: true} = assigns, socket) do
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
      |> changeset(alert_data)
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
      |> assign_async([:available_facilities], fn ->
        {:ok, %{available_facilities: CreateAlertLive.get_facilities(facility_types)}}
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
      |> assign_async([:available_facilities], fn ->
        {:ok, %{available_facilities: CreateAlertLive.get_facilities(facility_types)}}
      end)

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "validate",
        %{"access_affected_service" => access_affected_service},
        socket
      ) do
    changeset = changeset(%__MODULE__{}, access_affected_service)

    case apply_action(changeset |> validate_required(@required_fields), :validate) do
      {:ok, changeset} ->
        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changeset})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
        send(self(), {:section_completed, changeset})
    end

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, %{form: form})}
  end

  @impl true
  def handle_event("accepted_stops_modal", _params, socket) do
    stops =
      if async_available?(socket.assigns, :available_facilities) do
        socket.assigns.available_facilities.result.stops
      else
        []
      end

    selected_stop_id = socket.assigns.form.params["stop_id"]

    filter_title_value =
      if selected_stop_id in [nil, "", "default"] do
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

  def changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
  end

  @impl true
  def render(assigns) do
    params = assigns.form.params

    stops =
      if async_available?(assigns, :available_facilities) do
        assigns.available_facilities.result.stops
      else
        []
      end

    stop_filter_value = assigns.form[:stop_id_filter].value

    stop_id = assigns.form[:stop_id].value || ""

    stop_id_options =
      SelectFormatter.formatted_select_options(%SelectFormatter{
        options: stops,
        filter_value: stop_filter_value,
        values_to_keep: stop_id |> List.wrap()
      })

    facility_filter_value = assigns.form[:facility_id_filter].value
    facility_id = assigns.form[:facility_id].value || ""

    facility_id_options =
      if async_available?(assigns, :available_facilities) do
        options =
          assigns.available_facilities.result.facilities
          |> Enum.filter(
            &filter_facility_by_stop_ids(
              &1,
              assigns.stop_id_filter_value,
              params["facility_id"]
            )
          )

        SelectFormatter.formatted_select_options(%SelectFormatter{
          options: options,
          filter_value: facility_filter_value,
          values_to_keep: List.wrap(facility_id)
        })
        |> Enum.map(fn {name, id} -> {String.slice(name, 0..80), id} end)
      else
        []
      end

    assigns =
      assign(assigns,
        stop_id_options: stop_id_options,
        facility_id_options: facility_id_options
      )

    ~H"""
    <div class="min-w-full flex flex-col" id="access_service_view">
      <.h1 class="mb-8">Create new access {@effect_name |> String.downcase()} alert</.h1>
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
              filter_field={@form[:stop_id_filter]}
              options={@stop_id_options}
              loading={@available_facilities.loading}
              no_results={Enum.empty?(@stop_id_options)}
              prompt="All Stops"
              multiple={false}
            />
          </.modal>
          <.filtered_select
            label="Facilities"
            field={@form[:facility_id]}
            filter_field={@form[:facility_id_filter]}
            modal_filter_id="stops-filter-modal"
            modal_filter_title={"Filter: #{@filter_title_value}"}
            options={@facility_id_options}
            loading={@available_facilities.loading}
            no_results={Enum.empty?(@facility_id_options)}
            class="w-[25%]"
            multiple={false}
          />
        </fieldset>
      </.form>
      <hr class="mt-8" />
    </div>
    """
  end

  defp async_available?(assigns, key) do
    Map.get(assigns[key], :result) && assigns[key].ok? &&
      assigns[key].result
  end

  defp filter_facility_by_stop_ids(facility, stop_id_filter_value, facility_id) do
    # returns true if facility in list if it belongs to a selected stop or has already been selected by the user.
    equals_stop_id =
      if stop_id_filter_value === "default" do
        true
      else
        facility.stop.id === stop_id_filter_value
      end

    equals_stop_id or facility.id == facility_id
  end

  defp string_to_formatted_atom(string) do
    string
    |> String.upcase()
    |> String.replace(" ", "_")
    |> String.to_existing_atom()
  end
end
