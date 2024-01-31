defmodule AlertsUIWeb.FormComponents.AlertDetails do
  @moduledoc """
    Live Component for alert details section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route

  @primary_key false
  embedded_schema do
    field :route_ids, :string
    field :header_text, :string
    field :description_text, :string
  end

  @fields ~w[header_text description_text]a

  @impl true
  def mount(socket) do
    changeset = %__MODULE__{} |> change() |> to_form()
    socket = socket |> assign(changeset: changeset, available_routes: [])
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    available_routes =
      assigns.alert_data
      |> Map.get(:route_type)
      |> all_route_types()
      |> RoutesRepo.by_type()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:available_routes, available_routes)}
  end

  @impl true
  def handle_event("save", params, socket) do
    changeset(%__MODULE__{}, params)
    |> apply_action(:insert)
    |> case do
      {:ok, changeset} ->
        send(self(), {:create_alert, changeset})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset |> to_form())}
    end
  end

  def changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
    |> validate_required(@fields)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class={unless @progress.name == "details", do: "hidden", else: "min-w-full"}
      id="details_view"
    >
      <.form
        for={@changeset}
        phx-target={@myself}
        phx-submit="save"
        class="form-control gap-4"
        id="details_form"
      >
        <fieldset>
          <.input
            type="select"
            field={@changeset[:route_ids]}
            options={formatted_select_options(@available_routes)}
            multiple={true}
            label="Route(s)"
          />
        </fieldset>

        <.input
          field={@changeset[:header_text]}
          name="header_text"
          value=""
          label="Header"
          type="textarea"
          phx-debounce={120}
          id="header_input"
        />
        <.input
          field={@changeset[:description_text]}
          name="description_text"
          value=""
          label="Description"
          type="textarea"
          phx-debounce={120}
          id="description_input"
        />
        <.button class="btn btn-outline basis-8 self-center px-8" name="save">submit</.button>
      </.form>
    </div>
    """
  end

  # We lump subway together in the interface, so when asked for either light or
  # heavy rail include both.
  @spec all_route_types(0..4 | nil) :: [Route.type_int()]
  defp all_route_types(0), do: [0, 1]
  defp all_route_types(1), do: [0, 1]
  defp all_route_types(2), do: [2]
  defp all_route_types(3), do: [3]
  defp all_route_types(4), do: [4]
  defp all_route_types(_), do: []

  @spec formatted_select_options([Route.t()]) :: keyword(String.t())
  defp formatted_select_options(routes) do
    Enum.map(routes, fn %Route{id: id, name: name} -> {name, id} end)
  end
end
