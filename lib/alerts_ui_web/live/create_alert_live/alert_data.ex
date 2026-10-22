defmodule AlertsUIWeb.CreateAlertLive.AlertData do
  @moduledoc """
  Alert data v2
  """
  alias AlertsUI.Models.Alert
  alias AlertsUI.Repo
  alias AlertsUIWeb.CreateAlertLive
  alias AlertsUIWeb.CreateAlertLive.Helpers.AlertDataHelpers
  alias AlertsUIWeb.CreateAlertLive.Slice
  alias AlertsUIWeb.FormComponents.Helpers.AlertData, as: OldAlertData

  alias AlertsUIWeb.CreateAlertLive.Slices.{
    AlertDetailsSlice,
    DeliverySlice,
    NotificationPeriodSlice,
    ReminderTimesSlice,
    SubmitSlice,
    TimelineSlice,
    TimeRangeSlice,
    UrlSlice
  }

  alias Ecto.Changeset
  alias MBTAV3API.Routes.Route
  alias Phoenix.Component
  alias Phoenix.LiveView.Socket

  use AlertsUI.Schema

  import Changeset

  import Component, only: [assign: 3, to_form: 1]

  import AlertsUIWeb.FormComponents.Helpers.ErrorFormatter,
    only: [parse_field_errors: 1]

  import AlertsUIWeb.CreateAlertLive.Helpers.AlertDataHelpers,
    only: [combination_for: 2, combination_for: 3]

  @combination_values [:ACCESS, :R, :RDS, :RDT, :RDTS, :SR]
  @type combination :: :ACCESS | :R | :RDS | :RDT | :RDTS | :SR

  @alert_timing_values [:"one-time", :recurring]
  @type alert_timing :: :"one-time" | :recurring

  @start_values [:now, :start_of_service, :custom]
  @type start_values :: :now | :start_of_service | :custom

  @end_values [
    :later_today,
    :end_of_service,
    :until_further_notice,
    :when_work_order_is_closed,
    :custom
  ]
  @type end_values ::
          :later_today
          | :end_of_service
          | :until_further_notice
          | :when_work_order_is_closed
          | :custom

  @notification_values [:same_as_effect_period, :now, :start_of_service, :custom]
  @type notification_values :: :same_as_effect_period | :now | :start_of_service | :custom

  @recurrence_days_values [:sunday, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday]
  @type recurrence_days ::
          :sunday | :monday | :tuesday | :wednesday | :thursday | :friday | :saturday

  @uncastable_fields [:__struct__, :reminder_times]

  @primary_key false
  embedded_schema do
    # carried in the url and/or necessary for all alerts
    field :alert_id, :string
    field :form_type, :string
    field :route_type, :integer
    field :route_type_int, :integer
    field :effect_name, :string
    field :review, :boolean

    # affected service
    field :direction, :string
    field :facility_ids, {:array, :string}
    field :facility_search_term, :string
    field :single_facility_id, :string
    field :modal_date, :string, default: "default"
    field :modal_date_search_term, :string
    field :modal_route_id, :string
    field :modal_route_search_term, :string
    field :stop_id, :string
    field :original_direction_selections, {:array, :string}
    field :original_facility_selections, {:array, :string}
    field :original_route_selections, {:array, :string}
    field :original_stop_selections, {:array, :string}
    field :original_trip_selections, {:array, :string}
    field :route_ids, {:array, :string}
    field :route_search_term, :string
    field :single_route_id, :string
    field :stop_ids, {:array, :string}
    field :stop_names, {:array, :string}
    field :stop_names_and_ids, {:array, :string}
    field :stop_search_term, :string
    field :trip_ids, {:array, :string}
    field :trip_information_by_id, {:map, :map}
    field :trip_search_term, :string
    field :service_types, {:array, :integer}
    field :work_order_id, :string
    field :skate_search_term, :string
    field :skate_detour_id, :integer

    # time range
    field :alert_timing, Ecto.Enum, values: @alert_timing_values, default: :"one-time"
    field :recurrence_days, {:array, Ecto.Enum}, values: @recurrence_days_values
    field :can_close_automatically, :boolean, default: false
    field :active_period_end, :naive_datetime
    field :active_period_end_date, :date
    field :active_period_end_specifier, Ecto.Enum, values: @end_values
    field :active_period_end_time, :time

    field :active_period_end_time_specifier, Ecto.Enum,
      values: @end_values,
      default: :end_of_service

    field :active_period_start, :naive_datetime
    field :active_period_start_date, :date
    field :active_period_start_specifier, Ecto.Enum, values: @start_values, default: :now
    field :active_period_start_time, :time
    field :active_period_start_time_specifier, Ecto.Enum, values: @start_values, default: :now
    field :notification_period_end, :naive_datetime
    field :notification_period_end_date, :date
    field :notification_period_start, :naive_datetime
    field :notification_period_start_date, :date
    field :notification_specifier, Ecto.Enum, values: @notification_values, default: :now

    # details
    field :cause_detail, :string, default: ""
    field :description_text, :string
    field :description_sync_toggle, :boolean, default: true
    field :header_text, :string, default: ""
    field :header_sync_toggle, :boolean, default: true
    field :image_alternative_text, :string
    field :image_size, :map, default: %{}
    field :image_url, :string, default: ""
    field :image_path, :string, default: ""
    field :service_effect_text, :string
    field :severity, :integer, default: 4
    field :url, :string, default: ""

    # delivery
    field :accept_banner, :boolean, default: false
    field :banner_sync_toggle, :boolean, default: true
    field :banner_text, :string
    field :notification_toggle, :boolean
    field :view_banner, :boolean

    # rider reminders
    embeds_many :reminder_times, ReminderTime, on_replace: :delete do
      field :reminder_time, :naive_datetime
    end

    # generated
    field :combination, Ecto.Enum, values: @combination_values
    field :created_timestamp, :utc_datetime
    field :created_by, :string
    field :last_edited_at, :utc_datetime
    field :last_edited_by, :string
    field :last_push_notification_timestamp, :utc_datetime
  end

  @type t :: %__MODULE__{
          # basic params
          form_type: :atom,
          alert_id: String.t() | nil,
          route_type: String.t() | nil,
          route_type_int: Route.type_int() | nil,
          effect_name: String.t() | nil,
          review: boolean() | nil,
          # service
          direction: String.t() | nil,
          facility_ids: [String.t()] | nil,
          original_direction_selections: [String.t()] | nil,
          original_facility_selections: [String.t()] | nil,
          original_route_selections: [String.t()] | nil,
          original_stop_selections: [String.t()] | nil,
          original_trip_selections: [String.t()] | nil,
          trip_information_by_id: map() | nil,
          service_types: [integer()] | nil,
          work_order_id: String.t() | nil,
          # timing
          active_period_end: NaiveDateTime.t() | nil,
          active_period_end_date: Date.t() | nil,
          active_period_end_specifier: end_values() | nil,
          active_period_end_time: Time.t() | nil,
          active_period_end_time_specifier: end_values() | nil,
          active_period_start: NaiveDateTime.t() | nil,
          active_period_start_date: Date.t() | nil,
          active_period_start_specifier: start_values() | nil,
          active_period_start_time: Time.t() | nil,
          active_period_start_specifier: start_values() | nil,
          alert_timing: alert_timing() | nil,
          notification_period_end: NaiveDateTime.t() | nil,
          notification_period_end_date: Date.t() | nil,
          notification_period_start: NaiveDateTime.t() | nil,
          notification_period_start_date: Date.t() | nil,
          notification_specifier: notification_values(),
          recurrence_days: [recurrence_days()] | nil,
          # details
          cause_detail: String.t() | nil,
          description_text: String.t() | nil,
          description_sync_toggle: boolean() | nil,
          header_text: String.t() | nil,
          header_sync_toggle: boolean() | nil,
          image_alternative_text: String.t() | nil,
          image_url: String.t() | nil,
          service_effect_text: String.t() | nil,
          severity: integer(),
          url: String.t() | nil,
          # delivery
          accept_banner: boolean(),
          banner_sync_toggle: boolean(),
          banner_text: String.t(),
          notification_toggle: boolean() | nil,
          view_banner: boolean() | nil,
          # reminders
          reminder_times: [
            %{
              reminder_time: NaiveDateTime.t()
            }
          ]
        }

  @actions [:new, :edit, :duplicate]

  @spec init(
          atom() | %{:assigns => map(), optional(any()) => any()},
          map(),
          :duplicate | :edit | :new
        ) ::
          {:error, {map()}} | {:ok, {map()}}
  def init(socket, params, action, alert \\ %Alert{}) when action in @actions do
    form_type =
      case action do
        :new -> :new
        :edit -> :editing
        :duplicate -> :duplicating
      end

    base_params =
      alert
      |> Repo.preload([:informed_entity, :reminder_times])
      |> OldAlertData.build_alert_data(form_type)
      |> Map.from_struct()
      |> Map.put(:alert_id, alert.alert_id)
      |> AlertDataHelpers.atomize_fields()
      |> AlertDataHelpers.normalize_effect_name()
      |> set_sync_toggles()

    base = struct(__MODULE__, base_params)

    initial_route_type = base.route_type || params["route_type"]

    effect_name = base.effect_name || params["effect_name"]

    initial_combination =
      base.combination ||
        combination_for(
          initial_route_type,
          effect_name
        )

    {extracted_params, socket} =
      slices(initial_combination)
      |> Enum.map(fn slice_module ->
        slice_module
        |> struct(Map.from_struct(base))
        |> Slice.extract(base, params)
      end)
      |> Enum.reduce({%{}, socket}, fn slice, {alert_data_params, socket} ->
        extracted_params =
          Map.merge(alert_data_params, Map.from_struct(slice), &keep_non_nil/3)

        socket = Slice.mount(slice, socket, params)

        {extracted_params, socket}
      end)

    merged_params = Map.merge(Map.from_struct(base), extracted_params)

    __MODULE__
    |> struct(merged_params)
    |> sync(socket, params, init_param_fields())
  end

  @spec sync(
          t() | Changeset.t(),
          Socket.t(),
          Phoenix.LiveView.unsigned_params(),
          list(atom()) | nil
        ) :: {:ok, {Socket.t()}} | {:error, {Socket.t()}} | any()
  def sync(alert_data_or_changeset, socket, params, fields \\ nil) do
    alert_data_params =
      params
      |> Map.get("alert_data", %{})
      |> inject_empty_for_cleared_multiselect(params)

    alert_data_or_changeset
    |> cast(alert_data_params, fields || form_fields(socket))
    |> transform(params, socket)
    |> validate(params, socket)
    |> case do
      {:ok, alert_data} ->
        socket =
          socket
          |> assign(:form, to_form(change(alert_data)))
          |> assign(:errors, [])
          |> assigns(params)

        {:ok, socket}

      {:error, changeset} ->
        new_errors = parse_field_errors(changeset)
        changeset = %{changeset | errors: new_errors}

        socket =
          socket
          |> assign(:form, to_form(changeset))
          |> assigns(params)

        {:error, socket}
    end
  end

  def transform(%Changeset{} = changeset, params, socket) do
    combination =
      combination_for(
        get_field(changeset, :route_type),
        get_field(changeset, :effect_name),
        get_field(changeset, :combination)
      )

    Enum.reduce(
      slices(combination),
      changeset,
      fn slice_module, changeset ->
        changeset
        |> slice_from_changeset(slice_module)
        |> Slice.transform(changeset, params, socket)
      end
    )
  end

  def validate(%Changeset{} = changeset, params, socket) do
    combination = get_field(changeset, :combination)

    # Restart validation from a clean slate
    Enum.reduce(
      slices(combination),
      %{changeset | errors: [], valid?: true},
      fn slice_module, changeset ->
        changeset
        |> slice_from_changeset(slice_module)
        |> Slice.validate(changeset, params, socket)
      end
    )
    |> apply_action(:validate)
  end

  def assigns(socket, params) do
    Enum.reduce(slices(socket), socket, fn slice_module, socket ->
      Slice.assigns(struct(slice_module), socket, params)
    end)
  end

  def slice_from_changeset(changeset, slice_module) do
    as_map =
      slice_module
      |> struct()
      |> Map.keys()
      |> Enum.map(fn key -> {key, get_field(changeset, key)} end)
      |> Enum.into(%{})
      |> Map.from_struct()

    struct(slice_module, as_map)
  end

  def slices(combination) when is_atom(combination) do
    [
      TimelineSlice,
      UrlSlice,
      CreateAlertLive.service_slice(combination),
      TimeRangeSlice,
      AlertDetailsSlice,
      NotificationPeriodSlice,
      ReminderTimesSlice,
      DeliverySlice,
      SubmitSlice
    ]
  end

  def slices(socket), do: slices(combination_from_socket(socket))

  defp combination_from_socket(socket) do
    case Map.get(socket.assigns, :form) do
      nil -> nil
      _ -> socket.assigns.form[:combination].value
    end
  end

  def init_param_fields, do: [:alert_id, :effect_name, :route_type]

  def form_fields(socket) do
    slices(socket)
    |> Enum.map(&(struct(&1) |> Map.keys()))
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.reject(&(&1 in @uncastable_fields))
  end

  defp keep_non_nil(_key, v1, v2), do: if(is_nil(v2), do: v1, else: v2)

  defp set_sync_toggles(alert_data) do
    toggle_data =
      [:header, :description, :banner]
      |> Enum.map(fn toggle ->
        toggle_key = toggle_sync_key(toggle)

        toggle_value =
          cond do
            Map.get(alert_data, toggle_key) == false ->
              # the toggle has explicitly been disabled
              false

            Map.get(alert_data, toggle_text_key(toggle)) not in [nil, ""] ->
              # the field is present
              false

            true ->
              # the field is nil and the toggle has not been disabled
              true
          end

        {toggle_key, toggle_value}
      end)
      |> Enum.into(%{})

    Map.merge(alert_data, toggle_data)
  end

  defp toggle_sync_key(:header), do: :header_sync_toggle
  defp toggle_sync_key(:description), do: :description_sync_toggle
  defp toggle_sync_key(:banner), do: :banner_sync_toggle

  defp toggle_text_key(:header), do: :header_text
  defp toggle_text_key(:description), do: :description_text
  defp toggle_text_key(:banner), do: :banner_text

  # When a multiselect field is fully deselected, browsers omit it from form
  # submissions entirely. Ecto's cast then skips the field, leaving the prior
  # value intact. If the _target indicates the user interacted with a field
  # that is now absent from the params, inject an empty list so cast resets it.
  defp inject_empty_for_cleared_multiselect(
         alert_data_params,
         %{"_target" => ["alert_data", field]}
       )
       when not is_map_key(alert_data_params, field) do
    Map.put(alert_data_params, field, [])
  end

  defp inject_empty_for_cleared_multiselect(alert_data_params, _params), do: alert_data_params
end
