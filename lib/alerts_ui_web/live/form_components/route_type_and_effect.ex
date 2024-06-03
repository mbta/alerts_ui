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
    "Subway",
    "Commuter Rail",
    "Bus",
    "Ferry",
    "Systemwide"
  ]

  @primary_key false
  embedded_schema do
    field :route_type, :integer
    field :effect_name, :string
    field :draft, :boolean
  end

  @fields ~w[route_type effect_name draft]a
  @required_fields ~w[effect_name]a

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

  def draft_changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
  end

  def changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end

  @impl true
  def handle_event("route_type", %{"value" => route_type}, socket) do
    effects = EffectsForRouteTypes.list_effects(route_type)

    {:noreply,
     assign(socket, %{selected_route_type: route_type, effects: effects, selected_effect: nil})}
  end

  @impl true
  def handle_event("effect", %{"value" => effect}, socket) do
    {:noreply, assign(socket, %{selected_effect: effect})}
  end

  @impl true
  def handle_event("save_as_draft", params, socket) do
    %{
      effect_name: Map.get(params, "effect_name"),
      route_type: InformedEntity.route_type_mapping(Map.get(params, "route_type")),
      draft: true
    }
    |> then(&draft_changeset(%__MODULE__{}, &1))
    |> apply_action(:insert)
    |> case do
      {:ok, changeset} ->
        send(self(), {:save_as_draft, changeset})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset |> to_form())}
    end
  end

  @impl true
  def handle_event("save", _params, socket) do
    changeset_params = %{
      effect_name: socket.assigns.selected_effect,
      route_type: InformedEntity.route_type_mapping(socket.assigns.selected_route_type)
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
          else: "min-w-full flex flex-col"
      }
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
          <div class="w-4 mr-4 min-w-[25%]">
            <.h2>Select Service Type</.h2>
          </div>
          <div class="grid grid-cols-2 gap-4 mb-4 min-w-[50%]">
            <div :for={route_type <- @route_types}>
              <%= route_type_buttons(assigns, route_type) %>
            </div>
            <input type="hidden" id="route_type" name="route_type" value={@selected_route_type} />
          </div>
        </div>

        <hr class={if is_nil(@selected_route_type), do: "hidden"} />
        <div class="flex flex-row">
          <div class="w-4 mr-4 min-w-[25%]">
            <.h2 hidden={is_nil(@selected_route_type)}>
              Select Effect
            </.h2>
          </div>
          <div class="grid grid-cols-4 gap-4 min-w-[50%]">
            <div :for={effect <- @effects} class={if is_nil(@selected_route_type), do: "hidden"}>
              <%= effect_buttons(assigns, effect) %>
            </div>
            <input type="hidden" id="effect_name" name="effect_name" value={@selected_effect} />
          </div>
        </div>
      </.form>
      <.button_secondary
        phx-target={@myself}
        phx-click="save_as_draft"
        phx-value-effect_name={@selected_effect}
        phx-value-route_type={@selected_route_type}
        name="draft"
        id="draft"
        hidden={is_nil(@selected_route_type)}
        class="mt-24 basis-8 self-center min-w-[15%] font-extrabold"
      >
        Save as Draft
      </.button_secondary>
    </div>
    """
  end

  def route_type_buttons(assigns, route_type) do
    show_primary =
      is_nil(assigns.selected_route_type) or route_type == assigns.selected_route_type

    assigns = assign(assigns, %{route_type: route_type, show_primary: show_primary})

    ~H"""
    <.button_primary
      :if={@show_primary}
      phx-target={@myself}
      phx-click="route_type"
      class="basis-8 self-center w-full font-extrabold"
      value={@route_type}
    >
      <%= @route_type %>
    </.button_primary>
    <.button_secondary
      :if={!@show_primary}
      phx-target={@myself}
      phx-click="route_type"
      class="basis-8 self-center w-full font-extrabold"
      value={@route_type}
    >
      <%= @route_type %>
    </.button_secondary>
    """
  end

  def effect_buttons(assigns, effect) do
    assigns =
      assign(assigns, %{
        effect: effect
      })

    ~H"""
    <.button_primary
      phx-target={@myself}
      phx-click="effect"
      class="basis-8 self-center w-full font-extrabold"
      value={@effect}
    >
      <%= @effect %>
    </.button_primary>
    """
  end
end
