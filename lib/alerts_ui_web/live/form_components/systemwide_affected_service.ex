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
  def update(%{alert_data: alert_data} = assigns, socket) do
    incoming_alert_data = %{
      service_types: Map.get(alert_data, :service_types, [])
    }

    form =
      %__MODULE__{}
      |> changeset(incoming_alert_data)
      |> to_form()

    assigns =
      incoming_alert_data
      |> Map.put(:form, form)
      |> Map.merge(assigns)

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def update(%{submitted: submitted}, socket) do
    socket =
      if submitted do
        form =
          %__MODULE__{}
          |> changeset(socket.assigns.form.params)
          |> validate_required(@required_fields)
          |> Map.put(:action, :validate)
          |> to_form()

        assign(socket, form: form)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-w-full flex flex-col" id="systemwide_service_view">
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
        <fieldset class="mb-8 min-h-36 max-w-[25%]">
          <.toggle_checkgroup
            label="Service types impacted"
            field={@form[:service_types]}
            options={service_type_options()}
            show_icons={true}
            class="flex-col"
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
    changeset = changeset(%__MODULE__{}, integer_service_types(systemwide_affected_service))

    case apply_action(changeset, :insert) do
      {:ok, changeset} ->
        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changeset})

      {:error, changeset} ->
        send(self(), {:add_errors, changeset.errors, __MODULE__})
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
    |> validate_length(:service_types, min: 1)
  end

  defp service_type_options do
    Enum.map([:bus, :commuter_rail, :ferry, :subway], fn name ->
      {name, InformedEntity.route_type_mapping(name) |> Integer.to_string()}
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
