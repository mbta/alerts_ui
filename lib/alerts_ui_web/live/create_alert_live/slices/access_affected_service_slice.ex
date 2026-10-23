defmodule AlertsUIWeb.CreateAlertLive.Slices.AccessAffectedServiceSlice do
  @moduledoc """
  Slice that handles facility selection for accessibility alerts (elevator/escalator
  closures). Asynchronously loads facilities filtered by stop, and renders the
  facility picker with an optional stop-filter modal.
  """

  alias AlertsUIWeb.CreateAlertHelpers
  alias AlertsUIWeb.CreateAlertLive.AlertData
  alias AlertsUIWeb.CreateAlertLive.Helpers.SelectFormatter
  alias AlertsUIWeb.CreateAlertLive.Slice

  import AlertsUIWeb.CreateAlertLive.Helpers.AlertDataHelpers,
    only: [get_single_facility_effect_names: 0, humanize_effect_name: 1, facility_types: 1]

  import AlertsUIWeb.CreateAlertLive.Helpers.Validation,
    only: [always_validate_required: 3]

  import Ecto.Changeset, only: [get_field: 2, cast: 3]
  import Phoenix.LiveView, only: [start_async: 3]

  use AlertsUIWeb, :html

  defstruct [
    :facility_ids,
    :facility_search_term,
    :single_facility_id,
    :stop_id,
    :stop_search_term
  ]

  defmodule Selections do
    @moduledoc "Holds async-loaded facility and stop option lists for `AccessAffectedServiceSlice`."

    alias AlertsUIWeb.CreateAlertLive.Slices.AccessAffectedServiceSlice

    defstruct available_facilities: [],
              facility_id_options: [],
              filter_title_value: "All stops",
              loading: false,
              modal_stop_id_options: [],
              on_filter_accept: &AccessAffectedServiceSlice.on_filter_accept/1,
              on_filter_clear: &AccessAffectedServiceSlice.on_filter_clear/1,
              stop_id_filter_value: "default"
  end

  defimpl Slice, for: __MODULE__ do
    alias AlertsUIWeb.CreateAlertLive.Slices.AccessAffectedServiceSlice

    def mount(_service_data, socket, _base_params) do
      socket
    end

    def extract(service_data, %AlertData{} = _alert_data, _params) do
      service_data
    end

    def transform(_service_data, changeset, _params, _socket) do
      AccessAffectedServiceSlice.ensure_facility_ids(changeset)
    end

    def validate(_service_data, changeset, _params, socket) do
      if socket.assigns.submitted? do
        AccessAffectedServiceSlice.validate_changeset(changeset)
      else
        changeset
      end
    end

    def assigns(_service_data, socket, params) do
      AccessAffectedServiceSlice.async_assign_selections(socket, params)
    end
  end

  def single_facility_effect?(changeset) do
    effect_name = get_field(changeset, :effect_name)

    normalized_single_facility_effects =
      Enum.map(get_single_facility_effect_names(), fn name ->
        name |> String.split(" ") |> Enum.map_join("_", &String.downcase/1)
      end)

    effect_name in normalized_single_facility_effects
  end

  def ensure_facility_ids(changeset) do
    if single_facility_effect?(changeset) do
      case get_field(changeset, :single_facility_id) do
        nil -> changeset
        id -> cast(changeset, %{facility_ids: [id]}, [:facility_ids])
      end
    else
      changeset
    end
  end

  def validate_changeset(changeset) do
    if single_facility_effect?(changeset) do
      always_validate_required(changeset, :single_facility_id, "You must select a facility")
    else
      always_validate_required(changeset, :facility_ids, "You must select a facility")
    end
  end

  def async_assign_selections(%{assigns: %{}} = socket, params) do
    if update_selections?(params) do
      update_selections(socket, params)
    else
      case Map.get(socket.assigns, :selections) do
        nil ->
          assign(socket, :selections, %Selections{})

        _ ->
          socket
      end
    end
  end

  def async_assign_selections(socket, _params), do: socket

  defp update_selections(
         socket,
         %{"_target" => ["alert_data", "stop_search_term"]}
       ) do
    prev = prev(Map.get(socket.assigns, :selections))

    modal_stop_id_options =
      modal_stop_id_options(
        prev.available_facilities,
        socket.assigns.form
      )

    socket
    |> assign(:selections, %{prev | modal_stop_id_options: modal_stop_id_options})
  end

  defp update_selections(
         socket,
         %{"_target" => ["alert_data", "facility_search_term"]}
       ) do
    prev = prev(Map.get(socket.assigns, :selections))

    facility_id_options = facility_id_options(prev.available_facilities, socket.assigns.form)

    socket
    |> assign(:selections, %{prev | facility_id_options: facility_id_options})
  end

  defp update_selections(%{assigns: %{} = assigns} = socket, _params) do
    prev = prev(Map.get(socket.assigns, :selections))

    form = assigns.form

    facility_types = facility_types(form[:effect_name].value)

    socket
    |> assign(:selections, %{prev | loading: true})
    |> start_async(:fetch_selections, fn ->
      available_facilities =
        CreateAlertHelpers.get_facilities(facility_types)

      modal_stop_id_options = modal_stop_id_options(available_facilities, form)

      facility_id_options = facility_id_options(available_facilities, form)

      %Selections{
        available_facilities: available_facilities,
        modal_stop_id_options: modal_stop_id_options,
        facility_id_options: facility_id_options
      }
    end)
  end

  @update_selection_targets ["stop_id", "stop_search_term", "facility_search_term"]
  defp update_selections?(%{"_target" => ["alert_data", field]})
       when field in @update_selection_targets,
       do: true

  defp update_selections?(%{"_target" => _target}), do: false
  defp update_selections?(_), do: true

  defp modal_stop_id_options(available_facilities, form) do
    SelectFormatter.formatted_select_options(%SelectFormatter{
      options: Map.get(available_facilities, :stops) || [],
      search_term: form[:stop_search_term].value,
      values_to_keep: form[:stop_id].value |> List.wrap(),
      option_prefix: "stop-filter"
    })
  end

  defp facility_id_options(available_facilities, form) do
    facility_ids = form[:facility_ids].value || []

    filtered_facilities =
      available_facilities.facilities
      |> Enum.filter(
        &filter_facility_by_stop_ids(
          &1,
          form[:stop_id].value || "default",
          facility_ids
        )
      )

    SelectFormatter.formatted_select_options(%SelectFormatter{
      options: filtered_facilities,
      search_term: form[:facility_search_term].value,
      values_to_keep: facility_ids,
      option_prefix: "facility-filter"
    })
  end

  defp prev(%Selections{} = selections), do: selections
  defp prev(_), do: %Selections{}

  defp filter_facility_by_stop_ids(facility, stop_id_filter_value, selected_facility_ids) do
    equals_stop_id =
      if stop_id_filter_value === "default" do
        true
      else
        facility.stop.id === stop_id_filter_value
      end

    equals_stop_id or facility.id in selected_facility_ids
  end

  def on_filter_accept(socket) do
    selections = socket.assigns.selections
    selected_stop_id = socket.assigns.form[:stop_id].value
    stops = selections.available_facilities.stops

    filter_title_value =
      if selected_stop_id in [nil, "", "default"] or Enum.empty?(stops) do
        "All stops"
      else
        Enum.filter(stops, &(&1.id === selected_stop_id))
        |> Enum.map(& &1.name)
        |> hd
      end

    selections = %{
      selections
      | stop_id_filter_value: selected_stop_id,
        filter_title_value: filter_title_value
    }

    assign(socket, :selections, selections)
  end

  def on_filter_clear(socket) do
    {_, socket} =
      AlertData.sync(socket.assigns.form.source, socket, %{
        "alert_data" => %{"stop_id" => nil}
      })

    async_assign_selections(socket, %{})
  end

  def render(assigns) do
    ~H"""
    <div class="min-w-full flex flex-col" id="access_service_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Affected service
      </.h5>
      <fieldset class="flex flex-row">
        <.modal
          id="stops-filter-modal"
          header_text="Filter by stop"
          cancel_event_name="cancel_filter"
          accept_event_name="accept_filter"
          accept_button_text="Apply"
          target_id="#alert_form"
          container_class="md:!w-[25rem]"
        >
          <.filtered_select
            label="Stops"
            field={@form[:stop_id]}
            filter_field={@form[:stop_search_term]}
            options={@selections.modal_stop_id_options}
            loading={@selections.loading && @first_async_load}
            no_results={Enum.empty?(@selections.modal_stop_id_options)}
            prompt="All Stops"
            multiple={false}
            class="h-[32rem]"
          />
        </.modal>
        <.filtered_select
          class="md:w-[25%] h-[32rem]"
          field={
            if humanize_effect_name(@form) in get_single_facility_effect_names(),
              do: @form[:single_facility_id],
              else: @form[:facility_ids]
          }
          filter_field={@form[:facility_search_term]}
          label="Facilities"
          loading={@selections.loading && @first_async_load}
          modal_filter_active={filter_active?(@selections.stop_id_filter_value)}
          modal_filter_id="stops-filter-modal"
          modal_filter_title={"Filter: #{@selections.filter_title_value}"}
          multiple={humanize_effect_name(@form) not in get_single_facility_effect_names()}
          no_results={Enum.empty?(@selections.facility_id_options)}
          options={@selections.facility_id_options}
        />
      </fieldset>
      <p :if={@show_stop_ids} class="mt-2">
        Selected facility ids: {(@form[:facility_ids].value || []) |> Enum.join(", ")}
      </p>
      <hr class="mt-8" />
    </div>
    """
  end

  defp filter_active?(filter_value) when filter_value in ["", nil, "default"], do: false
  defp filter_active?(_), do: true
end
