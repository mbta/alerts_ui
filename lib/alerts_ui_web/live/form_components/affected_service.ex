defmodule AlertsUIWeb.FormComponents.AffectedService do
  @moduledoc """
    Live Component for affected service section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUI.Models.InformedEntity

  alias AlertsUIWeb.FormComponents.Helpers.{
    ContentFormatter,
    ErrorFormatter,
    SelectFormatter,
    ServiceEffectCombinations
  }

  alias MBTAV3API.Routes.Route

  @primary_key false
  embedded_schema do
    field :route_ids, {:array, :string}
    field :route_ids_filter, :string
    field :direction, :string
    field :trip_ids, {:array, :string}
    field :trip_ids_filter, :string
    field :stop_ids, {:array, :string}
    field :stop_ids_filter, :string
    field :trip_information_by_id, {:map, :map}
  end

  @fields ~w[route_ids direction trip_ids stop_ids trip_information_by_id route_ids_filter trip_ids_filter stop_ids_filter]a

  @impl true
  def mount(socket) do
    form = %__MODULE__{} |> changeset(%{}) |> to_form()

    socket =
      socket
      |> assign(%{
        form: form,
        button_selected_routes: [],
        direction_names_map: [],
        edited: false
      })

    {:ok, socket}
  end

  def update(%{refresh: true}, socket) do
    alert_data = %{
      route_ids: [],
      direction: "default",
      trip_ids: [],
      stop_ids: []
    }

    form =
      %__MODULE__{}
      |> changeset(alert_data)
      |> to_form()

    assigns = %{
      form: form,
      available_schedules: [],
      available_stops: []
    }

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def update(%{alert_data: alert_data, editing: editing} = assigns, socket) do
    route_type = Map.get(alert_data, :route_type)
    route_types = all_route_types(route_type)
    send(self(), {:fetch_available_routes, route_types})

    direction_names_map =
      Map.new(assigns.available_routes, &{&1.id, &1.direction_names})

    assigns =
      if editing == true and socket.assigns.edited == false do
        alert_data = %{
          route_ids: Map.get(alert_data, :route_ids) || [],
          direction: Map.get(alert_data, :direction) || "default",
          trip_ids: Map.get(alert_data, :trip_ids) || [],
          stop_ids: Map.get(alert_data, :stop_ids) || []
        }

        get_stops_by_route_ids(
          alert_data.route_ids,
          alert_data.direction
        )

        get_schedules_by_route_ids(
          alert_data.route_ids,
          alert_data.direction
        )

        form =
          %__MODULE__{}
          |> changeset(alert_data)
          |> to_form()

        assigns
        |> Map.put(:form, form)
        |> Map.put(:alert_data, alert_data)
        |> Map.put(:edited, true)
      else
        assigns
      end
      |> Map.put(:direction_names_map, direction_names_map)

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def update(%{submitted: submitted}, socket) do
    form_params =
      Map.update(socket.assigns.form.params, "route_ids", nil, fn route_ids ->
        if is_nil(route_ids) or Enum.empty?(route_ids), do: nil, else: route_ids
      end)

    socket =
      if submitted do
        changeset =
          %__MODULE__{}
          |> changeset(form_params)
          |> validate_required(
            ServiceEffectCombinations.required_fields(socket.assigns.combination)
          )

        errors =
          case changeset |> apply_action(:validate) do
            {:ok, _changeset} -> []
            {:error, changeset} -> ErrorFormatter.parse_field_errors(changeset)
          end

        form =
          changeset
          |> to_form()
          |> Map.put(:errors, errors)
          |> Map.put(:action, :validate)

        assign(socket, form: form)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"affected_service" => affected_service}, socket) do
    affected_service =
      affected_service
      |> Map.put_new("direction", "default")
      |> clean_route_ids(socket.assigns.form)
      |> populate_default_stops()
      |> populate_default_trips()

    changeset = validate(affected_service, socket.assigns)

    case apply_action(
           changeset
           |> validate_required(
             ServiceEffectCombinations.required_fields(socket.assigns.combination)
           ),
           :validate
         ) do
      {:ok, changeset} ->
        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changeset})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
        send(self(), {:section_completed, changeset})
    end

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, %{form: form})}
  end

  @impl true
  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  def validate(affected_service, assigns) do
    get_stops_by_route_ids(
      Map.get(affected_service, "route_ids", []),
      affected_service["direction"]
    )

    get_schedules_by_route_ids(
      Map.get(affected_service, "route_ids", []),
      affected_service["direction"]
    )

    trip_information_by_id =
      trip_information_by_id(assigns.available_schedules, affected_service["trip_ids"])

    affected_service = Map.put(affected_service, "trip_information_by_id", trip_information_by_id)

    %__MODULE__{}
    |> changeset(affected_service)
  end

  def changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
  end

  def clean_route_ids(affected_service, form) do
    # necessary to prevent duplication when input is checkbox group
    existing_route_ids = form.params["route_ids"] || []
    incoming_route_ids = affected_service["route_ids"] || []

    new_route_ids =
      Enum.reduce(incoming_route_ids, existing_route_ids, fn route_id, acc ->
        if route_id in acc do
          acc -- [route_id]
        else
          [route_id | acc]
        end
      end)

    affected_service |> Map.put("route_ids", new_route_ids)
  end

  @impl true
  def render(assigns) do
    route_ids = assigns.form[:route_ids].value || []
    route_filter_value = assigns.form[:route_ids_filter].value

    route_id_options =
      SelectFormatter.formatted_select_options(assigns.available_routes, route_filter_value)

    direction_options =
      SelectFormatter.formatted_direction_options(
        route_ids,
        assigns.direction_names_map
      )

    trip_filter_value = assigns.form[:trip_ids_filter].value

    trip_id_options =
      if Enum.empty?(route_ids) do
        []
      else
        assigns.available_schedules
        |> Enum.filter(fn schedule ->
          schedule.route.id in Map.get(assigns.form[:route_ids], :value, [])
        end)
        |> Enum.group_by(&SelectFormatter.name_for_option(&1.route))
        |> SelectFormatter.formatted_trip_options(trip_filter_value)
      end

    stop_filter_value = assigns.form[:stop_ids_filter].value

    stop_id_options =
      if match?([_route_id], route_ids) do
        SelectFormatter.formatted_select_options(assigns.available_stops, stop_filter_value)
      else
        []
      end

    assigns =
      assign(assigns,
        route_id_options: route_id_options,
        direction_options: direction_options,
        trip_id_options: trip_id_options,
        stop_id_options: stop_id_options,
        service_type_name: assigns.route_type |> InformedEntity.route_code_mapping() || nil
      )

    ~H"""
    <div
      class={unless @progress.name == "details", do: "hidden", else: "min-w-full mb-8 min-h-[32rem]"}
      id="service_view"
    >
      <.h1 class="mb-8">
        Create new <%= ContentFormatter.route_atom_to_string(@service_type_name) %>
        <%= (@effect_name || "") |> String.downcase() %> alert
      </.h1>
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Affected service
      </.h5>
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control mb-16"
        id="service_form"
      >
        <fieldset class="flex flex-row gap-x-12 min-h-[32rem]">
          <.filtered_select
            label={if @route_type in [0, 1, 2], do: "Line(s)", else: "Route(s)"}
            field={@form[:route_ids]}
            filter_field={@form[:route_ids_filter]}
            loading={Enum.empty?(@route_id_options)}
            options={@route_id_options}
            class={"min-w-[18rem] min-h-[30rem] #{@route_type !== 3 && "hidden"}"}
          />
          <.toggle_checkgroup
            label={if @route_type in [0, 1, 2], do: "Line(s)", else: "Route(s)"}
            field={@form[:route_ids]}
            options={@route_id_options}
            icon_type={icon_type(@route_type)}
            class={"flex-col #{if @route_type === 3, do: "hidden"}"}
            button_class="min-w-[100%]"
            show_icons={true}
          />
          <%= if show_trips_input?(assigns) do %>
            <.filtered_select
              label="Trip(s)"
              field={@form[:trip_ids]}
              filter_field={@form[:trip_ids_filter]}
              options={@trip_id_options}
              loading={
                Enum.empty?(@trip_id_options) and !disable_trip_input?(@form[:route_ids].value)
              }
              class="min-w-[24rem] min-h-[30rem] max-h-[30rem]"
              disabled={disable_trip_input?(@form[:route_ids].value)}
              prompt={if disable_trip_input?(@form[:route_ids].value), do: nil, else: "All Trips"}
            />
          <% end %>
          <div class="flex flex-col justify-start">
            <%= if show_directions_input?(assigns) do %>
              <.select
                label={if show_stops_input?(assigns), do: "Stop(s)", else: "Direction"}
                field={@form[:direction]}
                options={@direction_options}
                disabled={disable_stop_input?(@form[:route_ids].value)}
                prompt={
                  if disable_stop_input?(@form[:route_ids].value), do: "", else: "Both Directions"
                }
                class="min-w-[30rem]"
              />
            <% end %>

            <%= if show_stops_input?(assigns) do %>
              <div class="min-h-[90%]">
                <.filtered_select
                  field={@form[:stop_ids]}
                  filter_field={@form[:stop_ids_filter]}
                  options={@stop_id_options}
                  loading={
                    Enum.empty?(@stop_id_options) and !disable_stop_input?(@form[:route_ids].value)
                  }
                  class="min-w-[24rem] min-h-[30rem] h-[30rem]"
                  disabled={disable_stop_input?(@form[:route_ids].value)}
                  prompt={
                    if disable_stop_input?(@form[:route_ids].value),
                      do: nil,
                      else: "All Stops"
                  }
                />
              </div>
            <% end %>
          </div>
        </fieldset>
      </.form>
      <hr />
    </div>
    """
  end

  defp icon_type(route_type) do
    case route_type do
      2 -> :commuter_rail
      4 -> :ferry
      _ -> nil
    end
  end

  def trip_information_by_id(available_schedules, trip_ids) do
    available_schedules
    |> Stream.filter(fn schedule -> schedule.trip.id in trip_ids end)
    |> Enum.reduce(%{}, fn schedule, acc ->
      Map.put(acc, schedule.trip.id, %{
        direction_id: schedule.trip.direction_id,
        route_id: schedule.route.id
      })
    end)
  end

  @spec get_stops_by_route_ids(String.t(), list()) :: any()
  def get_stops_by_route_ids(route_ids, direction) do
    send(
      self(),
      {:fetch_available_stops, direction, route_ids}
    )
  end

  def get_schedules_by_route_ids(route_ids, direction) do
    send(
      self(),
      {:fetch_available_schedules, route_ids, direction}
    )
  end

  @spec show_trips_input?(map()) :: boolean()
  defp show_trips_input?(%{combination: combination}) do
    combination in [:RDT, :RDTS]
  end

  @spec show_stops_input?(map()) :: boolean()
  defp show_stops_input?(%{combination: combination}) do
    combination in [:RDS, :RDTS]
  end

  @spec show_directions_input?(map()) :: boolean()
  defp show_directions_input?(%{combination: combination}) do
    combination in [:RDS, :RDTS, :RDS, :RDT]
  end

  @spec disable_stop_input?(list() | nil) :: boolean()
  defp disable_stop_input?(route_ids) when is_list(route_ids), do: length(route_ids) !== 1
  defp disable_stop_input?(_route_ids), do: true

  @spec disable_trip_input?(list() | nil) :: boolean()
  defp disable_trip_input?(route_ids) when is_list(route_ids), do: Enum.empty?(route_ids)
  defp disable_trip_input?(_route_ids), do: true

  # We lump subway together in the interface, so when asked for either light or
  # heavy rail include both.
  @spec all_route_types(0..4 | nil) :: [Route.type_int()]
  defp all_route_types(0), do: [0, 1]
  defp all_route_types(1), do: [0, 1]
  defp all_route_types(2), do: [2]
  defp all_route_types(3), do: [3]
  defp all_route_types(4), do: [4]
  defp all_route_types(_), do: []

  defp populate_default_stops(affected_service) do
    if Map.get(affected_service, "stop_ids") in [nil, "default", ["default"]] do
      Map.put(
        affected_service,
        "stop_ids",
        []
      )
    else
      affected_service
    end
  end

  defp populate_default_trips(affected_service) do
    if Map.get(affected_service, "trip_ids") in [nil, "default", ["default"]] do
      Map.put(
        affected_service,
        "trip_ids",
        []
      )
    else
      affected_service
    end
  end
end
