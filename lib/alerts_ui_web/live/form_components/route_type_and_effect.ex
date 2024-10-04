defmodule AlertsUIWeb.FormComponents.RouteTypeAndEffect do
  @moduledoc """
    Live Component for route type and effect section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.FormComponents.Helpers.EffectsForRouteTypes

  @route_types [
    :bus,
    :subway,
    :commuter_rail,
    :ferry,
    :access,
    :systemwide
  ]

  @primary_key false
  embedded_schema do
    field :route_type, :integer
    field :effect_name, :string
  end

  @fields ~w[route_type effect_name]a
  @required_fields ~w[effect_name]a

  @impl true
  @spec mount(any()) :: {:ok, any()}
  def mount(socket) do
    changeset = %__MODULE__{} |> change() |> to_form()

    socket =
      socket
      |> assign(%{
        changeset: changeset,
        selected_route_type: nil,
        selected_effect: nil,
        route_types: @route_types,
        effects: EffectsForRouteTypes.list_effects(nil)
      })

    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    clean_alert_data = Map.merge(alert_data, %{route_ids: [], trip_ids: [], stop_ids: []})
    assigns = Map.put(assigns, :alert_data, clean_alert_data)
    {:ok, assign(socket, assigns)}
  end

  def changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end

  @impl true
  def handle_event("route_type", %{"value" => route_type}, socket) do
    effects =
      EffectsForRouteTypes.list_effects(route_type |> String.to_existing_atom())

    {:noreply,
     assign(socket, %{selected_route_type: route_type, effects: effects, selected_effect: nil})}
  end

  @impl true
  def handle_event("effect", %{"value" => effect}, socket) do
    {:noreply, assign(socket, %{selected_effect: effect})}
  end

  @impl true
  def handle_event("complete_step", _params, socket) do
    selected_effect =
      if socket.assigns.selected_effect do
        socket.assigns.selected_effect
      else
        nil
      end

    changeset_params = %{
      effect_name: selected_effect,
      route_type:
        InformedEntity.route_type_mapping(
          (socket.assigns.selected_route_type || "")
          |> String.to_existing_atom()
        )
    }

    changeset(%__MODULE__{}, changeset_params)
    |> apply_action(:insert)
    |> case do
      {:ok, changeset} ->
        send(self(), {:step_completed, changeset})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset |> to_form())}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class={
        unless @progress.name == "route_type_and_effect",
          do: "hidden",
          else: "min-w-full flex flex-col mb-8"
      }
      id="route_view"
    >
      <.h1 class="mb-8">Create new alert</.h1>
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Alert type
      </.h5>
      <.form
        for={@changeset}
        phx-target={@myself}
        phx-submit="complete_step"
        class="form-control gap-4 min-w-full"
        id="route_types_form"
      >
        <div class="w-4 mr-4 w-full text-center md:text-left">
          <.body>Service Type</.body>
        </div>
        <div class="flex flex-row mb-8 justify-center md:justify-start">
          <div class="grid sm:grid-cols-1 md:grid-cols-3 lg:grid-cols-4 2xl:grid-cols-6 gap-2">
            <div :for={route_type <- @route_types}>
              <%= route_type_buttons(assigns, route_type) %>
            </div>
            <input type="hidden" id="route_type" name="route_type" value={@selected_route_type} />
          </div>
        </div>

        <div class="w-4 mr-4 w-full text-center md:text-left">
          <.body>
            Effect
          </.body>
        </div>
        <div class="flex flex-row justify-center md:justify-start">
          <p class="text-bg-elevation-6 mb-[18rem]" hidden={!is_nil(@selected_route_type)}>
            Select a service type to see possible effects.
          </p>
          <div class="grid sm:grid-cols-1 md:grid-cols-3 lg:grid-cols-4 2xl:grid-cols-6 gap-2">
            <div :for={effect <- @effects} class={if is_nil(@selected_route_type), do: "hidden"}>
              <%= effect_buttons(assigns, effect) %>
            </div>
            <input type="hidden" id="effect_name" name="effect_name" value={@selected_effect} />
          </div>
        </div>
      </.form>
    </div>
    """
  end

  def route_type_buttons(assigns, route_type) do
    active_route = route_type == assigns.selected_route_type

    assigns = assign(assigns, %{route_type: route_type, active_route: active_route})

    ~H"""
    <.button_toggle
      active={@active_route}
      phx-target={@myself}
      phx-click="route_type"
      class="self-center min-w-[16rem]"
      value={@route_type}
      icon={@route_type}
    >
      <%= route_atom_to_string(@route_type) |> :string.titlecase() %>
    </.button_toggle>
    """
  end

  def effect_buttons(assigns, effect) do
    active_effect = effect == assigns.selected_effect

    assigns =
      assign(assigns, %{
        effect: effect,
        active_effect: active_effect
      })

    ~H"""
    <.button_toggle
      phx-target={@myself}
      phx-click="effect"
      class="self-cente min-w-[16rem]"
      value={@effect}
      active={@active_effect}
    >
      <%= @effect |> String.replace("_", " ") |> String.capitalize() %>
    </.button_toggle>
    """
  end
end
