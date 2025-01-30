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
    field :stop_ids, {:array, :string}
    field :stop_ids_filter, :binary
    field :facility_types, {:array, :string}
    field :facility_types_filter, :string
    field :facility_id, :string
    field :facility_id_filter, :string
  end

  @fields ~w[stop_ids stop_ids_filter facility_types facility_types_filter facility_id facility_id_filter]a
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
       edited: false,
       alert_data: %{
         facility_id: ""
       }
     })}
  end

  @impl true
  def update(%{alert_data: alert_data, editing: editing} = assigns, socket) do
    effect_name = Map.get(alert_data, :effect_name) || socket.assigns.effect_name

    facility_types =
      effect_name
      |> string_to_formatted_atom
      |> InformedEntity.facility_effect_to_types()

    assigns =
      if editing == true and socket.assigns.edited == false do
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

        Map.merge(assigns, %{
          form: form,
          alert_data: alert_data,
          facility_types: facility_types,
          edited: true
        })
      else
        assigns
      end
      |> Map.merge(%{effect_name: effect_name, facility_types: facility_types})

    socket =
      socket
      |> assign(assigns)
      |> assign_async([:available_facilities], fn ->
        {:ok, %{available_facilities: CreateAlertLive.get_facilities(facility_types)}}
      end)

    {:ok, socket}
  end

  @impl true
  def update(%{submitted: submitted}, socket) do
    socket =
      if submitted do
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

        assign(socket, form: form)
      else
        socket
      end

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
        |> Enum.filter(&filter_stop_by_types(&1, params))
      else
        []
      end

    type_filter_value = assigns.form[:facility_types_filter].value

    facility_type_options =
      assigns.facility_types
      |> Enum.filter(&filter_type_by_stop_ids(&1, params, stops))
      |> Enum.map(&{&1 |> String.capitalize() |> String.replace("_", " "), &1})
      |> SelectFormatter.filter_options(type_filter_value)

    stop_filter_value = assigns.form[:stop_ids_filter].value

    stop_id_options = SelectFormatter.formatted_select_options(stops, stop_filter_value, nil)

    facility_filter_value = assigns.form[:facility_id_filter].value

    facility_id_options =
      if async_available?(assigns, :available_facilities) do
        assigns.available_facilities.result.facilities
        |> Enum.filter(&filter_facility_by_type_and_stop_ids(&1, params))
        |> SelectFormatter.formatted_select_options(facility_filter_value, nil)
        |> Enum.map(fn {name, id} -> {String.slice(name, 0..80), id} end)
      else
        []
      end

    assigns =
      assign(assigns,
        stop_id_options: stop_id_options,
        facility_type_options: facility_type_options,
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
        class="form-control mb-16 min-h-[50rem]"
        id="service_form"
      >
        <fieldset class="flex flex-row gap-x-8 min-h-[50rem]">
          <.filtered_select
            label="Stops"
            field={@form[:stop_ids]}
            filter_field={@form[:stop_ids_filter]}
            options={@stop_id_options}
            loading={@available_facilities.loading}
            class="min-h-[50rem] min-w-[30%]"
            prompt="All Stops"
          />
          <.filtered_select
            label="Categories"
            field={@form[:facility_types]}
            filter_field={@form[:facility_types_filter]}
            options={@facility_type_options}
            class="min-w-[30%]"
            prompt="All Categories"
          />
          <.filtered_select
            label="Facilities"
            field={@form[:facility_id]}
            filter_field={@form[:facility_id_filter]}
            options={@facility_id_options}
            loading={@available_facilities.loading}
            class="min-w-[30%] max-w-[30%]"
            multiple={false}
            select_class="max-h-[90%]"
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

  defp filter_facility_by_type_and_stop_ids(facility, params) do
    # returns true if facility in list if it belongs to a selected stop, is of a selected
    # facility type, or has already been selected by the user.
    stop_ids = Map.get(params, "stop_ids", []) || []

    in_stop_ids =
      if !Enum.empty?(stop_ids) && stop_ids !== ["default"] do
        facility.stop.id in params["stop_ids"]
      else
        true
      end

    in_facility_types =
      if params["facility_types"] && params["facility_types"] !== ["default"] do
        facility.type in params["facility_types"]
      else
        true
      end

    (in_stop_ids && in_facility_types) or facility.id == params["facility_id"]
  end

  defp filter_stop_by_types(stop, params) do
    if params["facility_types"] && params["facility_types"] !== ["default"] do
      Enum.any?(Map.get(stop, :facility_types, []), fn type ->
        type in params["facility_types"]
      end)
    else
      true
    end
  end

  defp filter_type_by_stop_ids(type, params, stops) do
    stop_ids = Map.get(params, "stop_ids", []) || []

    if !Enum.empty?(stop_ids) && stop_ids !== ["default"] do
      types_from_stops =
        stops
        |> Enum.filter(&(&1.id in params["stop_ids"]))
        |> Enum.reduce([], fn stop, acc ->
          [stop.facility_types | acc]
        end)
        |> List.flatten()
        |> Enum.uniq()

      type in types_from_stops
    else
      true
    end
  end

  defp string_to_formatted_atom(string) do
    string
    |> String.upcase()
    |> String.replace(" ", "_")
    |> String.to_existing_atom()
  end
end
