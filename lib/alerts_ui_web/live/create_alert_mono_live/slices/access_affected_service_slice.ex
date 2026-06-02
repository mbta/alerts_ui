defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.AccessAffectedServiceSlice do
  @moduledoc """
  Slice that handles facility selection for accessibility alerts (elevator/escalator
  closures). Asynchronously loads facilities filtered by stop, and renders the
  facility picker with an optional stop-filter modal.
  """

  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertLive
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.FormComponents.Helpers.SelectFormatter

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertData,
    only: [get_single_facility_effect_names: 0]

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.Validation,
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

    alias AlertsUIWeb.CreateAlertMonoLive.Slices.AccessAffectedServiceSlice

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
    alias AlertsUIWeb.CreateAlertMonoLive.Slices.AccessAffectedServiceSlice

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
        always_validate_required(changeset, :facility_ids, "You must select a facility")
      else
        changeset
      end
    end

    def assigns(_service_data, socket, params) do
      AccessAffectedServiceSlice.async_assign_selections(socket, params)
    end
  end

  def ensure_facility_ids(changeset) do
    effect_name = get_field(changeset, :effect_name)

    normalized_single_facility_effects =
      Enum.map(get_single_facility_effect_names(), fn name ->
        name |> String.split(" ") |> Enum.map(&String.downcase/1) |> Enum.join("_")
      end)

    if effect_name in normalized_single_facility_effects do
      case get_field(changeset, :single_facility_id) do
        nil -> changeset
        id -> cast(changeset, %{facility_ids: [id]}, [:facility_ids])
      end
    else
      changeset
    end
  end

  def async_assign_selections(socket, params) do
    if update_selections?(params) do
      prev =
        case Map.get(socket.assigns, :selections) do
          %Selections{} = s -> s
          _ -> %Selections{}
        end

      form = socket.assigns.form

      facility_ids = form[:facility_ids].value || []
      facility_search_term = form[:facility_search_term].value

      facility_types =
        form[:effect_name].value
        |> effect_to_lookup_key()
        |> InformedEntity.facility_effect_to_types()

      stop_search_term = form[:stop_search_term].value
      stop_id = form[:stop_id].value

      socket
      |> assign(:selections, %{prev | loading: true})
      |> start_async(:fetch_selections, fn ->
        available_facilities =
          CreateAlertLive.get_facilities(facility_types)

        modal_stop_id_options =
          SelectFormatter.formatted_select_options(%SelectFormatter{
            options: Map.get(available_facilities, :stops) || [],
            search_term: stop_search_term,
            values_to_keep: stop_id |> List.wrap(),
            option_prefix: "stop-filter"
          })

        filtered_facilities =
          available_facilities.facilities
          |> Enum.filter(
            &filter_facility_by_stop_ids(
              &1,
              stop_id || "default",
              facility_ids
            )
          )

        facility_id_options =
          SelectFormatter.formatted_select_options(%SelectFormatter{
            options: filtered_facilities,
            search_term: facility_search_term,
            values_to_keep: facility_ids,
            option_prefix: "facility-filter"
          })

        %Selections{
          available_facilities: available_facilities,
          modal_stop_id_options: modal_stop_id_options,
          facility_id_options: facility_id_options
        }
      end)
    else
      case Map.get(socket.assigns, :selections) do
        nil ->
          assign(socket, :selections, %Selections{})

        _ ->
          socket
      end
    end
  end

  @update_selection_targets ["stop_id", "stop_search_term", "facility_search_term"]
  defp update_selections?(%{"_target" => ["alert_data", field]})
       when field in @update_selection_targets,
       do: true

  defp update_selections?(%{"_target" => _target}), do: false
  defp update_selections?(_), do: true

  defp filter_facility_by_stop_ids(facility, stop_id_filter_value, selected_facility_ids) do
    equals_stop_id =
      if stop_id_filter_value === "default" do
        true
      else
        facility.stop.id === stop_id_filter_value
      end

    equals_stop_id or facility.id in selected_facility_ids
  end

  defp effect_to_lookup_key(nil), do: nil

  defp effect_to_lookup_key(string) do
    string
    |> String.upcase()
    |> String.replace(" ", "_")
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
    case AlertData.sync(socket.assigns.form.source, socket, %{
           "alert_data" => %{"stop_id" => nil}
         }) do
      {:ok, socket} -> async_assign_selections(socket, %{})
      {:error, socket} -> async_assign_selections(socket, %{})
    end
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
            loading={@selections.loading}
            no_results={Enum.empty?(@selections.modal_stop_id_options)}
            prompt="All Stops"
            multiple={false}
            class="h-[32rem]"
          />
        </.modal>
        <.filtered_select
          class="md:w-[25%] h-[32rem]"
          field={
            if @form[:effect_name].value in get_single_facility_effect_names(),
              do: @form[:single_facility_id],
              else: @form[:facility_ids]
          }
          filter_field={@form[:facility_search_term]}
          label="Facilities"
          loading={@selections.loading}
          modal_filter_active={filter_active?(@selections.stop_id_filter_value)}
          modal_filter_id="stops-filter-modal"
          modal_filter_title={"Filter: #{@selections.filter_title_value}"}
          multiple={@form[:effect_name].value not in get_single_facility_effect_names()}
          no_results={Enum.empty?(@selections.facility_id_options)}
          options={@selections.facility_id_options}
        />
      </fieldset>
      <hr class="mt-8" />
    </div>
    """
  end

  defp filter_active?(filter_value) when filter_value in ["", nil, "default"], do: false
  defp filter_active?(_), do: true
end
