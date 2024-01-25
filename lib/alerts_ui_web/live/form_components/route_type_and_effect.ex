defmodule AlertsUIWeb.FormComponents.RouteTypeAndEffect do
  @moduledoc """
    Live Component for route type and effect section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.FormComponents.EffectsForRouteTypes

  @route_types [
    "Subway",
    "Commuter Rail",
    "Bus",
    "Ferry"
  ]

  @primary_key false
  embedded_schema do
    field :route_type, :integer
    field :effect_name, :string
  end

  @fields ~w[route_type effect_name]a

  @impl true
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

  def changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
    |> validate_required(@fields)
  end

  @impl true
  def handle_event("route_type", %{"value" => route_type}, socket) do
    effects = EffectsForRouteTypes.list_effects(route_type)

    {:noreply,
     assign(socket, %{selected_route_type: route_type, effects: effects, selected_effect: nil})}
  end

  def handle_event("effect", %{"value" => effect}, socket) do
    {:noreply, assign(socket, %{selected_effect: effect})}
  end

  @impl true
  def handle_event("save", _params, socket) do
    changeset_params = %{
      effect_name: socket.assigns.selected_effect,
      route_type: InformedEntity.route_type_mapping()[socket.assigns.selected_route_type]
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
      class={unless @progress.name == "route_type_and_effect", do: "hidden", else: "min-w-full"}
      id="route_view"
    >
      <.form
        for={@changeset}
        phx-target={@myself}
        phx-submit="save"
        class="form-control gap-4 min-w-full"
        id="route_types_form"
      >
        <div class="flex flex-row">
          <h2 class="mr-28 min-w-fit text-slate-400">Select Service Type</h2>
          <div class="grid grid-cols-2 gap-4 mb-4 min-w-[50%]">
            <div :for={route_type <- @route_types}>
              <%= route_type_buttons(assigns, route_type) %>
            </div>
            <input type="hidden" id="route_type" name="route_type" value={@selected_route_type} />
          </div>
        </div>

        <hr class={if is_nil(@selected_route_type), do: "hidden"} />
        <div class="flex flex-row">
          <h2 class={
            if is_nil(@selected_route_type), do: "hidden", else: "mr-28 min-w-fit text-slate-400"
          }>
            Select Effect
          </h2>
          <div class="grid grid-cols-4 gap-4 min-w-[50%]">
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
    button_class =
      case is_nil(assigns.selected_route_type) or route_type == assigns.selected_route_type do
        true -> "btn-primary"
        false -> "btn-default"
      end

    assigns = assign(assigns, %{route_type: route_type, button_class: button_class})

    ~H"""
    <button
      type="button"
      phx-target={@myself}
      phx-click="route_type"
      class={"btn rounded-lg #{@button_class} basis-8 self-center px-8 w-full font-extrabold"}
      value={@route_type}
    >
      <%= @route_type %>
    </button>
    """
  end

  def effect_buttons(assigns, effect) do
    button_class =
      case is_nil(assigns.selected_effect) or effect == assigns.selected_effect do
        true -> "btn-primary"
        false -> "btn-default"
      end

    formatted_name =
      effect |> String.split("_") |> Enum.map_join(" ", &String.capitalize(&1))

    assigns =
      assign(assigns, %{
        effect: effect,
        button_class: button_class,
        formatted_name: formatted_name
      })

    ~H"""
    <button
      phx-target={@myself}
      phx-click="effect"
      class={"btn rounded-lg #{@button_class} basis-8 self-center px-8 w-full font-extrabold"}
      value={@effect}
    >
      <%= @formatted_name %>
    </button>
    """
  end
end
