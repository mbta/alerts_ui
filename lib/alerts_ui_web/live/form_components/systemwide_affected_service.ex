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
  def render(assigns) do
    ~H"""
    <div class={
      unless @progress.name == "details",
        do: "hidden",
        else: "min-w-full flex flex-col"
    }>
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control gap-4"
        id="systemwide-affected-service-form"
      >
        <fieldset class="flex flex-row gap-4">
          <.input
            type="select"
            label="Service Type(s)"
            field={@form[:service_types]}
            options={service_type_options()}
            multiple={true}
            prompt="All"
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

    changeset =
      %__MODULE__{}
      |> changeset(systemwide_affected_service)

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

  defp changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
    |> validate_required(@required_fields)
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
