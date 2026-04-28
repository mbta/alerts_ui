defmodule AlertsUIWeb.CreateAlertMonoLive.AlertData do
  @moduledoc """
  Alert data v2
  """
  require Logger

  alias Ecto.Changeset
  import Changeset

  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.{
    UrlSlice,
    DeliverySlice,
    SystemwideServiceSlice
  }

  use AlertsUI.Schema

  @combination_values [:ACCESS, :R, :RDS, :RDT, :RDTS, :SR]
  @alert_timing_values [:"one-time", :recurring]
  @start_values [:now, :start_of_service, :custom]
  @end_values [:later_today, :end_of_service, :until_further_notice, :custom]
  @notification_values [:same_as_effect_period, :now, :start_of_service, :custom]
  @recurrence_days_values [:sunday, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday]

  @primary_key false
  embedded_schema do
    # carried in the url and/or necessary for all alerts
    field :alert_id, :string
    field :form_type, :string
    field :route_type, :string
    field :effect_name, :string
    field :review, :boolean
    # affected service
    field :direction, :string
    field :facility_ids, {:array, :string}
    field :original_direction_selections, {:array, :string}
    field :original_facility_selections, {:array, :string}
    field :original_route_selections, {:array, :string}
    field :original_stop_selections, {:array, :string}
    field :original_trip_selections, {:array, :string}
    field :route_ids, {:array, :string}
    field :service_types, {:array, :integer}
    # time range
    field :active_period_end, :naive_datetime
    field :active_period_end_date, :date
    field :active_period_end_specifier, Ecto.Enum, values: @end_values, default: :later_today
    field :active_period_end_time, :time
    field :active_period_end_time_specifier, Ecto.Enum, values: @end_values, default: :end_of_service
    field :active_period_start, :naive_datetime
    field :active_period_start_date, :date
    field :active_period_start_specifier, Ecto.Enum, values: @start_values, default: :now
    field :active_period_start_time, :time
    field :active_period_start_time_specifier, Ecto.Enum, values: @start_values, default: :now
    field :alert_timing, Ecto.Enum, values: @alert_timing_values, default: :"one-time"
    field :notification_period_start, :naive_datetime
    field :notification_period_start_date, :date
    field :notification_specifier, Ecto.Enum, values: @notification_values, default: :now
    field :recurrence_days, {:array, Ecto.Enum}, values: @recurrence_days_values
    # details
    field :cause_detail, :string, default: ""
    field :description_text, :string
    field :description_sync_toggle, :boolean, default: true
    field :header_text, :string
    field :header_sync_toggle, :boolean, default: true
    field :image_alternative_text, :string
    field :image_size, :map, default: %{}
    field :image_url, :string
    field :service_effect_text, :string
    field :severity, :integer, default: 4
    field :url, :string
    # delivery
    field :accept_banner, :boolean, default: false
    field :banner_sync_toggle, :boolean, default: true
    field :banner_text, :string
    field :notification_toggle, :boolean, default: true
    field :view_banner, :boolean, default: false
    # rider reminders
    embeds_many :reminder_times, ReminderTimes, on_replace: :delete do
      field :reminder_time, :naive_datetime
      field :min_time, :naive_datetime
      field :max_time, :naive_datetime
    end
    # generated
    field :combination, Ecto.Enum, values: @combination_values
    field :created_timestamp, :utc_datetime
    field :created_by, :string
    field :last_edited_at, :utc_datetime
    field :last_edited_by, :string
  end

  @slices [
    UrlSlice,
    DeliverySlice,
    SystemwideServiceSlice
  ]

  @actions [:new, :edit, :duplicate]

  def init(params, action, alert_or_nil \\ nil) when action in @actions do
    base_params =
      slices()
      |> Enum.map(fn slice_module ->
        slice = struct(slice_module)

        case alert_or_nil do
          nil -> slice
          alert -> Slice.extract(slice, alert)
        end
      end)
      |> Enum.reduce(%{}, fn slice, alert_data_params ->
        Map.merge(alert_data_params, Map.from_struct(slice))
      end)

    __MODULE__
    |> struct(base_params)
    |> sync(params, url_fields())
  end

  def sync(alert_data_or_changeset, params, fields \\ form_fields()) do
    Logger.warning("FORM FIELDS are: #{inspect(fields)}")
    Logger.warning("PARAMS are: #{inspect(params)}")
    alert_data_or_changeset
    |> cast(params, form_fields())
    |> transform()
    |> validate()
  end

  def transform(%Changeset{} = changeset) do
    Enum.reduce(slices(), changeset, fn slice_module, changeset -> 
      changeset
      |> slice_from_changeset(slice_module)
      |> Slice.transform(changeset)
    end)
  end   

  def validate(%Changeset{} = changeset) do
    Enum.reduce(slices(), changeset, fn slice_module, changeset -> 
      changeset
      |> slice_from_changeset(slice_module)
      |> Slice.validate(changeset)
    end) |> apply_action(:validate)
  end   

  def slice_from_changeset(changeset, slice_module) do
    as_map =
      slice_module
      |> struct()
      |> Map.keys()
      |> Enum.map(fn key -> {key, get_field(changeset, key)} end)
      |> Enum.into(%{})
      |> Map.from_struct

    struct(slice_module, as_map)
  end

  def slices(), do: @slices

  def url_fields, do: Map.keys(%UrlSlice{})

  def form_fields do
    slices()
    |> Enum.map(& struct(&1) |> Map.delete(:__struct__) |> Map.keys())
    |> List.flatten()
  end
end
