defmodule AlertsUIWeb.FormComponents.AccessAffectedService do
  @moduledoc """
    Live Component for access affected service section
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema

  require Logger

  import Ecto.Changeset

  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.FormComponents.Helpers.SelectFormatter

  @primary_key false
  embedded_schema do
    field :stop_ids, {:array, :string}
    field :stop_ids_filter, :binary
    field :facility_types, {:array, :string}
    field :facility_types_filter, :string
    field :facility_ids, {:array, :string}
    field :facility_ids_filter, :string
  end

  @fields ~w[stop_ids stop_ids_filter facility_types facility_types_filter facility_ids facility_ids_filter]a
  @required_fields ~w[facility_ids]a

  @impl true
  def mount(socket) do
    form =
      %__MODULE__{}
      |> changeset(%{})
      |> to_form()

    {:ok,
     assign(socket, %{
       form: form,
       facility_types: [],
       available_facilities: [],
       available_stops: [],
       effect_name: nil
     })}
  end

  @impl true
  def update(%{alert_data: alert_data, editing: editing} = assigns, socket) do
    facility_types =
      alert_data.effect_name
      |> string_to_formatted_atom
      |> InformedEntity.facility_effect_to_types()

    send(self(), {:fetch_available_facilities, facility_types})

    stop_ids =
      assigns.available_facilities
      |> Enum.map(fn facility ->
        stop = Map.get(facility, :stop)
        if stop, do: stop.id, else: nil
      end)
      |> Enum.filter(&(!is_nil(&1)))
      |> Enum.uniq()

    send(self(), {:fetch_stops_by_stop_ids, stop_ids})

    assigns =
      if editing do
        update_for_edit(alert_data, assigns)
      else
        assigns
      end
      |> Map.merge(%{facility_types: facility_types, effect_name: alert_data.effect_name})

    {:ok, assign(socket, assigns)}
  end

  defp update_for_edit(alert_data, assigns) do
    edit_alert_data = %{
      facility_ids: Map.get(alert_data, :facility_ids, [])
    }

    form =
      %__MODULE__{}
      |> changeset(edit_alert_data)
      |> Map.put(:action, :validate)
      |> to_form()

    edit_alert_data
    |> Map.put(:form, form)
    |> Map.merge(assigns)
  end

  @impl true
  def handle_event(
        "validate",
        %{"access_affected_service" => access_affected_service},
        socket
      ) do
    changeset = changeset(%__MODULE__{}, access_affected_service)

    case apply_action(changeset, :insert) do
      {:ok, changeset} ->
        send(self(), {:section_completed, changeset})

      {:error, changeset} ->
        changeset
    end

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, %{form: form, access_affected_service: access_affected_service})}
  end

  def changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
    |> validate_required(@required_fields)

  end

  @impl true
  def render(assigns) do
    params = assigns.form.params

    facility_type_options =
      assigns.facility_types
      |> Enum.map(&{&1 |> String.capitalize() |> String.replace("_", " "), &1})

    stop_id_options =
      SelectFormatter.formatted_select_options(assigns.available_stops)

    facility_id_options =
      assigns.available_facilities
      |> Enum.filter(&filter_by_type_and_stop_ids(&1, params))
      |> SelectFormatter.formatted_select_options()

    assigns =
      assign(assigns,
        stop_id_options: stop_id_options,
        facility_type_options: facility_type_options,
        facility_id_options: facility_id_options
      )

    ~H"""
    <div
      class={
        unless @progress.name == "details",
          do: "hidden",
          else: "min-w-full flex flex-col"
      }
      id="access_service_view"
    >
      <.h1 class="mb-8">Create new Access alert for <%= @effect_name %></.h1>
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Affected service
      </.h5>
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control mb-16 min-h-[30rem]"
        id="service_form"
      >
        <fieldset class="flex flex-row gap-x-12 min-h-[30rem]">
          <.filtered_select
            label="Stop(s)"
            field={@form[:stop_ids]}
            filter_field={@form[:stop_ids_filter]}
            options={@stop_id_options}
            class="min-w-[24rem] min-h-[90%]"
            prompt="All Stops"
          />
          <.filtered_select
            label="Categories"
            field={@form[:facility_types]}
            filter_field={@form[:facility_types_filter]}
            options={@facility_type_options}
            class="min-w-[24rem] min-h-[90%]"
            prompt="All Categories"
          />
          <.filtered_select
            label="Amenities"
            field={@form[:facility_ids]}
            filter_field={@form[:facility_ids_filter]}
            options={@facility_id_options}
            class="min-w-[48rem] min-h-[90%]"
          />
        </fieldset>
      </.form>
      <hr />
    </div>
    """
  end

  defp filter_by_type_and_stop_ids(facility, params) do
    in_stop_ids =
      if params["stop_ids"] && params["stop_ids"] !== ["default"] do
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

    in_stop_ids && in_facility_types
  end

  defp string_to_formatted_atom(string) do
    string
    |> String.upcase()
    |> String.replace(" ", "_")
    |> String.to_atom()
  end
end
