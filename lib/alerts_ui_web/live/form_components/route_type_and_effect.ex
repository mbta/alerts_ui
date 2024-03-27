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
    "Ferry"
  ]

  @primary_key false
  embedded_schema do
    field :route_type, :integer
    field :effect_name, :string
    field :draft, :boolean
  end

  @fields ~w[route_type effect_name draft]a
  @required_fields ~w[route_type effect_name]a

  @impl true
  def mount(socket) do
    changeset = %__MODULE__{} |> change() |> to_form()

    socket =
      socket
      |> assign(%{
        changeset: changeset,
        route_types: @route_types,
        effects: EffectsForRouteTypes.list_effects(nil)
      })

    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    route_type =
      case Map.get(alert_data, :route_type) do
        nil -> nil
        integer -> InformedEntity.route_type_mapping_from_integer()[integer]
      end

    edit_alert_data =
      %{
        route_type: route_type,
        effect_name: Map.get(alert_data, :effect_name),
        effects: EffectsForRouteTypes.list_effects(route_type)
      }

    changeset =
      %__MODULE__{}
      |> changeset(edit_alert_data)

    form = to_form(changeset)
    assigns = edit_alert_data |> Map.put(:form, form) |> Map.merge(assigns)

    {:ok, assign(socket, assigns)}
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

    {:noreply, assign(socket, %{route_type: route_type, effects: effects, effect_name: nil})}
  end

  @impl true
  def handle_event("effect", %{"value" => effect}, socket) do
    {:noreply, assign(socket, %{effect_name: effect})}
  end

  @impl true
  def handle_event("save_as_draft", params, socket) do
    %{
      effect_name: Map.get(params, "effect_name"),
      route_type: InformedEntity.route_type_mapping()[Map.get(params, "route_type")],
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
      effect_name: socket.assigns.effect_name,
      route_type: InformedEntity.route_type_mapping()[socket.assigns.route_type]
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
          <h2 class="mr-28 min-w-fit text-slate-400">Select Service Type</h2>
          <div class="grid grid-cols-2 gap-4 mb-4 min-w-[50%]">
            <div :for={route_type <- @route_types}>
              <%= route_type_buttons(assigns, route_type) %>
            </div>
            <input type="hidden" id="route_type" name="route_type" value={@route_type} />
          </div>
        </div>

        <hr class={if is_nil(@route_type), do: "hidden"} />
        <div class="flex flex-row">
          <h2 class={if is_nil(@route_type), do: "hidden", else: "mr-28 min-w-fit text-slate-400"}>
            Select Effect
          </h2>
          <div class="grid grid-cols-4 gap-4 min-w-[50%]">
            <div :for={effect <- @effects} class={if is_nil(@route_type), do: "hidden"}>
              <%= effect_buttons(assigns, effect) %>
            </div>
            <input type="hidden" id="effect_name" name="effect_name" value={@effect_name} />
          </div>
        </div>
      </.form>
      <button
        phx-target={@myself}
        phx-click="save_as_draft"
        phx-value-effect_name={@effect_name}
        phx-value-route_type={@route_type}
        name="draft"
        id="draft"
        class={
          if is_nil(@route_type),
            do: "hidden",
            else: "btn rounded-lg mt-8 basis-8 self-center px-8 min-w-[25%] font-extrabold"
        }
      >
        Save as Draft
      </button>
    </div>
    """
  end

  def route_type_buttons(assigns, route_type) do
    button_class =
      if is_nil(assigns.route_type) or route_type == assigns.route_type do
        "btn-primary"
      else
        "btn-default"
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
      if is_nil(assigns.effect_name) or effect == assigns.effect_name do
        "btn-primary"
      else
        "btn-default"
      end

    assigns =
      assign(assigns, %{
        effect: effect,
        button_class: button_class
      })

    ~H"""
    <button
      phx-target={@myself}
      phx-click="effect"
      class={"btn rounded-lg #{@button_class} basis-8 self-center px-8 w-full font-extrabold"}
      value={@effect}
    >
      <%= @effect %>
    </button>
    """
  end
end
