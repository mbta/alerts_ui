defmodule AlertsUIWeb.FormComponents.AlertDetails do
  @moduledoc """
    Live Component for alert details section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @primary_key false
  embedded_schema do
    field :route_ids, {:array, :string}
    field :direction, :string
    field :stop_ids, {:array, :string}
    field :header_text, :string
    field :description_text, :string
    field :draft, :boolean
  end

  @fields ~w[route_ids direction header_text description_text draft stop_ids]a
  @required_fields ~w[header_text description_text]a

  @impl true
  def mount(socket) do
    form = %__MODULE__{} |> changeset() |> to_form()
    socket = socket |> assign(%{form: form, available_routes: []})

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    available_routes =
      assigns
      |> get_in([:alert_data, :route_type])
      |> all_route_types()
      |> RoutesRepo.by_type()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(%{
       available_routes: available_routes,
       available_stops: []
     })}
  end

  def handle_event("validate", %{"alert_details" => alert_details}, socket) do
    alert_details = populate_default_direction(alert_details)

    available_stops =
      available_stops(alert_details["direction"], Map.get(alert_details, "route_ids", []))

    # handle the default "all stops" case
    alert_details =
      with true <- Map.get(alert_details, "stop_ids", nil) in [[""], []],
           false <- Enum.empty?(Map.get(alert_details, "route_ids", [])) do
        Map.put(alert_details, "stop_ids", Enum.map(available_stops, &id_for_option(&1)))
      else
        _ -> alert_details
      end

    changeset =
      %__MODULE__{}
      |> changeset(alert_details)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, %{form: to_form(changeset), available_stops: available_stops})}
  end

  @impl true
  def handle_event("save_as_draft", _params, socket) do
    changes = Map.put(socket.assigns.form.source.changes, :draft, true)

    %__MODULE__{}
    |> draft_changeset(changes)
    |> apply_action(:insert)
    |> case do
      {:ok, changeset} ->
        send(self(), {:save_as_draft, changeset})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, changeset |> to_form())}
    end
  end

  @impl true
  def handle_event("save", _params, socket) do
    %__MODULE__{}
    |> changeset(socket.assigns.form.source.changes)
    |> apply_action(:insert)
    |> case do
      {:ok, changeset} ->
        send(self(), {:create_alert, changeset})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset |> to_form())}
    end
  end

  def draft_changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
  end

  def changeset(changeset, params \\ %{}) do
    changeset
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end

  @impl true
  def render(assigns) do
    route_id_options = formatted_select_options(assigns.available_routes)
    direction_options = formatted_direction_options(assigns.form[:route_ids].value)
    stop_id_options = formatted_select_options(assigns.available_stops)

    assigns =
      assign(assigns,
        route_id_options: route_id_options,
        direction_options: direction_options,
        stop_id_options: stop_id_options
      )

    ~H"""
    <div
      class={unless @progress.name == "details", do: "hidden", else: "min-w-full flex flex-col"}
      id="details_view"
    >
      <.form
        for={@form}
        phx-target={@myself}
        phx-submit="save"
        phx-change="validate"
        class="form-control gap-4"
        id="details_form"
      >
        <fieldset class="flex flex-row gap-4">
          <.input
            type="select"
            label="Route(s)"
            field={@form[:route_ids]}
            options={@route_id_options}
            multiple={true}
          />

          <.input
            type="select"
            label="Direction"
            field={@form[:direction]}
            options={@direction_options}
          />

          <.input
            type="select"
            label="Stop(s)"
            field={@form[:stop_ids]}
            options={@stop_id_options}
            prompt={if Map.has_key?(assigns.form.params, "route_ids"), do: "All Stops", else: nil}
            multiple={true}
          />
        </fieldset>

        <.input
          field={@form[:header_text]}
          value=""
          label="Header"
          type="textarea"
          phx-debounce={120}
          id="header_input"
        />
        <.input
          field={@form[:description_text]}
          value=""
          label="Description"
          type="textarea"
          phx-debounce={120}
          id="description_input"
        />
        <.button class="btn btn-outline basis-8 self-center px-8" name="save">submit</.button>
      </.form>
      <button
        phx-target={@myself}
        phx-click="save_as_draft"
        type="button"
        name="draft"
        id="details_draft"
        class="btn rounded-lg mt-8 basis-8 self-center px-8 min-w-[25%] font-extrabold"
      >
        Save as Draft
      </button>
    </div>
    """
  end

  @spec available_stops(String.t(), [String.t()]) :: [Stop.t()]
  defp available_stops([], _route_ids), do: []

  defp available_stops("", route_ids) do
    route_ids
    |> Enum.flat_map(fn route ->
      Enum.flat_map([0, 1], &StopsRepo.by_route(route, &1))
    end)
  end

  defp available_stops(direction, route_ids) do
    route_ids
    |> Enum.flat_map(fn route ->
      StopsRepo.by_route(route, direction)
    end)
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

  @spec populate_default_direction(map()) :: map()
  defp populate_default_direction(%{"route_ids" => [_ | _]} = alert_details),
    do: Map.put_new(alert_details, "direction", "")

  defp populate_default_direction(alert_details), do: alert_details

  @spec formatted_select_options([Route.t() | Stop.t()]) :: keyword(String.t())
  defp formatted_select_options(objects) do
    objects
    |> Enum.sort_by(&sort_order/1)
    |> Enum.map(fn object -> {name_for_option(object), id_for_option(object)} end)
  end

  @spec sort_order(Stop.t() | Route.t()) :: non_neg_integer() | nil
  # keep original order from API
  defp sort_order(%Stop{}), do: nil
  defp sort_order(%Route{sort_order: sort_order}), do: sort_order

  @spec name_for_option(Stop.t() | Route.t()) :: String.t()
  defp name_for_option(%Stop{name: name}), do: name

  defp name_for_option(%Route{name: empty_name, long_name: long_name})
       when is_nil(empty_name) or empty_name == "",
       do: long_name

  defp name_for_option(%Route{name: name}), do: name

  @spec id_for_option(Stop.t() | Route.t()) :: String.t()
  def id_for_option(%Stop{id: id}), do: id
  def id_for_option(%Route{id: id}), do: id

  @spec formatted_direction_options([String.t()] | nil) :: keyword(String.t())
  defp formatted_direction_options([_ | _]) do
    [
      "Both Directions": "",
      Outbound: "0",
      Inbound: "1"
    ]
  end

  defp formatted_direction_options(_), do: []
end
