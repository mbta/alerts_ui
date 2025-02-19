defmodule AlertsUIWeb.FormComponents.AffectedService do
  @moduledoc """
    Live Component for affected service section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertLive

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
    field :single_route_id, :string
    field :route_ids_filter, :string
    field :direction, :string
    field :trip_ids, {:array, :string}
    field :trip_ids_filter, :string
    field :stop_ids, {:array, :string}
    field :stop_ids_filter, :string
    field :trip_information_by_id, {:map, :map}
  end

  @fields ~w[route_ids direction trip_ids stop_ids trip_information_by_id route_ids_filter trip_ids_filter stop_ids_filter single_route_id]a

  @impl true
  def mount(socket) do
    form = %__MODULE__{} |> changeset(%{}) |> to_form()

    socket =
      socket
      |> assign(%{
        form: form,
        button_selected_routes: [],
        updated: false,
        available_routes: %{},
        available_schedules: %{},
        available_stops: %{}
      })

    {:ok, socket}
  end

  @impl true
  def update(
        %{
          alert_data: alert_data,
          route_type: route_type,
          editing: true
        } = assigns,
        socket
      ) do
    trip_information_by_id =
      if async_available?(assigns, :available_schedules) do
        trip_information_by_id(
          Map.get(assigns.available_schedules, :result, []),
          Map.get(alert_data, "trip_ids", [])
        )
      else
        %{}
      end

    alert_data = Map.put(alert_data, :trip_information_by_id, trip_information_by_id)

    changeset =
      %__MODULE__{}
      |> changeset(alert_data)

    changes =
      changeset
      |> apply_action!(:validate)

    assigns =
      assigns
      |> Map.put(:form, to_form(changeset))
      |> Map.put(:alert_data, alert_data)

    send(self(), {:section_completed, changes})

    route_types = all_route_types(route_type)

    direction = alert_data.direction
    route_ids = alert_data.route_ids
    required_fields = ServiceEffectCombinations.required_fields(assigns.combination)

    socket =
      socket
      |> assign(assigns)
      |> assign_async([:available_routes], fn ->
        {:ok,
         %{
           available_routes: CreateAlertLive.get_routes(route_types)
         }}
      end)
      |> assign_stops(route_ids, direction, required_fields)
      |> assign_schedules(route_ids, direction, required_fields)

    {:ok, socket}
  end

  @impl true
  def update(
        %{alert_data: alert_data, combination: combination, route_type: route_type} = assigns,
        socket
      ) do
    changeset = changeset(%__MODULE__{}, alert_data)

    {result, error_changeset} =
      apply_action(
        changeset
        |> validate_required(ServiceEffectCombinations.required_fields(combination)),
        :validate
      )

    if result === :error do
      send(
        self(),
        {:add_errors, ErrorFormatter.parse_field_errors(error_changeset), __MODULE__}
      )
    end

    route_types = all_route_types(route_type)

    socket =
      socket
      |> assign(assigns)
      |> assign_async(:available_routes, fn ->
        {:ok, %{available_routes: CreateAlertLive.get_routes(route_types)}}
      end)

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
      |> clean_route_ids(socket.assigns.form, socket.assigns.effect_name)
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
        available_schedules =
          Map.get(socket.assigns.available_schedules, :result)

        selected_trips =
          if available_schedules do
            available_schedules
            |> Enum.filter(&(&1.trip.id in affected_service["trip_ids"]))
          else
            nil
          end

        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changeset})
        send(self(), {:selected_trips, selected_trips})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
        send(self(), {:section_completed, changeset})
    end

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    direction = affected_service["direction"]
    route_ids = Map.get(affected_service, "route_ids", [])
    required_fields = ServiceEffectCombinations.required_fields(socket.assigns.combination)

    socket =
      socket
      |> assign(%{form: form})
      |> assign_stops(route_ids, direction, required_fields)
      |> assign_schedules(route_ids, direction, required_fields)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  def validate(affected_service, assigns) do
    trip_information_by_id =
      if async_available?(assigns, :available_schedules) do
        trip_information_by_id(
          assigns.available_schedules.result,
          Map.get(affected_service, "trip_ids", [])
        )
      else
        %{}
      end

    affected_service = Map.put(affected_service, "trip_information_by_id", trip_information_by_id)

    %__MODULE__{}
    |> changeset(affected_service)
  end

  def changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
  end

  def clean_route_ids(affected_service, _form, "Detour") do
    incoming_route_id = affected_service["single_route_id"] || nil

    affected_service
    |> Map.put("route_ids", List.wrap(incoming_route_id) |> Enum.reject(&is_nil/1))
  end

  def clean_route_ids(affected_service, form, _) do
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

  def assign_stops(socket, route_ids, direction, fields) do
    if :stop_ids in fields do
      assign_async(socket, [:available_stops], fn ->
        {:ok,
         %{
           available_stops:
             CreateAlertLive.get_stops(
               route_ids,
               direction
             )
         }}
      end)
    else
      socket
    end
  end

  def assign_schedules(socket, route_ids, direction, fields) do
    if :trip_ids in fields do
      assign_async(socket, [:available_schedules], fn ->
        {:ok,
         %{
           available_schedules:
             CreateAlertLive.get_schedules(
               route_ids,
               direction
             )
         }}
      end)
    else
      socket
    end
  end

  @impl true
  def render(assigns) do
    route_ids = assigns.form[:route_ids].value || []
    route_filter_value = assigns.form[:route_ids_filter].value

    route_id_options =
      SelectFormatter.formatted_select_options(%SelectFormatter{
        options: Map.get(assigns.available_routes, :result, []) || [],
        filter_value: route_filter_value,
        route_type: assigns.route_type,
        values_to_keep: route_ids
      })

    direction_names_map =
      if async_available?(assigns, :available_routes) do
        Map.new(assigns.available_routes.result, &{&1.id, &1.direction_names})
      else
        %{}
      end

    direction_options =
      SelectFormatter.formatted_direction_options(
        route_ids,
        direction_names_map
      )

    trip_ids = assigns.form[:trip_ids].value || []
    trip_filter_value = assigns.form[:trip_ids_filter].value

    trip_id_options =
      if async_available?(assigns, :available_schedules) do
        schedules_by_route_type =
          assigns.available_schedules.result
          |> Enum.filter(fn schedule ->
            schedule.route.id in Map.get(assigns.form[:route_ids], :value, [])
          end)
          |> Enum.group_by(&SelectFormatter.name_for_option(&1.route))

        SelectFormatter.formatted_select_options(%SelectFormatter{
          schedules_by_route_name: schedules_by_route_type,
          route_type: assigns.route_type,
          filter_value: trip_filter_value,
          values_to_keep: trip_ids
        })
      else
        []
      end

    stop_ids = assigns.form[:stop_ids].value || []
    stop_filter_value = assigns.form[:stop_ids_filter].value

    stop_id_options =
      SelectFormatter.formatted_select_options(%SelectFormatter{
        options: Map.get(assigns.available_stops, :result, []) || [],
        filter_value: stop_filter_value,
        route_type: assigns.route_type,
        values_to_keep: stop_ids
      })

    assigns =
      assign(assigns,
        route_id_options: route_id_options,
        direction_options: direction_options,
        trip_id_options: trip_id_options,
        stop_id_options: stop_id_options,
        service_type_name: assigns.route_type |> InformedEntity.route_code_mapping() || nil
      )

    ~H"""
    <div class="min-w-[100%] self-start min-h-[50rem] flex flex-col" id="service_view">
      <.h1 class="mb-8">
        Create new {ContentFormatter.route_atom_to_string(@service_type_name)}
        {(@effect_name || "") |> String.downcase()} alert
      </.h1>
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Affected service
      </.h5>
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class={["form-control flex flex-row gap-x-8 mb-4", @route_type !== 2 && "h-[50rem]"]}
        id="service_form"
      >
        <div class="w-[33%]">
          <.filtered_select
            label={if @route_type in [0, 1, 2], do: "Lines", else: "Routes"}
            field={if @effect_name == "Detour", do: @form[:single_route_id], else: @form[:route_ids]}
            filter_field={@form[:route_ids_filter]}
            loading={@available_routes.loading}
            no_results={Enum.empty?(@route_id_options)}
            options={@route_id_options}
            class={"#{@route_type !== 3 && "hidden"} h-full"}
            multiple={if @effect_name == "Detour", do: false, else: true}
          />
          <.toggle_checkgroup
            label={if @route_type in [0, 1, 2], do: "Lines", else: "Routes"}
            field={@form[:route_ids]}
            options={@route_id_options}
            icon_type={icon_type(@route_type)}
            class={"flex-col #{if @route_type === 3, do: "hidden"}"}
            button_class="min-w-[100%]"
            show_icons={true}
          />
        </div>

        <div :if={show_trips_input?(assigns)} class="flex flex-col justify-start w-[33%]">
          <.select
            :if={show_directions_input?(assigns)}
            label={
              cond do
                show_trips_input?(assigns) -> "Trips"
                show_stops_input?(assigns) -> "Stops"
                true -> "Direction"
              end
            }
            field={@form[:direction]}
            options={@direction_options}
            disabled={disable_stop_input?(@form[:route_ids].value)}
            prompt={if disable_stop_input?(@form[:route_ids].value), do: "", else: "Both Directions"}
          />
          <div class="min-w-[100%] min-h-[90%]">
            <.filtered_select
              field={@form[:trip_ids]}
              filter_field={@form[:trip_ids_filter]}
              options={@trip_id_options}
              loading={Map.get(@available_schedules, :loading, true)}
              no_results={
                Enum.empty?(@trip_id_options) && !disable_trip_input?(@form[:route_ids].value)
              }
              class={
                "min-w-[100%] " <>
                if(not show_trips_input?(assigns), do: "min-h-[90%]", else: "min-h-full")
              }
              disabled={disable_trip_input?(@form[:route_ids].value)}
              prompt={if disable_trip_input?(@form[:route_ids].value), do: nil, else: "All Trips"}
            />
          </div>
        </div>
        <div class="flex flex-col justify-start w-[33%]">
          <.select
            :if={show_directions_input?(assigns) && !show_trips_input?(assigns)}
            label={if show_stops_input?(assigns), do: "Stops", else: "Direction"}
            field={@form[:direction]}
            options={@direction_options}
            disabled={disable_stop_input?(@form[:route_ids].value)}
            prompt={if disable_stop_input?(@form[:route_ids].value), do: "", else: "Both Directions"}
          />
          <.filtered_select
            :if={show_stops_input?(assigns)}
            label={if show_trips_input?(assigns), do: "Stops", else: nil}
            field={@form[:stop_ids]}
            filter_field={@form[:stop_ids_filter]}
            options={@stop_id_options}
            loading={Map.get(@available_stops, :loading, true)}
            no_results={
              Enum.empty?(@stop_id_options) && !disable_stop_input?(@form[:route_ids].value)
            }
            class={
              "min-w-[100%] " <>
              if(not show_trips_input?(assigns), do: "min-h-[90%]", else: "min-h-full")
            }
            disabled={disable_stop_input?(@form[:route_ids].value)}
            prompt={
              if disable_stop_input?(@form[:route_ids].value),
                do: nil,
                else: "All Stops"
            }
          />
        </div>
      </.form>
      <hr class="mt-4" />
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

  defp async_available?(assigns, key) do
    Map.get(assigns, key) && Map.get(assigns[key], :result) && assigns[key].ok? &&
      assigns[key].result
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
  defp disable_stop_input?(nil), do: true
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
