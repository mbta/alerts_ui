defmodule AlertsUIWeb.FormComponents.AffectedService do
  @moduledoc """
    Live Component for affected service section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUI.Models.ActivePeriod
  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertLive

  alias AlertsUIWeb.FormComponents.Helpers.{
    ContentFormatter,
    ErrorFormatter,
    Helpers,
    SelectFormatter,
    ServiceEffectCombinations
  }

  alias MBTAV3API.Routes.Route

  @primary_key false
  embedded_schema do
    field :route_ids, {:array, :string}
    field :single_route_id, :string
    field :route_search_term, :string
    field :direction, :string
    field :trip_ids, {:array, :string}
    field :trip_search_term, :string
    field :stop_ids, {:array, :string}
    field :stop_search_term, :string
    field :trip_information_by_id, {:map, :map}
    field :modal_date, :string
    field :modal_date_search_term, :string
  end

  @fields ~w[route_ids direction trip_ids stop_ids trip_information_by_id route_search_term trip_search_term stop_search_term single_route_id modal_date modal_date_search_term]a

  @impl true
  def mount(socket) do
    service_dates =
      Enum.to_list(0..6)
      |> Enum.map(fn x ->
        DateTime.now!("America/New_York")
        |> ActivePeriod.datetime_to_service_date()
        |> Date.add(x)
      end)
      |> Enum.map(fn date ->
        {Timex.format!(date, "{WDfull} {M}/{0D}"), Date.to_iso8601(date)}
      end)

    today = hd(service_dates) |> elem(1)

    changeset = changeset(%__MODULE__{}, %{modal_date: today})

    socket =
      socket
      |> assign(%{
        form: to_form(changeset),
        button_selected_routes: [],
        available_routes: %{},
        available_schedules: %{},
        available_stops: %{},
        today: today,
        service_dates: service_dates,
        modal_date: today,
        modal_options: service_dates,
        filter_title_value: service_dates |> Enum.map(fn {option, _value} -> option end) |> hd,
        modal_date_filter: ""
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
      if Map.get(alert_data, :trip_information_by_id) do
        alert_data.trip_information_by_id
      else
        available_schedules =
          CreateAlertLive.get_schedules_by_date(
            alert_data.route_ids,
            alert_data.direction,
            nil
          )

        trip_information_by_id(
          available_schedules,
          Map.get(alert_data, :trip_ids, [])
        )
      end

    params =
      socket.assigns.form.params |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)

    alert_data =
      Map.put(alert_data, :trip_information_by_id, trip_information_by_id)
      |> Map.put(:modal_date, nil)
      |> Map.merge(params)

    changeset =
      %__MODULE__{}
      |> changeset(alert_data)

    changes =
      changeset
      |> apply_action!(:validate)

    assigns =
      assigns
      |> Map.put(:modal_date, nil)

    send(self(), {:section_completed, changes})

    route_types = all_route_types(route_type)

    direction = alert_data.direction
    route_ids = alert_data.route_ids
    required_fields = ServiceEffectCombinations.required_fields(assigns.combination)

    socket =
      socket
      |> assign(assigns)
      |> assign(:form, changeset |> to_form())
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
  def update(%{submitted: true}, socket) do
    form_params =
      Map.update(socket.assigns.form.params, "route_ids", nil, fn route_ids ->
        if is_nil(route_ids) or Enum.empty?(route_ids), do: nil, else: route_ids
      end)

    changeset =
      %__MODULE__{}
      |> changeset(form_params)
      |> validate_required(ServiceEffectCombinations.required_fields(socket.assigns.combination))

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

    {:ok, assign(socket, form: form)}
  end

  @impl true
  def update(
        %{route_type: route_type, alert_data: alert_data} = assigns,
        socket
      ) do
    route_types = all_route_types(route_type)

    # make sure initial errors get sent up to create_alert_live even if no events fire
    # For other form components, this is done in the mount, but we can't do that here
    # because assigns won't be populated yet, and that's how we get the required_fields
    changeset = changeset(%__MODULE__{}, Map.merge(alert_data, socket.assigns))

    case apply_action(
           changeset
           |> validate_required(ServiceEffectCombinations.required_fields(assigns.combination)),
           :validate
         ) do
      {:ok, _changeset} ->
        send(self(), {:add_errors, [], __MODULE__})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
    end

    # don't re-fetch routes if we already have them- prevents weird unselect render error
    socket =
      if socket.assigns.available_routes === %{} do
        socket
        |> assign_async(:available_routes, fn ->
          {:ok, %{available_routes: CreateAlertLive.get_routes(route_types)}}
        end)
      else
        socket
      end
      |> assign(assigns)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"affected_service" => affected_service}, socket) do
    affected_service =
      affected_service
      |> Map.put_new("direction", "default")
      |> clean_route_ids(socket.assigns.form, socket.assigns.effect_name)
      |> adjust_selections()
      # Stops / trips have default values, but all other empty lists among the fields
      # should be omitted. That means they have been deselected
      |> Helpers.filter_empty_list_fields()
      |> populate_default_stops()
      |> populate_default_trips()

    changeset = validate(affected_service, socket.assigns)

    # If we validate before the apply, the apply will fail. Validate separately
    case apply_action(changeset, :validate) do
      {:ok, changeset} ->
        available_schedules =
          Map.get(socket.assigns.available_schedules, :result)

        selected_schedules =
          if available_schedules do
            available_schedules
            |> Enum.filter(&(&1.trip.id in affected_service["trip_ids"]))
          else
            nil
          end

        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changeset})
        send(self(), {:selected_schedules, selected_schedules})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
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
      # If any of the selections were adjusted server-side, push those changes back
      # to the client
      |> push_event("adjustSelections", affected_service)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("accepted_dates_modal", _params, socket) do
    params = socket.assigns.form.params

    modal_date =
      if params["modal_date"] in [nil, "", "default"] do
        nil
      else
        params["modal_date"]
      end

    required_fields = ServiceEffectCombinations.required_fields(socket.assigns.combination)

    {filter_title_value, _} =
      socket.assigns.modal_options
      |> Enum.find({"All future trips", nil}, fn {_option, value} ->
        value == modal_date
      end)

    socket =
      socket
      |> assign(modal_date: modal_date, filter_title_value: filter_title_value)
      |> assign_schedules(params["route_ids"], params["direction"], required_fields)

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancelled_modal", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filter", %{"filter-id" => "dates-filter-modal"}, socket) do
    params = socket.assigns.form.params

    default_filter_title =
      socket.assigns.service_dates |> Enum.map(fn {option, _value} -> option end) |> hd

    required_fields = ServiceEffectCombinations.required_fields(socket.assigns.combination)

    socket =
      socket
      |> assign(modal_date: socket.assigns.today, filter_title_value: default_filter_title)
      |> assign_schedules(params["route_ids"], params["direction"], required_fields)

    {:noreply, socket}
  end

  def validate(affected_service, assigns) do
    trip_information_by_id =
      if Helpers.async_available?(assigns, :available_schedules) do
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

  def clean_route_ids(affected_service, form, "Detour") do
    # if it's a detour alert, we need to set route_ids to equal the single_route_id
    # from the form, so we don't have to worry about whether it's a list
    # elsewhere
    incoming_route_id = Map.get(affected_service, "single_route_id")

    incoming_route_ids =
      if incoming_route_id do
        List.wrap(incoming_route_id)
      else
        form.params["route_ids"] || []
      end

    affected_service
    |> Map.put("route_ids", incoming_route_ids)
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

  # If the user tries ctrl-click "All Trips" while individual trips are already selected,
  # the select-all shouldn't work. But the client isn't smart enough to know that
  # on its own. Here, we update the server-side data, and later we push it to the client
  @spec adjust_selections(map()) :: map()
  def adjust_selections(affected_service) do
    Enum.reduce(affected_service, %{}, fn {k, v}, acc -> Map.put(acc, k, adjust_select_all(v)) end)
  end

  def adjust_select_all(["default" | others]), do: others
  def adjust_select_all(keep_all), do: keep_all

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
      service_date = socket.assigns.modal_date

      assign_async(socket, [:available_schedules], fn ->
        {:ok,
         %{
           available_schedules:
             CreateAlertLive.get_schedules_by_date(
               route_ids,
               direction,
               service_date
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
    route_search_term = assigns.form[:route_search_term].value

    route_id_options =
      SelectFormatter.formatted_select_options(%SelectFormatter{
        options: Map.get(assigns.available_routes, :result, []) || [],
        search_term: route_search_term,
        route_type: assigns.route_type,
        values_to_keep: route_ids
      })

    direction_names_map =
      if Helpers.async_available?(assigns, :available_routes) do
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
    trip_search_term = assigns.form[:trip_search_term].value

    trip_id_options =
      if Helpers.async_available?(assigns, :available_schedules) do
        SelectFormatter.formatted_select_options(%SelectFormatter{
          schedules_by_route_name: get_schedules_by_route_type(assigns),
          route_type: assigns.route_type,
          search_term: trip_search_term,
          values_to_keep: trip_ids
        })
      else
        []
      end

    stop_ids = assigns.form[:stop_ids].value || []
    stop_search_term = assigns.form[:stop_search_term].value

    stop_id_options =
      SelectFormatter.formatted_select_options(%SelectFormatter{
        options: Map.get(assigns.available_stops, :result, []) || [],
        search_term: stop_search_term,
        route_type: assigns.route_type,
        values_to_keep: stop_ids
      })

    modal_options =
      filter_modal_options(
        assigns.modal_options,
        assigns.form[:modal_date_filter].value,
        assigns.form[:modal_date].value
      )

    assigns =
      assign(assigns,
        route_id_options: route_id_options,
        direction_options: direction_options,
        trip_id_options: trip_id_options,
        stop_id_options: stop_id_options,
        modal_options: modal_options,
        service_type_name: assigns.route_type |> InformedEntity.route_code_mapping() || nil
      )

    ~H"""
    <div class="min-w-[100%] self-start flex flex-col" id="service_view">
      <.h1 class="!mb-0">Create new alert</.h1>
      <.p>
        {ContentFormatter.route_atom_to_string(@service_type_name)} • {@effect_name || ""}
      </.p>
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Affected service
      </.h5>
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class={["form-control flex flex-row mb-4", @route_type !== 2 && "min-h-[32rem]"]}
        id="service_form"
      >
        <div class="w-[25%] mr-8">
          <.filtered_select
            label={if @route_type in [0, 1, 2], do: "Lines", else: "Routes"}
            field={if @effect_name == "Detour", do: @form[:single_route_id], else: @form[:route_ids]}
            filter_field={@form[:route_search_term]}
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

        <.modal
          :if={show_trips_input?(assigns)}
          id="dates-filter-modal"
          header_text="Filter by day"
          cancel_event_name="cancelled_modal"
          accept_event_name="accepted_dates_modal"
          accept_button_text="Apply"
          target_id="#service_form"
        >
          <.filtered_select
            label="Upcoming dates"
            field={@form[:modal_date]}
            filter_field={@form[:modal_date_search_term]}
            options={@modal_options}
            class="h-[32rem]"
            prompt="All future trips"
            multiple={false}
          />
        </.modal>
        <div :if={show_trips_input?(assigns)} class="flex flex-col justify-start w-[25%] mr-8">
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
            modal_filter_id="dates-filter-modal"
            modal_filter_title={"Filter: #{@filter_title_value}"}
            modal_filter_active={date_filter_active?(@modal_date, @today)}
            options={@direction_options}
            disabled={disable_stop_input?(@form[:route_ids].value)}
            modal_filter_disabled={@form[:route_ids].value in [nil, []]}
            prompt={if disable_stop_input?(@form[:route_ids].value), do: "", else: "Both Directions"}
            target_id="#service_form"
          />
          <.filtered_select
            field={@form[:trip_ids]}
            filter_field={@form[:trip_search_term]}
            options={@trip_id_options}
            loading={Map.get(@available_schedules, :loading, true)}
            no_results={
              Enum.empty?(@trip_id_options) && !disable_trip_input?(@form[:route_ids].value)
            }
            class="min-w-[100%] h-full"
            disabled={disable_trip_input?(@form[:route_ids].value)}
            prompt={if disable_trip_input?(@form[:route_ids].value), do: nil, else: "All Trips"}
            hook="SelectAllAdjuster"
          />
        </div>
        <div class="flex flex-col justify-start w-[25%]">
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
            filter_field={@form[:stop_search_term]}
            options={@stop_id_options}
            loading={Map.get(@available_stops, :loading, true)}
            no_results={
              Enum.empty?(@stop_id_options) && !disable_stop_input?(@form[:route_ids].value)
            }
            class="min-w-[100%] h-full"
            disabled={disable_stop_input?(@form[:route_ids].value)}
            prompt={
              if disable_stop_input?(@form[:route_ids].value),
                do: nil,
                else: "All Stops"
            }
            hook="SelectAllAdjuster"
          />
        </div>
      </.form>
      <hr class="mt-4" />
    </div>
    """
  end

  defp date_filter_active?(filter_value, today) when filter_value == today, do: false
  defp date_filter_active?(_, _), do: true

  defp icon_type(route_type) do
    case route_type do
      2 -> :commuter_rail
      4 -> :ferry
      _ -> nil
    end
  end

  defp filter_modal_options(modal_options, modal_date_filter, modal_date_value) do
    modal_options
    |> Enum.filter(fn {option, value} ->
      filter_value = modal_date_filter || ""

      (option || "")
      |> String.downcase()
      |> String.contains?(filter_value) || value == modal_date_value
    end)
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

  # Each of these are only used once in the validation flow... what exactly should we do here?
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

  defp get_schedules_by_route_type(assigns) do
    assigns.available_schedules.result
    |> Enum.filter(fn schedule ->
      # If a line was selected and deselected, value here may be set to nil
      schedule.route.id in (assigns.form[:route_ids].value || [])
    end)
    |> Enum.group_by(&SelectFormatter.name_for_option(&1.route))
  end
end
