defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.BusDetourServiceSlice do
  @moduledoc """
  Slice that manages affected-service selection for bus detour alerts
  """

  use AlertsUIWeb, :html
  alias AlertsUI.Alerts
  alias AlertsUI.SkateDetours.GetDetours
  alias AlertsUIWeb.CreateAlertLive
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.FormComponents.Helpers.SelectFormatter

  alias Ecto.Changeset

  import Phoenix.LiveView, only: [push_event: 3, start_async: 3]

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.Validation,
    only: [always_validate_required: 3]

  defstruct [
    :direction,
    :route_search_term,
    :skate_search_term,
    :single_route_id,
    :stop_names_and_ids,
    :stop_search_term,
    :form_type,
    :skate_detour_id
  ]

  defmodule Selections do
    @moduledoc "Holds async-loaded route, and stop lists for `BusDetourServiceSlice`."

    alias AlertsUIWeb.CreateAlertMonoLive.Slices.BusDetourServiceSlice

    defstruct available_routes: [],
              available_stops: [],
              direction_options: [],
              filter_title_value: nil,
              loading: false,
              on_filter_accept: &BusDetourServiceSlice.on_filter_accept/1,
              on_filter_clear: &BusDetourServiceSlice.on_filter_clear/1,
              route_id_options: [],
              selected_stops: [],
              stop_id_options: []
  end

  defimpl Slice, for: __MODULE__ do
    alias AlertsUI.SkateDetours.GetDetours
    alias AlertsUIWeb.CreateAlertMonoLive.Slices.BusDetourServiceSlice
    alias AlertsUIWeb.CreateAlertMonoLive.Slices.BusDetourServiceSlice.Selections

    def mount(_service_data, socket, _base_params) do
      assign(
        socket,
        :selections,
        %Selections{}
      )
    end

    def extract(service_data, _alert_data, _params) do
      service_data
    end

    def transform(_service_data, changeset, params, socket) do
      changeset
      |> BusDetourServiceSlice.apply_detour(socket, params)
      |> BusDetourServiceSlice.transform_changeset(params)
    end

    def validate(_service_data, changeset, _params, socket) do
      if socket.assigns.submitted? do
        BusDetourServiceSlice.validate_changeset(changeset)
      else
        changeset
      end
    end

    def assigns(_service_data, socket, params) do
      socket =
        socket
        |> BusDetourServiceSlice.clear_stops_touched_on_route_change(params)
        |> BusDetourServiceSlice.async_assign_selections(params)

      # only grab detours once
      socket =
        if is_nil(socket.assigns.skate_detours.loading) do
          BusDetourServiceSlice.async_assign_detours(socket, params)
        else
          socket
        end

      # We do not want to let the user select both "All stops" and an individual stop
      # We push the data to the client (hooks.js) to filter for us
      maybe_needs_adjusting = %{
        stop_names_and_ids: socket.assigns.form[:stop_names_and_ids].value
      }

      push_event(socket, "adjustSelections", maybe_needs_adjusting)
    end
  end

  def apply_detour(changeset, socket, %{"_target" => ["alert_data", "skate_detour_id"]}) do
    detours = socket.assigns.skate_detours.result || []
    skate_detour_id = Changeset.get_field(changeset, :skate_detour_id)
    skate_detour = Enum.find(detours, &(&1.id == skate_detour_id))

    stops =
      socket.assigns.selections.available_stops
      |> Enum.filter(&(&1.id in skate_detour.missed_stops))
      |> Enum.map(&SelectFormatter.id_for_option(&1, true))

    changeset
    |> Changeset.cast(%{direction: Integer.to_string(skate_detour.direction_id)}, [:direction])
    |> Changeset.cast(%{stop_names_and_ids: stops}, [:stop_names_and_ids])
  end

  def apply_detour(changeset, _socket, _params) do
    changeset
  end

  def transform_changeset(changeset, params) do
    changeset
    |> ensure_default_direction()
    |> ensure_route_ids()
    |> clear_selections_on_change(params)
    |> ensure_stop_names_and_ids()
    |> filter_stops_by_direction()
    |> split_stop_names_and_ids()
  end

  def validate_changeset(changeset) do
    changeset
    |> always_validate_required(:single_route_id, "You must select a route")
  end

  # Changing the route clears the stop selection (see clear_selections_on_change/2),
  # so a prior blur on the old selection shouldn't keep validating the new one live
  def clear_stops_touched_on_route_change(socket, %{"_target" => ["alert_data", _field]}) do
    assign(socket, :stops_touched?, false)
  end

  def clear_stops_touched_on_route_change(socket, _params), do: socket

  def async_assign_selections(%{assigns: %{} = assigns} = socket, params) do
    if update_selections?(params) do
      update_selections(socket, params)
    else
      dont_update_selections(Map.get(assigns, :selections), socket)
    end
  end

  def async_assign_selections(socket, _params), do: socket

  def async_assign_detours(socket, params) do
    single_route_id = params["alert_data"]["single_route_id"]

    Phoenix.LiveView.assign_async(socket, [:skate_detours], fn ->
      detours = GetDetours.get_detours() |> Enum.filter(&(&1.route_id == single_route_id))
      used_detour_ids = Alerts.get_matching_skate_ids(Enum.map(detours, & &1.id))

      detours = Enum.reject(detours, &(&1.id in used_detour_ids))

      {:ok,
       %{
         skate_detours: detours
       }}
    end)
  end

  defp update_selections(
         socket,
         %{"_target" => ["alert_data", "route_search_term"]}
       ) do
    prev = prev(Map.get(socket.assigns, :selections))
    form = socket.assigns.form

    route_id_options = route_id_options(prev.available_routes, form)

    socket
    |> assign(:selections, %{prev | route_id_options: route_id_options})
  end

  defp update_selections(
         socket,
         %{"_target" => ["alert_data", "stop_search_term"]}
       ) do
    prev = prev(Map.get(socket.assigns, :selections))
    form = socket.assigns.form

    stop_id_options = stop_id_options(prev.available_stops, form)

    socket
    |> assign(:selections, %{prev | stop_id_options: stop_id_options})
  end

  defp update_selections(socket, _params) do
    prev = prev(Map.get(socket.assigns, :selections))
    form = socket.assigns.form

    direction = form[:direction].value
    route_ids = form[:route_ids].value || []
    route_type = form[:route_type].value

    socket
    |> assign(:selections, %{prev | loading: true})
    |> start_async(:fetch_selections, fn ->
      available_routes = CreateAlertLive.get_routes([3])

      available_stops =
        CreateAlertLive.get_stops(
          route_ids,
          route_type,
          direction
        )

      direction_options =
        SelectFormatter.formatted_direction_options(
          route_ids,
          Map.new(available_routes, &{&1.id, &1.direction_names})
        )

      route_id_options = route_id_options(available_routes, form)

      stop_id_options = stop_id_options(available_stops, form)

      %Selections{
        available_routes: available_routes,
        available_stops: available_stops,
        direction_options: direction_options,
        route_id_options: route_id_options,
        stop_id_options: stop_id_options
      }
    end)
  end

  defp route_id_options(
         available_routes,
         form
       ) do
    SelectFormatter.formatted_select_options(%SelectFormatter{
      options: available_routes,
      search_term: form[:route_search_term].value,
      route_type: form[:route_type].value,
      values_to_keep: form[:route_ids].value || [],
      option_prefix: "route-selector"
    })
  end

  defp stop_id_options(available_stops, form) do
    SelectFormatter.formatted_select_options(
      %SelectFormatter{
        options: available_stops,
        search_term: form[:stop_search_term].value,
        route_type: form[:route_type].value,
        values_to_keep: form[:stop_names_and_ids].value || [],
        option_prefix: "stop-search"
      },
      true
    )
  end

  defp dont_update_selections(nil, socket), do: assign(socket, :selections, %Selections{})
  defp dont_update_selections(_selections, socket), do: socket

  defp prev(%Selections{} = selections), do: selections
  defp prev(_), do: %Selections{}

  @update_selection_targets [
    "direction",
    "stop_ids",
    "route_search_term",
    "single_route_id",
    "stop_search_term",
    "skate_search_term"
  ]

  # update selections when a user interacts with one of our fields...
  defp update_selections?(%{"_target" => ["alert_data", field]})
       when field in @update_selection_targets,
       do: true

  # ...but not on any other user interaction...
  defp update_selections?(%{"_target" => _target}), do: false
  # ...and always on mount, when there is no target
  defp update_selections?(_), do: true

  defp ensure_default_direction(changeset) do
    case Changeset.get_field(changeset, :direction) do
      nil -> Changeset.cast(changeset, %{direction: "default"}, [:direction])
      _ -> changeset
    end
  end

  defp ensure_route_ids(changeset) do
    case Changeset.get_field(changeset, :single_route_id) do
      nil -> Changeset.cast(changeset, %{route_ids: []}, [:route_ids])
      route_id -> Changeset.cast(changeset, %{route_ids: [route_id]}, [:route_ids])
    end
  end

  defp clear_selections_on_change(changeset, %{"_target" => _target}) do
    if Changeset.changed?(changeset, :route_ids) do
      Changeset.cast(
        changeset,
        %{
          stop_names_and_ids: [],
          stop_ids: [],
          skate_detour_id: nil
        },
        [
          :stop_names_and_ids,
          :stop_ids,
          :skate_detour_id
        ]
      )
    else
      changeset
    end
  end

  defp clear_selections_on_change(changeset, _params), do: changeset

  defp ensure_stop_names_and_ids(changeset) do
    stop_names_and_ids = Changeset.get_field(changeset, :stop_names_and_ids)

    cond do
      stop_names_and_ids in [nil, "default", ["default"]] ->
        Changeset.cast(changeset, %{stop_names_and_ids: []}, [:stop_names_and_ids])

      is_list(stop_names_and_ids) and "default" in stop_names_and_ids ->
        Changeset.cast(
          changeset,
          %{stop_names_and_ids: List.delete(stop_names_and_ids, "default")},
          [:stop_names_and_ids]
        )

      true ->
        changeset
    end
  end

  defp filter_stops_by_direction(changeset) do
    marker =
      case Changeset.get_field(changeset, :direction) do
        "0" -> ~r/inbound/
        "1" -> ~r/outbound/
        _ -> ~r/\A\Z/
      end

    stop_names_and_ids =
      changeset
      |> Changeset.get_field(:stop_names_and_ids)
      |> Enum.filter(&(!(&1 =~ marker)))

    Changeset.cast(
      changeset,
      %{stop_names_and_ids: stop_names_and_ids},
      [:stop_names_and_ids]
    )
  end

  defp split_stop_names_and_ids(changeset) do
    split_names_and_ids =
      Changeset.get_field(changeset, :stop_names_and_ids)
      |> Enum.reduce(%{stop_names: [], stop_ids: []}, fn name_and_id, acc ->
        case String.split(name_and_id, "|") do
          ["default"] ->
            acc

          [_, "default"] ->
            acc

          [stop_name, stop_id] ->
            %{stop_names: [stop_name | acc[:stop_names]], stop_ids: [stop_id | acc[:stop_ids]]}
        end
      end)

    Changeset.cast(changeset, split_names_and_ids, [:stop_names, :stop_ids])
  end

  def default_selections(selections \\ %Selections{}) do
    %{selections | loading: true}
  end

  defp build_detour_options(skate_detour_result, form) do
    skate_detours =
      if skate_detour_result.ok? do
        skate_detour_result.result
      else
        []
      end

    {outbound, inbound} = Enum.split_with(skate_detours, &(&1.direction_id == 0))

    [outbound_options, inbound_options] =
      Enum.map(
        [outbound, inbound],
        &SelectFormatter.formatted_select_options(%SelectFormatter{
          options: &1,
          search_term: form[:skate_search_term].value,
          route_type: 3,
          values_to_keep: form[:skate_detour_id].value || [],
          option_prefix: "detour-selector"
        })
      )

    if Enum.empty?(skate_detours) do
      []
    else
      %{
        Inbound: inbound_options,
        Outbound: outbound_options
      }
      |> Enum.reject(fn {_k, v} -> Enum.empty?(v) end)
    end
  end

  def render(assigns) do
    form = assigns.form

    disable_stop_input? = form[:route_ids].value == [] or !is_nil(form[:skate_detour_id].value)

    assigns =
      assign(assigns, %{
        skate_detour_options: build_detour_options(assigns.skate_detours, form),
        detours_loading?: assigns.skate_detours.loading,
        disable_stop_input?: disable_stop_input?
      })

    ~H"""
    <div class="min-w-full self-start flex flex-col" id="service_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Bus Detour affected service
      </.h5>
      <div class={[
        "flex flex-row flex-wrap min-h-[38rem] md:min-h-[32rem] gap-y-4",
        @form[:single_route_id].errors != [] && "mb-9",
        @form[:stop_names_and_ids].errors != [] && "mb-14 md:mb-16",
        @form[:single_route_id].errors === [] && @form[:stop_names_and_ids].errors === [] && "mb-4"
      ]}>
        <div class={[
          "md:mb-0 w-full md:w-[30%] md:mr-8",
          @form[:single_route_id].errors != [] && "mb-10"
        ]}>
          <.filtered_select
            label="Routes"
            field={@form[:single_route_id]}
            filter_field={@form[:route_search_term]}
            loading={@selections.loading && @first_async_load}
            no_results={Enum.empty?(@selections.route_id_options)}
            options={@selections.route_id_options}
            class="h-full"
            multiple={false}
          />
        </div>

        <div class="flex flex-col justify-start w-full md:w-[30%]">
          <.filtered_select
            label="Detours from Skate"
            field={@form[:skate_detour_id]}
            filter_field={@form[:skate_search_term]}
            options={
              if Enum.empty?(@skate_detour_options),
                do: ["No active detours in Skate"],
                else: @skate_detour_options
            }
            disabled={Enum.empty?(@skate_detour_options)}
            class="h-full mr-6"
            loading={@detours_loading?}
            multiple={false}
          />
        </div>

        <div class="flex flex-col justify-start w-full md:w-[30%]">
          <.select
            label="Stops"
            field={@form[:direction]}
            options={@selections.direction_options}
            disabled={@disable_stop_input?}
            prompt={if @disable_stop_input?, do: "", else: "Both Directions"}
          />
          <div
            id="stop_names_and_ids_selector_wrapper"
            class="contents"
            phx-hook="FocusOutPush"
            data-focusout-event="stop_selector_blur"
          >
            <.filtered_select
              field={@form[:stop_names_and_ids]}
              selected={@form[:stop_names_and_ids].value}
              filter_field={@form[:stop_search_term]}
              options={if @selections.loading, do: [], else: @selections.stop_id_options}
              loading={@selections.loading}
              no_results={
                Enum.empty?(@selections.stop_id_options) &&
                  !@disable_stop_input?
              }
              class="min-w-full h-full"
              disabled={@disable_stop_input?}
              prompt={
                if @disable_stop_input?,
                  do: nil,
                  else: "All Stops"
              }
            />
          </div>
        </div>
      </div>
      <div
        :if={@form[:skate_detour_id].value}
        class="p-2 rounded-sm max-w-[48rem] text-bold"
      >
        <p>
          <.icon name="hero-information-circle-solid" /> Selecting a detour from Skate will
          automatically:
        </p>
        <ul class="list-disc ml-8">
          <li>select a direction</li>
          <li>select missed stops</li>
          <li>
            set this alert to close when the detour is
            closed in Skate
          </li>
        </ul>
      </div>
      <p :if={@show_stop_ids}>
        Selected route ids: {(@form[:route_ids].value || []) |> Enum.join(", ")} Selected skate detour: {@form[
          :skate_detour_id
        ].value} Selected stop ids: {(@form[
                                        :stop_ids
                                      ].value ||
                                        [])
        |> Enum.join(", ")}
      </p>
      <hr class="mt-4" />
    </div>
    """
  end

  def on_filter_accept(socket) do
    async_assign_selections(socket, %{})
  end

  def on_filter_clear(socket) do
    {_, socket} =
      AlertData.sync(socket.assigns.form.source, socket, %{})

    async_assign_selections(socket, %{})
  end
end
