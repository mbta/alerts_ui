defmodule AlertsUIWeb.FormComponents.SystemwideAffectedService do
  @moduledoc """
    Live Component for systemwide affected service section
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema

  require Logger

  import Ecto.Changeset

  alias AlertsUI.Models.InformedEntity

  @primary_key false
  embedded_schema do
    field :service_types, {:array, :integer}
  end

  @fields ~w[service_types]a
  @required_fields ~w[service_types]a

  @impl true
  def mount(socket) do
    form =
      %__MODULE__{}
      |> changeset(%{})
      |> to_form()

    {:ok, assign(socket, %{form: form})}
  end

  @impl true
  def update(%{alert_data: alert_data, editing: editing} = assigns, socket) do
    assigns =
      if editing do
        update_for_edit(alert_data, assigns)
      else
        assigns
      end

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={
      unless @progress.name == "details",
        do: "hidden",
        else: "min-w-full flex flex-col"
    }>
      <.h1 class="mb-8">Create new systemwide alert</.h1>
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Affected service
      </.h5>
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control"
        id="systemwide-affected-service-form"
      >
        <fieldset class="mb-8 min-h-36">
          <.select
            label="Service Type(s)"
            field={@form[:service_types]}
            options={service_type_options()}
            multiple={true}
            prompt="All"
            class="max-w-[16rem]"
            select_class="min-h-[9rem]"
          />
        </fieldset>
      </.form>
      <hr />
    </div>
    """
  end

  @impl true
  def handle_event(
        "validate",
        %{"systemwide_affected_service" => systemwide_affected_service},
        socket
      ) do
    systemwide_affected_service = integer_service_types(systemwide_affected_service)

    changeset = changeset(%__MODULE__{}, systemwide_affected_service)

    case apply_action(changeset, :insert) do
      {:ok, changeset} ->
        send(self(), {:section_completed, changeset})
    end

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     assign(socket, %{form: form, systemwide_affected_service: systemwide_affected_service})}
  end

  @impl true
  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  defp changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end

  defp update_for_edit(alert_data, assigns) do
    edit_alert_data = %{
      service_types: Map.get(alert_data, :service_types, [])
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

  defp service_type_options do
    Enum.map(["Bus", "Commuter Rail", "Ferry", "Subway"], fn name ->
      {name, InformedEntity.route_type_mapping(name)}
    end)
  end

  defp integer_service_types(%{"service_types" => service_types} = systemwide_affected_service)
       when is_list(service_types) do
    service_types =
      service_types
      |> Enum.map(&integer_service_type/1)
      |> Enum.reject(&is_nil/1)

    %{systemwide_affected_service | "service_types" => service_types}
  end

  defp integer_service_type("1"), do: 1
  defp integer_service_type("2"), do: 2
  defp integer_service_type("3"), do: 3
  defp integer_service_type("4"), do: 4
  defp integer_service_type(service_type_int) when service_type_int in 0..4, do: service_type_int

  defp integer_service_type(unknown_service_type) do
    Logger.error("Unknown service type: #{inspect(unknown_service_type)}")
    nil
  end
end
