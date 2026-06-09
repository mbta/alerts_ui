defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.NotificationPeriodSlice do
  @moduledoc """
    Live Component for notification period of form
  """

  alias AlertsUI.Models.ActivePeriod
  alias AlertsUIWeb.CreateAlertMonoLive.Helpers.Time, as: DTHelpers
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.FormComponents.Helpers.DateTimeHelpers
  alias Phoenix.HTML.Form

  use AlertsUIWeb, :html

  import Ecto.Changeset

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertData,
    only: [put_over_nil: 3, values_to_options: 1]

  @notification_values [
    :same_as_effect_period,
    :now,
    :start_of_service,
    :custom
  ]

  defstruct [
    :form_type,
    :active_period_end,
    :notification_period_start,
    :notification_period_start_date,
    notification_specifier: :now
  ]

  defimpl Slice, for: __MODULE__ do
    alias AlertsUIWeb.CreateAlertMonoLive.AlertData
    alias AlertsUIWeb.CreateAlertMonoLive.Helpers.TimeRangeValidators
    alias AlertsUIWeb.CreateAlertMonoLive.Slices.NotificationPeriodSlice

    def mount(_slice, socket, _params) do
      socket
    end

    def extract(slice, %AlertData{} = _alert, _params) do
      now = DateTimeHelpers.current_time()

      slice
      |> put_over_nil(:notification_specifier, :now)
      |> put_over_nil(:notification_period_start, now)
      |> put_over_nil(:notification_period_start_date, NaiveDateTime.to_date(now))
      |> update_times_if_duplicating(slice.form_type, now)
    end

    def transform(_slice, changeset, _params, _socket) do
      changeset
      |> NotificationPeriodSlice.ensure_notification_start()
      |> NotificationPeriodSlice.extract_notification_end()
    end

    def validate(_slice, changeset, params, socket) do
      changeset
      |> TimeRangeValidators.validate_cast_notification_datetimes(params)
      |> TimeRangeValidators.validate_notification(socket.assigns.form_type == :editing)
      |> TimeRangeValidators.validate_required_notification_fields()
    end

    def assigns(_slice, socket, _params) do
      socket
    end

    def update_times_if_duplicating(slice, :duplicating, now) do
      active_period_end = slice.active_period_end || now

      if NaiveDateTime.compare(now, active_period_end) in [:eq, :gt] do
        Map.merge(slice, %{
          notification_specifier: :now,
          notification_period_start: now,
          notification_period_start_date: NaiveDateTime.to_date(now)
        })
      else
        slice
      end
    end

    def update_times_if_duplicating(slice, _, _), do: slice
  end

  def ensure_notification_start(changeset) do
    specifier = get_field(changeset, :notification_specifier)
    start_dt = get_field(changeset, :notification_period_start, :unspecified)
    start_d = get_field(changeset, :notification_period_start_date, :unspecified)

    changeset
    |> ensure_notification_start_for_specifier(specifier, start_dt, start_d)
  end

  def ensure_notification_start_for_specifier(changeset, :same_as_effect_period, _, _) do
    active_period_start = get_field(changeset, :active_period_start)
    active_period_start_date = get_field(changeset, :active_period_start_date)

    changeset
    |> force_change(:notification_period_start, active_period_start)
    |> force_change(:notification_period_start_date, active_period_start_date)
  end

  def ensure_notification_start_for_specifier(changeset, :now, _, _) do
    now = DateTimeHelpers.current_time()

    changeset
    |> force_change(:notification_period_start, now)
    |> force_change(:notification_period_start_date, now |> NaiveDateTime.to_date())
  end

  def ensure_notification_start_for_specifier(changeset, :start_of_service, _, d) do
    datetime = NaiveDateTime.new!(d, ActivePeriod.start_of_service_time())

    changeset
    |> force_change(:notification_period_start, datetime)
    |> force_change(:notification_period_start_date, d)
  end

  def ensure_notification_start_for_specifier(changeset, :custom, nil, d) do
    ensure_notification_start_for_specifier(
      changeset,
      :custom,
      DateTimeHelpers.current_time(),
      d
    )
  end

  def ensure_notification_start_for_specifier(changeset, :custom, dt, _) do
    changeset
    |> force_change(:notification_period_start, dt)
    |> force_change(:notification_period_start_date, NaiveDateTime.to_date(dt))
  end

  def ensure_notification_start_for_specifier(changeset, _, _, _), do: changeset

  def extract_notification_end(changeset) do
    specifier = get_field(changeset, :active_period_end_specifier)
    end_dt = get_field(changeset, :active_period_end) || :unspecified
    end_d = get_field(changeset, :active_period_end_date) || :unspecified

    changeset
    |> extract_notification_end_for_specifier(specifier, end_dt, end_d)
  end

  def extract_notification_end_for_specifier(changeset, :later_today, _, _) do
    now =
      DateTimeHelpers.current_time()
      |> ActivePeriod.end_of_service_datetime_naive()

    changeset
    |> force_change(:notification_period_end, now)
    |> force_change(:notification_period_end_date, now |> NaiveDateTime.to_date())
  end

  def extract_notification_end_for_specifier(changeset, :end_of_service, _, :unspecified) do
    now = NaiveDateTime.local_now() |> NaiveDateTime.to_date()
    extract_notification_end_for_specifier(changeset, :end_of_service, :ignored, now)
  end

  def extract_notification_end_for_specifier(changeset, :end_of_service, _, date) do
    datetime =
      date
      |> NaiveDateTime.new!(~T[12:00:00])
      |> ActivePeriod.end_of_service_datetime_naive()

    changeset
    |> force_change(:notification_period_end, datetime)
    |> force_change(:notification_period_end_date, datetime |> NaiveDateTime.to_date())
  end

  def extract_notification_end_for_specifier(changeset, :until_further_notice, _, _) do
    now = DateTimeHelpers.current_time()

    changeset
    |> force_change(:notification_period_end, DTHelpers.replace_time(now, ~T[23:59:59]))
    |> force_change(:notification_period_end_date, now |> NaiveDateTime.to_date())
  end

  def extract_notification_end_for_specifier(changeset, :custom, :unspecified, _) do
    now = NaiveDateTime.local_now()
    extract_notification_end_for_specifier(changeset, :custom, now, :ignored)
  end

  def extract_notification_end_for_specifier(changeset, :custom, dt, _) do
    changeset
    |> force_change(:notification_period_end, dt)
    |> force_change(:notification_period_end_date, dt |> NaiveDateTime.to_date())
  end

  def extract_notification_end_for_specifier(changeset, _, _, _) do
    changeset
  end

  def notification_values, do: @notification_values

  attr :form, Form

  def render(assigns) do
    ~H"""
    <div class="min-w-full flex flex-col" id="notification_period_view">
      <div id="scheduled-selector-div" class="flex flex-col md:flex-row md:flex-wrap gap-8 my-4">
        <.select
          label="Notification period"
          field={@form[:notification_specifier]}
          options={values_to_options(notification_values())}
          class="md:w-[16rem] h-10"
        />
        <.datetime
          :if={@form[:notification_specifier].value in [:start_of_service, "start_of_service"]}
          type="date"
          label=""
          field={@form[:notification_period_start_date]}
          min={DateTimeHelpers.current_time() |> naive_datetime_to_iso_date}
          max={
            [naive_datetime_to_iso_date(@form[:active_period_start].value), "9999-12-31"]
            |> Enum.max()
          }
          value={@form[:notification_period_start_date].value}
          class="md:min-w-64 md:max-w-64 h-10"
        />
        <.datetime
          :if={@form[:notification_specifier].value in [:custom, "custom"]}
          label=""
          field={@form[:notification_period_start]}
          min={@form[:active_period_start].value |> naive_datetime_to_iso8601}
          max={
            [naive_datetime_to_iso_date(@form[:active_period_end].value), "9999-12-31T23:59"]
            |> Enum.max()
          }
          value={@form[:notification_period_start].value |> naive_datetime_to_iso8601}
          class="md:min-w-64 md:max-w-64 h-10"
        />
        <div
          :if={
            @form[:notification_specifier].value not in [
              :same_as_effect_period,
              "same_as_effect_period"
            ]
          }
          class="flex flex-col md:flex-row"
        >
          <p class="pt-[2rem] mr-[2rem]">
            to
          </p>
          <input
            disabled={true}
            type="text"
            id="closed-placeholder"
            value="When alert is closed"
            placeholder="When alert is closed"
            class="border border-bg-elevation-6 pl-2
                  rounded text-text-secondary
                  bg-bg-elevation-3 ring-0  ring-border-focus
                  mt-[1.75rem] h-10 min-w-[16rem]"
          />
        </div>
      </div>
      <hr class="mt-8" />
    </div>
    """
  end

  def naive_datetime_to_iso_date(%NaiveDateTime{} = datetime),
    do: datetime |> NaiveDateTime.to_date() |> Date.to_iso8601()

  def naive_datetime_to_iso_date(_), do: ""

  defp naive_datetime_to_iso8601(%NaiveDateTime{} = datetime),
    do:
      datetime
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.to_iso8601()
      |> String.slice(0..-4//1)

  defp naive_datetime_to_iso8601(_), do: ""
end
